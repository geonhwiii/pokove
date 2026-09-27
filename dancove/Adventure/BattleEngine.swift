import Foundation

// The adventure's rules: stats, damage, stages and an auto-battle that advances one action per
// tick. Pure value types, so scripts/adventure-sim.swift can run it outside the app.

/// SplitMix64: small, fast and reproducible, so a stage always holds the same Pokémon.
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

    static func level(forXP xp: Int) -> Int {
        var level = max(1, Int(cbrt(Double(max(xp, 1)))))
        while level < maxLevel, xp >= self.xp(forLevel: level + 1) { level += 1 }
        while level > 1, xp < self.xp(forLevel: level) { level -= 1 }
        return min(level, maxLevel)
    }

    /// Experience for knocking out a Pokémon, shared in full by the whole party.
    /// It grows much slower than the L³ curve, so early levels come quickly and later ones take
    /// real work.
    static func defeatXP(baseExperience: Int, level: Int, boss: Bool) -> Int {
        let xp = Double(baseExperience) * (1 + Double(level) / 50) * xpScale
        return max(1, Int(boss ? xp * 3 : xp))
    }

    /// Tuning knob for how fast the party grows (see scripts/adventure-sim.swift).
    nonisolated(unsafe) static var xpScale = 0.12
}

/// One Pokémon on the field.
nonisolated struct Combatant: Identifiable, Equatable, Sendable {
    let id: UUID
    var speciesID: Int
    var level: Int
    var types: [PokeType]
    var stats: PokeStats
    var hp: Int
    var isBoss = false
    /// The party member this is, for experience and evolution.
    var ownedID: UUID?

    var maxHP: Int { stats.hp }
    var isFainted: Bool { hp <= 0 }
    var hpFraction: Double { maxHP > 0 ? Double(max(0, hp)) / Double(maxHP) : 0 }

    init(species: PokeSpecies, level: Int, isBoss: Bool = false, ownedID: UUID? = nil) {
        id = UUID()
        speciesID = species.id
        self.level = level
        types = species.types
        var stats = PokeMath.stats(species.stats, level: level)
        if isBoss { stats.hp = Int(Double(stats.hp) * Stage.bossHPMultiplier) }
        self.stats = stats
        hp = stats.hp
        self.isBoss = isBoss
        self.ownedID = ownedID
    }

    /// After a level-up or evolution: new stats, keeping the damage already taken.
    mutating func become(_ species: PokeSpecies, level: Int) {
        let taken = maxHP - hp
        speciesID = species.id
        self.level = level
        types = species.types
        stats = PokeMath.stats(species.stats, level: level)
        hp = isFainted ? 0 : max(1, stats.hp - taken)
    }
}

nonisolated struct Stage: Codable, Hashable, Comparable, Sendable {
    var world: Int
    var number: Int

    static let first = Stage(world: 1, number: 1)
    static let perWorld = 10
    static let bossHPMultiplier = 2.5
    static let bossLevelBonus = 4

    var index: Int { (world - 1) * Self.perWorld + (number - 1) }
    var isBoss: Bool { number == Self.perWorld }
    var next: Stage { number < Self.perWorld ? Stage(world: world, number: number + 1) : Stage(world: world + 1, number: 1) }
    var label: String { "\(world)-\(number)" }

    /// The level wild Pokémon have here.
    var enemyLevel: Int { min(PokeMath.maxLevel - Self.bossLevelBonus, 3 + Int((Double(index) * Self.levelStep).rounded())) }
    static let levelStep = 1.5

    static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.index < rhs.index }
}

