import Foundation

// Progress along the journey, discoveries, the gacha, the daily dungeon and rewards. Pure rules,
// shared with the simulation script.

/// A station on a chapter's line; both indexes are 0-based.
nonisolated struct StationPoint: Codable, Hashable, Sendable {
    var chapter: Int
    var station: Int
}

/// What the party is fighting.
nonisolated enum BattleTarget: Equatable, Sendable {
    /// A station, while an agent works.
    case station(StationPoint)
    /// A chapter's boss: its gym leader, or one of the League's five.
    case boss(chapter: Int, index: Int)
    case legend(String)
    case dungeon(DungeonTier)

    /// Everything but stations is a challenge, which plays out whether or not an agent works.
    var isChallenge: Bool { if case .station = self { false } else { true } }
}

/// How far the journey has come, and where on the line the party fights.
nonisolated struct JourneyProgress: Codable, Equatable, Sendable {
    /// The current chapter, 0-based. After the League it stays on the last chapter, which loops.
    var chapter = 0
    /// Stations cleared in the current chapter; `Chapter.stationCount` once its boss is next.
    var station = 0
    /// The next of the chapter's bosses (the League has five).
    var boss = 0
    /// Clears of an earlier station still to go after a loss, before trying again.
    var training = 0
    /// A cleared station the user picked to repeat.
    var repeating: StationPoint?
    /// Counts clears while looping the last chapter.
    var cursor = 0
    var badges = 0
    var isChampion = false
    var beatenLegends: [String] = []
    /// Losses in a row to the current boss.
    var losses = 0
    /// After a loss, AUTO tries again once the party reaches this level, even mid-training.
    var retryLevel: Int?

    func hasReached(chapter index: Int) -> Bool { index <= chapter }

    /// Stations cleared on a chapter's line.
    func cleared(in index: Int) -> Int {
        index < chapter ? Chapter.stationCount : (index == chapter ? min(station, Chapter.stationCount) : 0)
    }

    func isCleared(_ point: StationPoint) -> Bool { point.station < cleared(in: point.chapter) }

    /// The boss waiting at the end of the current line, if it has one.
    func nextBoss(_ chapters: [Chapter]) -> (chapter: Int, index: Int)? {
        guard chapters.indices.contains(chapter), chapters[chapter].bosses.indices.contains(boss) else { return nil }
        return (chapter, boss)
    }

    /// The line is cleared, so its boss can be challenged.
    func isBossOpen(_ chapters: [Chapter]) -> Bool { station >= Chapter.stationCount && nextBoss(chapters) != nil }

    /// AUTO takes the boss on as soon as the line is cleared. After a loss it trains first, and
    /// tries again sooner if a level gained gives it a fair chance (`chance` is the forecast).
    func wantsBoss(_ chapters: [Chapter], auto: Bool, partyLevel: Int, chance: () -> Double) -> Bool {
        guard auto, isBossOpen(chapters) else { return false }
        if training == 0 { return true }
        guard let retryLevel, partyLevel >= retryLevel else { return false }
        return chance() >= AutoChallenge.earlyRetryChance
    }

    var isTraining: Bool { training > 0 && repeating == nil }

    /// Where the party fights while an agent works.
    func stationTarget(_ chapters: [Chapter]) -> StationPoint {
        if let repeating { return repeating }
        let last = Chapter.stationCount - 1
        if station < Chapter.stationCount {
            // After a loss on the line, a few clears of the station before.
            if training > 0, station > 0 { return StationPoint(chapter: chapter, station: station - 1) }
            return StationPoint(chapter: chapter, station: station)
        }
        // A line with no boss (after the League) loops; otherwise the party trains at its last station.
        if nextBoss(chapters) == nil { return StationPoint(chapter: chapter, station: cursor % Chapter.stationCount) }
        return StationPoint(chapter: chapter, station: last)
    }

    enum Outcome: Equatable, Sendable {
        case none
        /// A new station opened, or the next of the League's five.
        case advanced
        case badge(Int)
        case champion
        case legend(String)
    }

    @discardableResult
    mutating func recordStation(_ point: StationPoint, cleared: Bool, chapters: [Chapter]) -> Outcome {
        let frontier = StationPoint(chapter: chapter, station: station)
        if repeating == nil, training == 0, point == frontier, station < Chapter.stationCount {
            guard cleared else {
                training = point.station > 0 ? AutoChallenge.wildTraining : 0
                return .none
            }
            station += 1
            return .advanced
        }
        guard cleared else { return .none }
        if training > 0 { training -= 1 }
        if station >= Chapter.stationCount, nextBoss(chapters) == nil { cursor += 1 }
        return .none
    }

    @discardableResult
    mutating func recordBoss(cleared: Bool, chapters: [Chapter], partyLevel: Int) -> Outcome {
        guard let next = nextBoss(chapters) else { return .none }
        guard cleared else {
            losses += 1
            training = AutoChallenge.trainingClears
            retryLevel = partyLevel + 1
            return .none
        }
        losses = 0
        training = 0
        retryLevel = nil
        let current = chapters[next.chapter]
        if current.isLeague, next.index + 1 < current.bosses.count {
            boss += 1
            return .advanced
        }
        if let badge = current.badge { badges = max(badges, badge) }
        if current.isLeague { isChampion = true }
        chapter = min(chapter + 1, chapters.count - 1)
        station = 0
        boss = 0
        repeating = nil
        cursor = 0
        return current.isLeague ? .champion : (current.badge.map { .badge($0) } ?? .advanced)
    }

    @discardableResult
    mutating func recordLegend(_ id: String, cleared: Bool) -> Outcome {
        guard cleared else { return .none }
        if !beatenLegends.contains(id) { beatenLegends.append(id) }
        return .legend(id)
    }
}

