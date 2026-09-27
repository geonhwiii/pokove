import Foundation

// The adventure's battles: stats, Gen 3 damage, real moves and a 1:1 relay that advances one action
// per tick. Pure value types, so scripts/adventure-sim.swift can run it outside the app.

/// SplitMix64: small, fast and reproducible.
nonisolated struct SeededRNG: RandomNumberGenerator, Equatable, Sendable {
    var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func pick(_ range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    /// An index chosen in proportion to `weights`.
    mutating func weighted(_ weights: [Double]) -> Int? {
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var roll = unit() * total
        for (index, weight) in weights.enumerated() {
            if roll < weight { return index }
            roll -= weight
        }
        return weights.indices.last
    }
}

nonisolated struct PokeStats: Codable, Equatable, Sendable {
    var hp: Int
    var attack: Int
    var defense: Int
    var spAttack: Int
    var spDefense: Int
    var speed: Int
}

nonisolated enum PokeMath {
    static let maxLevel = 100

    /// Main-series stat formulas without IVs, EVs or natures.
    static func stats(_ base: BaseStats, level: Int) -> PokeStats {
        func other(_ value: Int) -> Int { 2 * value * level / 100 + 5 }
        return PokeStats(
            hp: 2 * base.hp * level / 100 + level + 10,
            attack: other(base.attack),
            defense: other(base.defense),
            spAttack: other(base.spAttack),
            spDefense: other(base.spDefense),
            speed: other(base.speed)
        )
    }

    /// The medium-fast curve: reaching level L takes L³ experience.
    static func xp(forLevel level: Int) -> Int { level * level * level }

    /// Experience still needed for the next level; 0 at the top.
    static func xpToNext(level: Int, xp: Int) -> Int {
        level >= maxLevel ? 0 : max(0, self.xp(forLevel: level + 1) - xp)
    }

    static func level(forXP xp: Int) -> Int {
        var level = max(1, Int(cbrt(Double(max(xp, 1)))))
        while level < maxLevel, xp >= self.xp(forLevel: level + 1) { level += 1 }
        while level > 1, xp < self.xp(forLevel: level) { level -= 1 }
        return min(level, maxLevel)
    }

    /// The most experience a Pokémon can hold under a level cap; the rest is banked.
    static func xpLimit(cap: Int) -> Int {
        cap >= maxLevel ? xp(forLevel: maxLevel) : xp(forLevel: cap + 1) - 1
    }

    /// Experience for knocking out a Pokémon, shared in full by the whole party.
    ///
    /// It follows the square root of the species' base experience, so evolved Pokémon are worth
    /// more without the late game racing ahead: levels come every few minutes at first and take
    /// about an hour near the Elite Four. Foes below the party's level are worth less, so
    /// revisiting early routes doesn't beat pushing on.
    static func defeatXP(baseExperience: Int, level: Int, partyLevel: Int, kind: StagePlan.Kind) -> Int {
        let bonus: Double = switch kind {
        case .wild: 1
        case .trainer: 1.5
        case .legend: 3
        case .dungeon: 1.25
        case .tower: 1.5
        }
        let relative = min(1, Double(level) / Double(max(1, partyLevel)))
        return max(1, Int((xpScale * Double(max(20, baseExperience)).squareRoot() * (0.4 + 0.6 * relative) * bonus).rounded()))
    }

    /// Tuning knob for how fast the party grows (see scripts/adventure-sim.swift).
    nonisolated(unsafe) static var xpScale = 1.1
}

/// Everything the rules read: species, moves and wild encounters.
nonisolated struct GameData: Sendable {
    let dex: DexView
    let moves: MoveDex
    let encounters: EncounterDex
    /// The journey for this player's starter.
    let chapters: [Chapter]

    init(species: [PokeSpecies], moves: MoveDex, encounters: EncounterDex, starter: Int) {
        dex = DexView(species)
        self.moves = moves
        self.encounters = encounters
        chapters = Kanto.chapters(starter: starter)
    }

    func legend(_ id: String) -> LegendSpot? { Kanto.legends.first { $0.id == id } }
    /// The chapter whose line a legendary branches off.
    func chapterIndex(ofLegend id: String) -> Int? { chapters.firstIndex { $0.legend?.id == id } }
}

/// The parts of the dex the rules need, so they don't depend on the observable store.
nonisolated struct DexView: Sendable {
    let species: [PokeSpecies]
    private let byID: [Int: PokeSpecies]
    private let children: [Int: [Int]]

    init(_ species: [PokeSpecies]) {
        self.species = species
        byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        var children: [Int: [Int]] = [:]
        for entry in species { if let from = entry.evolvesFrom { children[from, default: []].append(entry.id) } }
        self.children = children
    }

    subscript(id: Int) -> PokeSpecies? { byID[id] }
    func evolutions(_ id: Int) -> [Int] { children[id] ?? [] }

    func stage(of id: Int) -> Int {
        var stage = 1
        var current = byID[id]
        while let from = current?.evolvesFrom, let previous = byID[from] { stage += 1; current = previous }
        return stage
    }

    /// The first form of a species' evolution line.
    func base(of id: Int) -> Int {
        var current = id
        while let from = byID[current]?.evolvesFrom, byID[from] != nil { current = from }
        return current
    }
}

// MARK: Combatants

/// One Pokémon in a battle.
nonisolated struct Combatant: Identifiable, Equatable, Sendable {
    let id: UUID
    var speciesID: Int
    var level: Int
    var types: [PokeType]
    var stats: PokeStats
    var hp: Int
    var moves: [PokeMove]
    /// Rounds left before a strong move can be used again.
    var cooldowns: [Int: Int] = [:]
    /// Bosses (legendaries, the dungeon's last floor) have more HP than their level gives.
    var hpScale: Double = 1
    /// The party member this is, for experience and evolution.
    var ownedID: UUID?
    /// Poisoned, burned or paralyzed, until the battle ends.
    var status: Ailment?

    var maxHP: Int { stats.hp }
    /// Paralysis quarters speed.
    var speed: Int { status == .paralysis ? max(1, stats.speed / 4) : stats.speed }
    var isFainted: Bool { hp <= 0 }
    var hpFraction: Double { maxHP > 0 ? Double(max(0, hp)) / Double(maxHP) : 0 }

    init(species: PokeSpecies, level: Int, moves: MoveDex, hpScale: Double = 1, ownedID: UUID? = nil) {
        id = UUID()
        speciesID = species.id
        self.level = level
        types = species.types
        var stats = PokeMath.stats(species.stats, level: level)
        stats.hp = Int(Double(stats.hp) * hpScale)
        self.stats = stats
        hp = stats.hp
        self.moves = moves.moveset(species: species.id, types: species.types, level: level)
        self.hpScale = hpScale
        self.ownedID = ownedID
    }

    /// After a level-up or evolution: new stats and moves, keeping the damage already taken.
    mutating func become(_ species: PokeSpecies, level: Int, moves: MoveDex) {
        let taken = maxHP - hp
        speciesID = species.id
        self.level = level
        types = species.types
        stats = PokeMath.stats(species.stats, level: level)
        stats.hp = Int(Double(stats.hp) * hpScale)
        self.moves = moves.moveset(species: species.id, types: species.types, level: level)
        cooldowns = cooldowns.filter { entry in self.moves.contains { $0.id == entry.key } }
        hp = isFainted ? 0 : max(1, stats.hp - taken)
    }

    func isReady(_ move: PokeMove) -> Bool { (cooldowns[move.id] ?? 0) == 0 }
}

// MARK: Stages

/// What a battle holds: wild Pokémon at a station, a trainer's team, a legendary, or the dungeon.
nonisolated struct StagePlan: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case wild
        case trainer(Trainer)
        case legend
        case dungeon(DungeonTier)
        case tower(Int)
    }

    struct Foe: Equatable, Sendable {
        let species: Int
        let level: Int
        var hpScale: Double = 1
    }

    let kind: Kind
    let foes: [Foe]
    let scenery: Scenery

    var trainer: Trainer? { if case .trainer(let trainer) = kind { trainer } else { nil } }

    static let legendHP = 2.5

    /// One wild Pokémon, two at a chapter's last station, different on every visit. Wild
    /// Pokémon stay a level or more below the party, as in the games, so only the bosses stand in
    /// the way: the line is for exploring, the gyms for testing the team.
    static func station(_ station: Station, isLast: Bool, data: GameData, partyLevel: Int, rng: inout SeededRNG) -> StagePlan {
        let pool = data.encounters.pool(for: station.stretch, dex: data.dex)
        let level = min(station.level, partyLevel - 1)
        let count = isLast ? 2 : 1
        let foes = (0..<count).map { index -> Foe in
            let species = rng.weighted(pool.map(\.share)).map { pool[$0].species } ?? 16
            // The last one is the toughest.
            let spread = index == count - 1 ? 0 : rng.pick(-2...(-1))
            return Foe(species: species, level: max(2, level + spread))
        }
        return StagePlan(kind: .wild, foes: foes, scenery: station.stretch.scenery)
    }

    static func boss(_ trainer: Trainer, scenery: Scenery) -> StagePlan {
        StagePlan(kind: .trainer(trainer), foes: trainer.battleTeam.map { Foe(species: $0.species, level: $0.level) }, scenery: scenery)
    }

    static func legend(_ spot: LegendSpot) -> StagePlan {
        StagePlan(kind: .legend, foes: [Foe(species: spot.species, level: spot.level, hpScale: legendHP)], scenery: spot.scenery)
    }
}