/// Where the party is: the first stage not yet cleared, and whether it's training on the one
/// before after being wiped out there.
nonisolated struct StageProgress: Codable, Equatable, Sendable {
    var frontier = Stage.first
    /// Clears of the previous stage still to go before trying the frontier again.
    var training = 0

    static let trainingClears = 3

    var current: Stage {
        guard training > 0, frontier.index > 0 else { return frontier }
        return Stage(index: frontier.index - 1)
    }

    var isTraining: Bool { current != frontier }

    /// Returns true when this clear opened a new stage.
    @discardableResult
    mutating func record(cleared: Bool) -> Bool {
        if cleared {
            if isTraining { training -= 1; return false }
            frontier = frontier.next
            return true
        }
        training = frontier.index > 0 ? Self.trainingClears : 0
        return false
    }
}

nonisolated extension Stage {
    init(index: Int) {
        self.init(world: index / Stage.perWorld + 1, number: index % Stage.perWorld + 1)
    }
}

nonisolated struct StageEnemy: Codable, Equatable, Sendable {
    var speciesID: Int
    var level: Int
    var isBoss: Bool
}

nonisolated struct StagePlan: Equatable, Sendable {
    let stage: Stage
    let waves: [[StageEnemy]]

    /// The same stage always holds the same Pokémon.
    static func make(for stage: Stage, dex: DexView) -> StagePlan {
        var rng = SeededRNG(seed: UInt64(stage.index + 1) &* 0x2545_F491_4F6C_DD1D)
        let level = stage.enemyLevel
        if stage.isBoss {
            let boss = pickBoss(level: level + Stage.bossLevelBonus, world: stage.world, dex: dex, rng: &rng)
            return StagePlan(stage: stage, waves: [[StageEnemy(speciesID: boss, level: level + Stage.bossLevelBonus, isBoss: true)]])
        }
        let pool = dex.species.filter { !$0.isSpecial && fits($0, level: level, dex: dex) }
        var waves: [[StageEnemy]] = []
        for wave in 0..<3 {
            let count = rng.unit() < 0.35 + Double(wave) * 0.15 + Double(stage.index) * 0.01 ? 2 : 1
            waves.append((0..<count).map { _ in
                let species = pool.isEmpty ? 16 : pool[Int(rng.next() % UInt64(pool.count))].id
                let spread = Int(rng.next() % 3) - 1
                return StageEnemy(speciesID: species, level: max(2, level + spread), isBoss: false)
            })
        }
        return StagePlan(stage: stage, waves: waves)
    }

    /// Evolved forms only show up once wild Pokémon are around the level they evolve at.
    private static func fits(_ species: PokeSpecies, level: Int, dex: DexView) -> Bool {
        guard let evolveLevel = species.evolveLevel else { return true }
        return level + 3 >= evolveLevel
    }

    private static func pickBoss(level: Int, world: Int, dex: DexView, rng: inout SeededRNG) -> Int {
        // Every fifth world ends with a legendary.
        if world % 5 == 0 {
            let legends = dex.species.filter(\.isSpecial)
            if !legends.isEmpty { return legends[Int(rng.next() % UInt64(legends.count))].id }
        }
        let strong = dex.species.filter { species in
            guard !species.isSpecial else { return false }
            let evolved = species.evolvesFrom != nil && (species.evolveLevel ?? 0) <= level
            let loner = species.evolvesFrom == nil && dex.evolutions(species.id).isEmpty && species.stats.total >= 440
            return evolved || loner
        }
        let pool = strong.isEmpty ? dex.species.filter { !$0.isSpecial } : strong
        return pool[Int(rng.next() % UInt64(pool.count))].id
    }
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
}

nonisolated struct BattleAttack: Equatable, Sendable {
    let attackerID: UUID
    let targetID: UUID
    let damage: Int
    let effectiveness: Double
    let critical: Bool
    let type: PokeType
    let fainted: Bool
    /// True when the party attacked.
    let byParty: Bool
}

nonisolated enum BattleEvent: Equatable, Sendable {
    case waveStarted(Int)
    case attack(BattleAttack)
    case stageCleared(Stage)
    case wiped(Stage)
}