extension JourneyProgress {
    /// v2 walked 28 map nodes. Each maps onto a chapter; stations are in proportion to the stages
    /// cleared there, and a node with a trainer means the line is done and its boss is next.
    static func migrated(fromNode node: Int, stage: Int, badges: Int, isChampion: Bool, beatenLegends: [String]) -> JourneyProgress {
        // (chapter, wild stages) per v2 node; 0 stages marks a gym or the League.
        let legacy: [(chapter: Int, stages: Int)] = [
            (0, 3), (0, 3), (0, 0), (1, 3), (1, 3), (1, 3), (1, 0), (2, 3), (2, 2), (2, 0), (3, 2), (3, 3), (3, 3), (3, 2), (3, 0),
            (4, 3), (4, 3), (4, 3), (4, 0), (5, 0), (6, 3), (6, 3), (6, 0), (7, 2), (7, 0), (8, 3), (8, 0), (9, 3),
        ]
        var progress = JourneyProgress()
        progress.badges = badges
        progress.isChampion = isChampion
        progress.beatenLegends = beatenLegends
        guard legacy.indices.contains(node) else {
            progress.chapter = 9
            progress.station = Chapter.stationCount
            return progress
        }
        let entry = legacy[node]
        progress.chapter = entry.chapter
        if entry.stages == 0 {
            progress.station = Chapter.stationCount
            progress.boss = max(0, stage)
            return progress
        }
        let routes = legacy.indices.filter { legacy[$0].chapter == entry.chapter && legacy[$0].stages > 0 }
        let total = routes.reduce(0) { $0 + legacy[$1].stages }
        let before = routes.filter { $0 < node }.reduce(0) { $0 + legacy[$1].stages }
        progress.station = min(Chapter.stationCount - 1, (before + max(0, stage)) * Chapter.stationCount / max(1, total))
        return progress
    }
}

// MARK: Challenging bosses

nonisolated enum AutoChallenge {
    /// After a loss to a boss, the most clears of the last station before the next try; a level
    /// gained ends the training sooner.
    static let trainingClears = 30
    /// After a rare loss on the line, clears of the station before.
    static let wildTraining = 3
    /// A level gained mid-training only brings the next try forward with at least this chance.
    static let earlyRetryChance = 0.15
    /// Losses in a row before the recap points at the best-team button.
    static let hintAfterLosses = 3
}