// MARK: Battle

nonisolated enum BattleSide: Sendable {
    case party, foe
}

/// One move used, with everything the scene needs to show it.
nonisolated struct BattleAction: Equatable, Sendable {
    let attackerID: UUID
    let targetID: UUID
    let move: PokeMove
    let byParty: Bool
    let missed: Bool
    let hits: Int
    let damage: Int
    let effectiveness: Double
    let critical: Bool
    let healed: Int
    let recoil: Int
    let targetFainted: Bool
    let attackerFainted: Bool
    /// A status the hit left the target with.
    var inflicted: Ailment?
}

/// A status condition at work: just inflicted, hurting at the end of a round, or stopping a move.
nonisolated struct StatusEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case inflicted
        case hurt(Int)
        case immobile
    }

    let targetID: UUID
    let ailment: Ailment
    let kind: Kind
    /// The Pokémon is the party's.
    let onParty: Bool
    let fainted: Bool
}

nonisolated enum BattleEvent: Equatable, Sendable {
    /// A Pokémon took the field after the one before it fainted.
    case sentOut(BattleSide, UUID)
    case action(BattleAction)
    case status(StatusEvent)
    case cleared
    case wiped
}

/// A battle in progress, fought one Pokémon a side at a time. `step()` plays one action; the app
/// calls it every 1.5 s at a station while an agent works, and every second in a challenge.
nonisolated struct BattleState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case intro(Int)
        case fighting
        case switching(Int)
        case clearing(Int)
        case wiping(Int)
        case over(cleared: Bool)
    }

    let plan: StagePlan
    var party: [Combatant]
    private(set) var foes: [Combatant]
    private(set) var partyIndex: Int
    private(set) var foeIndex = 0
    private(set) var phase: Phase
    /// Sides still to act this round, with the moves they chose.
    private var round: [(side: BattleSide, move: PokeMove)] = []
    /// Status messages waiting to be shown, one a step.
    private var pending: [BattleEvent] = []
    /// Sides still to take poison or burn damage at the end of the round.
    private var residual: [BattleSide] = []
    private var actions = 0
    private var rng: SeededRNG

    static func == (lhs: BattleState, rhs: BattleState) -> Bool {
        lhs.plan == rhs.plan && lhs.party == rhs.party && lhs.foes == rhs.foes && lhs.partyIndex == rhs.partyIndex
            && lhs.foeIndex == rhs.foeIndex && lhs.phase == rhs.phase && lhs.actions == rhs.actions
    }

    var isOver: Bool { if case .over = phase { true } else { false } }
    var partyActive: Combatant? { party.indices.contains(partyIndex) ? party[partyIndex] : nil }
    var foeActive: Combatant? { foes.indices.contains(foeIndex) ? foes[foeIndex] : nil }

    init(plan: StagePlan, party: [Combatant], data: GameData, seed: UInt64) {
        self.plan = plan
        self.party = party
        partyIndex = party.firstIndex { !$0.isFainted } ?? 0
        foes = plan.foes.compactMap { foe in
            data.dex[foe.species].map { Combatant(species: $0, level: foe.level, moves: data.moves, hpScale: foe.hpScale) }
        }
        rng = SeededRNG(seed: seed)
        phase = .intro(plan.trainer == nil ? 1 : 2)
    }

    func combatant(_ id: UUID) -> Combatant? {
        party.first { $0.id == id } ?? foes.first { $0.id == id }
    }

    mutating func step() -> BattleEvent? {
        switch phase {
        case .intro(let ticks):
            if ticks > 0 { phase = .intro(ticks - 1); return nil }
            phase = .fighting
            return act()
        case .switching(let ticks):
            if ticks > 0 { phase = .switching(ticks - 1); return nil }
            phase = .fighting
            if partyActive?.isFainted == true, let next = party.firstIndex(where: { !$0.isFainted }) {
                partyIndex = next
                return .sentOut(.party, party[next].id)
            }
            if foeActive?.isFainted == true, let next = foes.firstIndex(where: { !$0.isFainted }) {
                foeIndex = next
                return .sentOut(.foe, foes[next].id)
            }
            return act()
        case .clearing(let ticks):
            if ticks > 0 { phase = .clearing(ticks - 1); return nil }
            phase = .over(cleared: true)
            return .cleared
        case .wiping(let ticks):
            if ticks > 0 { phase = .wiping(ticks - 1); return nil }
            phase = .over(cleared: false)
            return .wiped
        case .over:
            return nil
        case .fighting:
            return act()
        }
    }

    private mutating func act() -> BattleEvent? {
        if !pending.isEmpty { return pending.removeFirst() }
        while !residual.isEmpty {
            if let event = hurt(residual.removeFirst()) { return event }
        }
        actions += 1
        // A stalemate ends as a loss rather than running forever.
        if actions > 400 {
            phase = .wiping(1)
            return nil
        }
        guard let ally = partyActive, let foe = foeActive, !ally.isFainted, !foe.isFainted else { return settle() }
        if round.isEmpty {
            let allyMove = Self.choose(for: ally, against: foe, smart: true, rng: &rng)
            let foeMove = Self.choose(for: foe, against: ally, smart: plan.kind != .wild, rng: &rng)
            let allyFirst: Bool
            if allyMove.priority != foeMove.priority {
                allyFirst = allyMove.priority > foeMove.priority
            } else if ally.speed != foe.speed {
                allyFirst = ally.speed > foe.speed
            } else {
                allyFirst = rng.unit() < 0.5
            }
            round = allyFirst ? [(.party, allyMove), (.foe, foeMove)] : [(.foe, foeMove), (.party, allyMove)]
        }
        let (side, move) = round.removeFirst()
        // Fully paralyzed a quarter of the time.
        if let mover = active(side), mover.status == .paralysis, rng.unit() < 0.25 {
            if round.isEmpty { endRound() }
            return .status(StatusEvent(targetID: mover.id, ailment: .paralysis, kind: .immobile, onParty: side == .party, fainted: false))
        }
        let action = use(move, by: side)
        if action.targetFainted || action.attackerFainted {
            round = []
            pending = []
            _ = settle()
        } else {
            if let ailment = action.inflicted {
                pending.append(.status(StatusEvent(targetID: action.targetID, ailment: ailment, kind: .inflicted,
                                                   onParty: !action.byParty, fainted: false)))
            }
            if round.isEmpty { endRound() }
        }
        return .action(action)
    }

    private func active(_ side: BattleSide) -> Combatant? { side == .party ? partyActive : foeActive }

    /// Both sides have moved: poison and burn take their eighth.
    private mutating func endRound() {
        residual = [BattleSide.party, .foe].filter { side in
            guard let pokemon = active(side), !pokemon.isFainted else { return false }
            return pokemon.status == .poison || pokemon.status == .burn
        }
    }

    private mutating func hurt(_ side: BattleSide) -> BattleEvent? {
        guard var pokemon = active(side), !pokemon.isFainted, let status = pokemon.status, status != .paralysis else { return nil }
        let amount = min(pokemon.hp, max(1, pokemon.maxHP / 8))
        pokemon.hp -= amount
        if side == .party { party[partyIndex] = pokemon } else { foes[foeIndex] = pokemon }
        if pokemon.isFainted {
            residual = []
            round = []
            _ = settle()
        }
        return .status(StatusEvent(targetID: pokemon.id, ailment: status, kind: .hurt(amount), onParty: side == .party,
                                   fainted: pokemon.isFainted))
    }

    /// After a faint: the next Pokémon comes out, or the stage ends.
    private mutating func settle() -> BattleEvent? {
        if foes.allSatisfy(\.isFainted) {
            phase = .clearing(1)
        } else if party.allSatisfy(\.isFainted) {
            phase = .wiping(1)
        } else if partyActive?.isFainted == true || foeActive?.isFainted == true {
            phase = .switching(0)
        }
        return nil
    }

    private mutating func use(_ move: PokeMove, by side: BattleSide) -> BattleAction {
        var attacker = side == .party ? party[partyIndex] : foes[foeIndex]
        var defender = side == .party ? foes[foeIndex] : party[partyIndex]
        for key in attacker.cooldowns.keys { attacker.cooldowns[key] = max(0, (attacker.cooldowns[key] ?? 0) - 1) }
        if move.cooldown > 0 { attacker.cooldowns[move.id] = move.cooldown }

        let effectiveness = Self.effectiveness(of: move, against: defender)
        var missed = false
        if let accuracy = move.accuracy, rng.unit() * 100 >= Double(accuracy) { missed = true }

        var damage = 0, hits = 0, critical = false
        if !missed, effectiveness > 0 {
            let count = Self.hitCount(move, rng: &rng)
            for _ in 0..<count where !defender.isFainted {
                let crit = Self.rollCritical(move, rng: &rng)
                let dealt = min(defender.hp, Self.damage(move, from: attacker, to: defender, critical: crit, rng: &rng))
                defender.hp -= dealt
                damage += dealt
                hits += 1
                critical = critical || crit
            }
        }
        // A status the hit may leave, on a target that has none and isn't immune.
        var inflicted: Ailment?
        if damage > 0, !defender.isFainted, defender.status == nil, let ailment = move.ailment, ailment.affects(defender.types),
           rng.unit() * 100 < Double(move.ailmentChance) {
            defender.status = ailment
            inflicted = ailment
        }
        var healed = 0, recoil = 0
        if damage > 0, move.drain > 0 {
            healed = min(attacker.maxHP - attacker.hp, max(1, damage * move.drain / 100))
            attacker.hp += healed
        } else if damage > 0, move.drain < 0 {
            recoil = min(attacker.hp, max(1, damage * -move.drain / 100))
            attacker.hp -= recoil
        }

        if side == .party { party[partyIndex] = attacker; foes[foeIndex] = defender } else { foes[foeIndex] = attacker; party[partyIndex] = defender }
        return BattleAction(
            attackerID: attacker.id, targetID: defender.id, move: move, byParty: side == .party, missed: missed,
            hits: hits, damage: damage, effectiveness: effectiveness, critical: critical, healed: healed, recoil: recoil,
            targetFainted: defender.isFainted, attackerFainted: attacker.isFainted, inflicted: inflicted
        )
    }

    // MARK: Rules

    static func effectiveness(of move: PokeMove, against defender: Combatant) -> Double {
        move.id == PokeMove.struggle.id ? 1 : move.type.effectiveness(against: defender.types)
    }

    /// The best ready move for this matchup. Wild Pokémon sometimes pick at random, as in the games.
    static func choose(for attacker: Combatant, against defender: Combatant, smart: Bool, rng: inout SeededRNG) -> PokeMove {
        let ready = attacker.moves.filter { attacker.isReady($0) && $0.id != PokeMove.struggle.id }
        let scored = ready.map { move in (move, expectedDamage(move, from: attacker, to: defender)) }.filter { $0.1 > 0 }
        guard !scored.isEmpty else { return PokeMove.struggle }
        if !smart, rng.unit() < 0.4 { return scored[Int(rng.next() % UInt64(scored.count))].0 }
        return scored.max { $0.1 * (0.9 + 0.2 * rng.unit()) < $1.1 * (0.9 + 0.2 * rng.unit()) }!.0
    }

    static func expectedDamage(_ move: PokeMove, from attacker: Combatant, to defender: Combatant) -> Double {
        let effectiveness = effectiveness(of: move, against: defender)
        guard effectiveness > 0 else { return 0 }
        let hits: Double = move.minHits == move.maxHits ? Double(move.minHits) : (move.minHits == 2 && move.maxHits == 5 ? 3 : Double(move.minHits + move.maxHits) / 2)
        let chance = Double(move.accuracy ?? 100) / 100
        switch move.damage {
        case .fixed(let amount): return Double(amount) * chance
        case .level: return Double(attacker.level) * chance
        case .halfHP: return Double(defender.hp) / 2 * chance
        case .power(let power):
            return baseDamage(power: power, move: move, from: attacker, to: defender) * modifier(move, attacker: attacker, effectiveness: effectiveness) * 0.925 * hits * chance
        }
    }

    /// Gen 3's formula before the random factor, critical hits and type.
    private static func baseDamage(power: Int, move: PokeMove, from attacker: Combatant, to defender: Combatant) -> Double {
        let attack = Double(move.isPhysical ? attacker.stats.attack : attacker.stats.spAttack)
        let defense = Double(max(1, move.isPhysical ? defender.stats.defense : defender.stats.spDefense))
        return floor(floor(floor(2 * Double(attacker.level) / 5 + 2) * Double(power) * attack / defense) / 50) + 2
    }

    private static func modifier(_ move: PokeMove, attacker: Combatant, effectiveness: Double) -> Double {
        let stab = move.id != PokeMove.struggle.id && attacker.types.contains(move.type) ? 1.5 : 1
        // A burn halves physical attacks.
        let burn = attacker.status == .burn && move.isPhysical ? 0.5 : 1
        return stab * effectiveness * burn
    }

    static func damage(_ move: PokeMove, from attacker: Combatant, to defender: Combatant, critical: Bool, rng: inout SeededRNG) -> Int {
        switch move.damage {
        case .fixed(let amount): return amount
        case .level: return attacker.level
        case .halfHP: return max(1, defender.hp / 2)
        case .power(let power):
            let effectiveness = effectiveness(of: move, against: defender)
            let spread = 0.85 + rng.unit() * 0.15
            let value = baseDamage(power: power, move: move, from: attacker, to: defender)
                * modifier(move, attacker: attacker, effectiveness: effectiveness) * (critical ? 2 : 1) * spread
            return max(1, Int(value))
        }
    }

    private static func rollCritical(_ move: PokeMove, rng: inout SeededRNG) -> Bool {
        guard move.power != nil else { return false }
        return rng.unit() < (move.critStage > 0 ? 1.0 / 8 : 1.0 / 16)
    }

    /// Gen 3's odds for 2–5 hit moves: 2 and 3 hits 3/8 each, 4 and 5 hits 1/8 each.
    private static func hitCount(_ move: PokeMove, rng: inout SeededRNG) -> Int {
        guard move.maxHits > move.minHits else { return move.minHits }
        if move.minHits == 2, move.maxHits == 5 {
            let roll = rng.unit()
            return roll < 0.375 ? 2 : (roll < 0.75 ? 3 : (roll < 0.875 ? 4 : 5))
        }
        return rng.pick(move.minHits...move.maxHits)
    }
}