/// A stage in progress. `step()` plays one action; the app calls it about once a second while an
/// agent works.
nonisolated struct BattleState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case intro(Int)
        case fighting
        case betweenWaves(Int)
        case clearing(Int)
        case wiping(Int)
        case over(cleared: Bool)
    }

    let plan: StagePlan
    private(set) var waveIndex = 0
    var party: [Combatant]
    private(set) var enemies: [Combatant] = []
    private(set) var phase: Phase = .intro(1)
    private var queue: [UUID] = []
    private var actionsThisWave = 0
    private var rng: SeededRNG

    var stage: Stage { plan.stage }
    var waveCount: Int { plan.waves.count }
    var isOver: Bool { if case .over = phase { true } else { false } }

    init(plan: StagePlan, party: [Combatant], dex: DexView, seed: UInt64) {
        self.plan = plan
        self.party = party
        rng = SeededRNG(seed: seed)
        enemies = Self.spawn(plan.waves.first ?? [], dex: dex)
    }

    private static func spawn(_ wave: [StageEnemy], dex: DexView) -> [Combatant] {
        wave.compactMap { enemy in
            dex[enemy.speciesID].map { Combatant(species: $0, level: enemy.level, isBoss: enemy.isBoss) }
        }
    }

    func combatant(_ id: UUID) -> Combatant? {
        party.first { $0.id == id } ?? enemies.first { $0.id == id }
    }

    mutating func step(dex: DexView) -> BattleEvent? {
        switch phase {
        case .intro(let ticks):
            if ticks > 0 { phase = .intro(ticks - 1); return nil }
            phase = .fighting
            return .waveStarted(waveIndex)
        case .betweenWaves(let ticks):
            if ticks > 0 { phase = .betweenWaves(ticks - 1); return nil }
            waveIndex += 1
            enemies = Self.spawn(plan.waves[waveIndex], dex: dex)
            queue = []
            actionsThisWave = 0
            phase = .fighting
            return .waveStarted(waveIndex)
        case .clearing(let ticks):
            if ticks > 0 { phase = .clearing(ticks - 1); return nil }
            phase = .over(cleared: true)
            return .stageCleared(stage)
        case .wiping(let ticks):
            if ticks > 0 { phase = .wiping(ticks - 1); return nil }
            phase = .over(cleared: false)
            return .wiped(stage)
        case .over:
            return nil
        case .fighting:
            return act()
        }
    }

    private mutating func act() -> BattleEvent? {
        actionsThisWave += 1
        // A stalemate (say, nothing can touch a Ghost) ends as a loss rather than running forever.
        if actionsThisWave > 240 {
            phase = .wiping(1)
            return nil
        }
        var actorID: UUID?
        while actorID == nil {
            if queue.isEmpty {
                queue = (party + enemies).filter { !$0.isFainted }
                    .sorted { $0.stats.speed == $1.stats.speed ? rng.unit() < 0.5 : $0.stats.speed > $1.stats.speed }
                    .map(\.id)
                if queue.isEmpty { return nil }
            }
            let next = queue.removeFirst()
            if let actor = combatant(next), !actor.isFainted { actorID = next }
        }
        guard let actorID, let attacker = combatant(actorID) else { return nil }
        let byParty = party.contains { $0.id == actorID }

        let targetIndex: Int?
        if byParty {
            targetIndex = enemies.firstIndex { !$0.isFainted }
        } else {
            // Enemies favor the front of the party.
            let living = party.indices.filter { !party[$0].isFainted }
            targetIndex = living.isEmpty ? nil : (rng.unit() < 0.5 ? living[0] : living[Int(rng.next() % UInt64(living.count))])
        }
        guard let targetIndex else { return nil }
        let defender = byParty ? enemies[targetIndex] : party[targetIndex]
        let hit = Self.damage(from: attacker, to: defender, rng: &rng)
        if byParty { enemies[targetIndex].hp -= hit.damage } else { party[targetIndex].hp -= hit.damage }
        let fainted = (byParty ? enemies[targetIndex] : party[targetIndex]).isFainted

        if enemies.allSatisfy(\.isFainted) {
            phase = waveIndex + 1 < plan.waves.count ? .betweenWaves(1) : .clearing(1)
        } else if party.allSatisfy(\.isFainted) {
            phase = .wiping(1)
        }
        return .attack(BattleAttack(
            attackerID: attacker.id, targetID: defender.id, damage: hit.damage, effectiveness: hit.effectiveness,
            critical: hit.critical, type: hit.type, fainted: fainted, byParty: byParty
        ))
    }

    /// The main-series formula at power 50 with the attacker's best type against the target.
    static func damage(from attacker: Combatant, to defender: Combatant, rng: inout SeededRNG)
        -> (damage: Int, effectiveness: Double, critical: Bool, type: PokeType) {
        let type = attacker.types.max { $0.effectiveness(against: defender.types) < $1.effectiveness(against: defender.types) } ?? .normal
        let effectiveness = type.effectiveness(against: defender.types)
        let physical = attacker.stats.attack >= attacker.stats.spAttack
        let attack = Double(physical ? attacker.stats.attack : attacker.stats.spAttack)
        let defense = Double(max(1, physical ? defender.stats.defense : defender.stats.spDefense))
        let base = floor(floor((2 * Double(attacker.level) / 5 + 2) * 50 * attack / defense) / 50) + 2
        let critical = rng.unit() < 1.0 / 16
        let spread = 0.85 + rng.unit() * 0.15
        // Immunities still chip a little, so every fight can end.
        let multiplier = 1.5 * max(effectiveness, 0.25) * (critical ? 1.5 : 1) * spread
        return (max(1, Int(base * multiplier)), effectiveness, critical, type)
    }
}