/// Plays a stage out many times ahead of time to estimate the chance of winning it.
nonisolated enum Forecast {
    static func winChance(party: [Combatant], plan: StagePlan, data: GameData, trials: Int = 24) -> Double {
        guard !party.isEmpty else { return 0 }
        var rng = SeededRNG(seed: 0x5EED)
        var wins = 0
        for _ in 0..<trials {
            var battle = BattleState(plan: plan, party: party, data: data, seed: rng.next())
            var steps = 0
            while !battle.isOver, steps < 2000 {
                if battle.step() == .cleared { wins += 1 }
                steps += 1
            }
        }
        return Double(wins) / Double(trials)
    }
}

// MARK: Discovery

/// A wild Pokémon that turns up while an agent works and joins at once.
nonisolated enum Discovery {
    /// On average one every this much agent work; quicker until the party is three, so the
    /// first hour isn't lonely.
    static func meanInterval(boxCount: Int) -> TimeInterval {
        boxCount < 3 ? 6 * 60 : 20 * 60
    }

    /// Where discoveries come from: the stretch of the station being fought.
    static func pool(at point: StationPoint, data: GameData) -> [(species: Int, share: Double)] {
        guard data.chapters.indices.contains(point.chapter), data.chapters[point.chapter].stations.indices.contains(point.station) else {
            return []
        }
        return data.encounters.pool(for: data.chapters[point.chapter].stations[point.station].stretch, dex: data.dex)
    }

    static func roll(pool: [(species: Int, share: Double)], rng: inout SeededRNG) -> Int? {
        rng.weighted(pool.map(\.share)).map { pool[$0].species }
    }

    /// A newcomer arrives a little behind the party, so it's worth raising without jumping ahead.
    static func level(of species: PokeSpecies, partyLevel: Int, cap: Int, rng: inout SeededRNG) -> Int {
        var level = max(3, Int(Double(partyLevel) * 0.85) - 1 + rng.pick(-2...2))
        // Evolved forms are never below the level they evolve at: a lucky find.
        if let evolveLevel = species.evolveLevel { level = max(level, evolveLevel) }
        return min(level, cap, PokeMath.maxLevel)
    }

    /// Meeting one you already have is worth about a third of a level to it.
    static func duplicateXP(level: Int) -> Int { max(20, level * level) }
}

// MARK: Gacha

nonisolated struct GachaCard: Codable, Identifiable, Equatable, Sendable {
    enum Rarity: Int, Codable, Comparable, Sendable {
        case common, uncommon, rare, mythical

        static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }

        var weight: Double {
            switch self {
            case .common: 10
            case .uncommon: 5
            case .rare: 2.2
            case .mythical: 0.2
            }
        }
    }

    let id: UUID
    let species: Int
    let level: Int
    let rarity: Rarity
}