/// Who turns up at the end of an agent's turn: anyone in the dex, weighted by how common they
/// are. Evolved forms and legendaries are rarer.
nonisolated enum WildEncounter {
    /// Turns shorter than this end before anything shows up.
    static let minimumTurn: TimeInterval = 20

    static func weight(of species: PokeSpecies, dex: DexView) -> Double {
        if species.isSpecial { return 10 }
        let stageFactor: Double = switch dex.stage(of: species.id) {
        case 1: 1
        case 2: 0.3
        default: 0.12
        }
        return Double(max(species.captureRate, 3)) * stageFactor
    }

    /// `partyLevel` is the party's average: a newcomer arrives a little behind it, so it's worth
    /// raising without jumping ahead of the Pokémon already raised.
    static func roll(dex: DexView, partyLevel: Int, rng: inout SeededRNG) -> StageEnemy? {
        let weights = dex.species.map { weight(of: $0, dex: dex) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var pick = rng.unit() * total
        var chosen = dex.species[0]
        for (species, weight) in zip(dex.species, weights) {
            if pick < weight { chosen = species; break }
            pick -= weight
        }
        return StageEnemy(speciesID: chosen.id, level: level(of: chosen, partyLevel: partyLevel, rng: &rng), isBoss: false)
    }

    static func level(of species: PokeSpecies, partyLevel: Int, rng: inout SeededRNG) -> Int {
        let spread = Int(rng.next() % 5) - 2
        var level = max(3, Int(Double(partyLevel) * 0.85) - 1 + spread)
        // Evolved forms are never below the level they evolve at: a lucky find.
        if let evolveLevel = species.evolveLevel { level = max(level, evolveLevel) }
        if species.isSpecial { level = max(level, 40) }
        return min(level, PokeMath.maxLevel)
    }

    static func captureChance(of species: PokeSpecies) -> Double {
        if species.isSpecial { return 0.35 }
        return 0.55 + 0.35 * Double(species.captureRate) / 255
    }

    /// Catching one you already have is worth about a third of a level to it.
    static func duplicateXP(level: Int) -> Int { max(20, level * level) }

    /// Most turns bring someone along; not all.
    static let encounterChance = 0.6
}