/// Three face-up cards; the user keeps one. Nothing can go wrong.
nonisolated enum Gacha {
    /// In stardust.
    static let price = 400
    static let cardCount = 3
    /// A new journey starts with one pull's worth.
    static let startingStardust = price

    /// Every species met so far on the journey, plus gacha-only ones unlocked along the way.
    static func pool(progress: JourneyProgress, data: GameData) -> [(species: Int, rarity: GachaCard.Rarity)] {
        var best: [Int: Double] = [:]
        var stretches: Set<String> = []
        for (index, chapter) in data.chapters.enumerated() where progress.hasReached(chapter: index) {
            let reached = index < progress.chapter ? chapter.stations.count : min(progress.station + 1, chapter.stations.count)
            for station in chapter.stations.prefix(reached) where stretches.insert(station.stretch.id).inserted {
                for entry in data.encounters.pool(for: station.stretch, dex: data.dex) {
                    best[entry.species] = max(best[entry.species] ?? 0, entry.share)
                }
            }
        }
        var pool: [(species: Int, rarity: GachaCard.Rarity)] = best.map { species, share in
            (species, share >= 15 ? .common : (share >= 5 ? .uncommon : .rare))
        }
        for (species, chapter) in Kanto.gachaOnly where progress.hasReached(chapter: chapter) && best[species] == nil {
            pool.append((species, .rare))
        }
        if progress.isChampion { pool.append((Kanto.mew, .mythical)) }
        return pool.sorted { $0.species < $1.species }
    }

    /// Three different species, weighted by rarity. Lines you already have come up less often
    /// (`duplicateWeight`), and not at all when it's 0. With a `floor` (the dungeon's Ultra Ball),
    /// only that rarity and up, topped up with the next rarest if there aren't three.
    static func draw(pool: [(species: Int, rarity: GachaCard.Rarity)], level: (Int) -> Int, isOwned: (Int) -> Bool,
                     duplicateWeight: Double = 0.3, floor: GachaCard.Rarity = .common, rng: inout SeededRNG) -> [GachaCard] {
        let allowed = pool.filter { duplicateWeight > 0 || !isOwned($0.species) }
        var remaining = allowed.filter { $0.rarity >= floor }
        if remaining.count < cardCount {
            let below = allowed.filter { $0.rarity < floor }.sorted { $0.rarity > $1.rarity }
            remaining += below.prefix(cardCount - remaining.count)
        }
        var cards: [GachaCard] = []
        while cards.count < cardCount,
              let index = rng.weighted(remaining.map { $0.rarity.weight * (isOwned($0.species) ? duplicateWeight : 1) }) {
            let entry = remaining.remove(at: index)
            cards.append(GachaCard(id: UUID(), species: entry.species, level: level(entry.species), rarity: entry.rarity))
        }
        return cards
    }

    /// Picking one you already have: about half a level for it.
    static func duplicateXP(level: Int) -> Int { max(40, 2 * level * level) }
}

// MARK: Rewards

nonisolated enum Rewards {
    /// Stardust for winning. The dungeon pays per tier instead (`DailyDungeon.stardust`).
    static func stardust(for kind: StagePlan.Kind) -> Int {
        switch kind {
        case .wild: 1
        case .trainer: 30
        case .legend: 60
        case .dungeon: 0
        }
    }
}

// MARK: Daily dungeon

nonisolated enum DungeonTier: String, Codable, CaseIterable, Comparable, Sendable {
    case easy, normal, hard

    static func < (lhs: DungeonTier, rhs: DungeonTier) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Levels from the party's.
    var levelOffset: Int {
        switch self {
        case .easy: -6
        case .normal: -2
        case .hard: 3
        }
    }

    /// The last floor's boss has this much more HP than its level gives.
    var bossHP: Double {
        switch self {
        case .easy: 1.5
        case .normal, .hard: 2
        }
    }
}

/// Which tiers have paid out on a dungeon day.
nonisolated struct DungeonDay: Codable, Equatable, Sendable {
    var day: String
    var claimed: [DungeonTier] = []
}

/// Five floors of the day's type, the last a boss; each tier pays once a day.
nonisolated enum DailyDungeon {
    static let resetHour = 4
    static let floors = 5
    static let bossLevels = 1
    static let stardust: [DungeonTier: Int] = [.easy: 60, .normal: 120]

    /// The dungeon day a moment belongs to: days turn over at 04:00 local time.
    static func day(of date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted(date))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func nextReset(after date: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: shifted(date))
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: resetHour, minute: 0, second: 0, of: next) ?? next
    }

    private static func shifted(_ date: Date) -> Date { date.addingTimeInterval(-Double(resetHour) * 3600) }

    /// The type of the day, by weekday.
    static func types(on date: Date, calendar: Calendar = .current) -> [PokeType] {
        switch calendar.component(.weekday, from: shifted(date)) {
        case 1: [.dragon, .ghost]
        case 2: [.grass]
        case 3: [.fire]
        case 4: [.water]
        case 5: [.electric]
        case 6: [.psychic, .fighting]
        default: [.rock, .ground]
        }
    }

    static func scenery(for types: [PokeType]) -> Scenery {
        switch types.first {
        case .grass: .forest
        case .fire: .volcano
        case .water: .sea
        case .electric: .plant
        case .rock: .cave
        default: .tower
        }
    }

    static func level(_ tier: DungeonTier, partyLevel: Int, cap: Int) -> Int {
        max(2, min(partyLevel + tier.levelOffset, cap))
    }

    /// Species of the day's types that could be met at a level, legendaries aside. `evolved`
    /// keeps each line only in the most evolved form it would have by then, for the boss.
    static func species(types: [PokeType], level: Int, evolved: Bool, dex: DexView) -> [PokeSpecies] {
        let matching = dex.species.filter { species in
            !species.isSpecial && !Set(species.types).isDisjoint(with: types) && (species.evolveLevel ?? 0) <= level
                && (!evolved || !dex.evolutions(species.id).contains { (dex[$0]?.evolveLevel ?? .max) <= level })
        }
        return matching.isEmpty ? dex.species.filter { !$0.isSpecial && ($0.evolveLevel ?? 0) <= level } : matching
    }

    /// The same floors all day for a tier, so a retry faces what beat you.
    static func plan(_ tier: DungeonTier, on date: Date, partyLevel: Int, cap: Int, data: GameData) -> StagePlan {
        let day = day(of: date)
        var rng = SeededRNG(seed: (day + tier.rawValue).unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
        let types = types(on: date)
        let level = level(tier, partyLevel: partyLevel, cap: cap)
        let foes = (0..<floors).map { floor -> StagePlan.Foe in
            let isBoss = floor == floors - 1
            // Floors climb to the tier's level; the boss stands a little above it.
            let floorLevel = isBoss ? level + bossLevels : max(2, level - (floors - 2) + floor)
            var candidates = species(types: types, level: floorLevel, evolved: isBoss, dex: data.dex)
            // The boss is one of the strongest of the day.
            if isBoss { candidates = Array(candidates.sorted { $0.stats.total > $1.stats.total }.prefix(3)) }
            let pick = candidates.isEmpty ? 19 : candidates[Int(rng.next() % UInt64(candidates.count))].id
            return StagePlan.Foe(species: pick, level: floorLevel, hpScale: isBoss ? tier.bossHP : 1)
        }
        return StagePlan(kind: .dungeon(tier), foes: foes, scenery: scenery(for: types))
    }
}

// MARK: Party suggestions

nonisolated enum Recommend {
    struct Candidate: Sendable {
        let id: UUID
        let species: PokeSpecies
        let level: Int
    }

    /// The three best for a stage: against a trainer or legendary, whoever wins its matchups
    /// fastest while taking the least; against wild Pokémon, simply the strongest.
    static func party(from candidates: [Candidate], against foes: [StagePlan.Foe], data: GameData, size: Int = 3) -> [UUID] {
        func fighter(_ candidate: Candidate) -> Combatant {
            Combatant(species: candidate.species, level: candidate.level, moves: data.moves)
        }
        let opponents = foes.compactMap { foe in data.dex[foe.species].map { Combatant(species: $0, level: foe.level, moves: data.moves) } }
        func score(_ candidate: Candidate) -> Double {
            let me = fighter(candidate)
            guard !opponents.isEmpty else { return Double(candidate.level) * 1000 + Double(candidate.species.stats.total) }
            // Each matchup as the chance of winning it: how many turns each side needs, with
            // Struggle when nothing else lands, and the faster one getting the first hit.
            return opponents.reduce(0) { total, foe in
                let offense = best(from: me, to: foe) / Double(max(1, foe.maxHP))
                let defense = best(from: foe, to: me) / Double(max(1, me.maxHP))
                let mine = (1 / max(offense, 0.005)).rounded(.up) - (me.stats.speed >= foe.stats.speed ? 0.5 : 0)
                let theirs = (1 / max(defense, 0.005)).rounded(.up)
                return total + theirs / (mine + theirs)
            }
        }
        func best(from attacker: Combatant, to defender: Combatant) -> Double {
            let damage = attacker.moves.map { BattleState.expectedDamage($0, from: attacker, to: defender) }.max() ?? 0
            return damage > 0 ? damage : BattleState.expectedDamage(PokeMove.struggle, from: attacker, to: defender)
        }
        let ranked = candidates.map { ($0.id, score($0)) }.sorted { $0.1 > $1.1 }
        return ranked.prefix(size).map(\.0)
    }
}
