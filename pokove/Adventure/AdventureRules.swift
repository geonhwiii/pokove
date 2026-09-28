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
    /// A gym leader, or one of the League's five, by the chapter they belong to.
    case boss(chapter: Int, index: Int)
    case legend(String)
    /// A daily dungeon's stage.
    case dungeon(DungeonKind, stage: Int)
    /// A Battle Tower floor, from 1, after the Champion.
    case tower(Int)

    /// Everything but stations is a challenge, which plays out whether or not an agent works.
    var isChallenge: Bool { if case .station = self { false } else { true } }

    /// Challenges open with the VS card, except tower floors after the first, which follow on at once.
    var showsIntro: Bool {
        if case .tower(let floor) = self { return floor == 1 }
        return isChallenge
    }
}

/// How far the journey has come, and where on the line the party fights. The stage line and the
/// gyms are separate: the line runs on from chapter to chapter, and a chapter's gym opens once its
/// line is cleared. Badges raise the level cap.
nonisolated struct JourneyProgress: Codable, Equatable, Sendable {
    /// The chapter the line is on, 0-based. The one after the League waits for the Champion.
    var chapter = 0
    /// Stations cleared in the current chapter; `Chapter.stationCount` once the last open line is done.
    var station = 0
    /// The next of the League's five, once the eight badges are in.
    var boss = 0
    /// Clears of the station before still to go after a loss on the line.
    var training = 0
    /// A cleared station the user picked to repeat.
    var repeating: StationPoint?
    /// Counts clears while looping the last open line.
    var cursor = 0
    var badges = 0
    var isChampion = false
    var beatenLegends: [String] = []
    /// Losses in a row to the current boss.
    var losses = 0
    /// Wild Pokémon beaten at the next station so far (optional so older saves still read).
    var frontierWins: Int?

    /// Wild Pokémon beaten at the next station so far; it opens at `Chapter.winsNeeded`.
    var wins: Int { frontierWins ?? 0 }

    func hasReached(chapter index: Int) -> Bool { index <= chapter }

    /// Stations cleared on a chapter's line.
    func cleared(in index: Int) -> Int {
        index < chapter ? Chapter.stationCount : (index == chapter ? min(station, Chapter.stationCount) : 0)
    }

    func isCleared(_ point: StationPoint) -> Bool { point.station < cleared(in: point.chapter) }

    /// The furthest chapter the line runs to: the one after the League opens with the Champion.
    func lastChapter(_ chapters: [Chapter]) -> Int {
        guard !isChampion, let league = chapters.firstIndex(where: \.isLeague) else { return chapters.count - 1 }
        return league
    }

    /// The last open line is cleared, so the party goes round it.
    var isLooping: Bool { station >= Chapter.stationCount }

    /// The next gym leader in badge order, then the League's five one after another.
    func nextBoss(_ chapters: [Chapter]) -> (chapter: Int, index: Int)? {
        guard !isChampion, let index = chapters.firstIndex(where: { $0.isLeague || ($0.badge ?? 0) > badges }) else { return nil }
        let member = chapters[index].isLeague ? boss : 0
        guard chapters[index].bosses.indices.contains(member) else { return nil }
        return (index, member)
    }

    /// The next boss's chapter is cleared, so it can be challenged.
    func isBossOpen(_ chapters: [Chapter]) -> Bool {
        guard let next = nextBoss(chapters) else { return false }
        return cleared(in: next.chapter) >= Chapter.stationCount
    }

    var isTraining: Bool { training > 0 && repeating == nil }

    var frontier: StationPoint { StationPoint(chapter: chapter, station: station) }

    /// The station before a point, across the start of a chapter. That skips the chapter before's
    /// terminus, which is tougher than the station the party couldn't manage.
    func previous(_ point: StationPoint) -> StationPoint? {
        if point.station > 0 { return StationPoint(chapter: point.chapter, station: point.station - 1) }
        return point.chapter > 0 ? StationPoint(chapter: point.chapter - 1, station: Chapter.stationCount - 2) : nil
    }

    /// Where the party fights while an agent works: the next station, or the one before for a few
    /// clears after losing there.
    func stationTarget(_ chapters: [Chapter]) -> StationPoint {
        if let repeating { return repeating }
        if isLooping { return StationPoint(chapter: chapter, station: cursor % Chapter.stationCount) }
        if training > 0, let before = previous(frontier) { return before }
        return frontier
    }

    /// Stops repeating or training and takes the next station on right away.
    mutating func pushOn() {
        repeating = nil
        training = 0
    }

    enum Outcome: Equatable, Sendable {
        case none
        /// A new station opened, or the next of the League's five.
        case advanced
        /// The line went on to the next chapter; the one behind it opened its gym.
        case chapter
        case badge(Int)
        case champion
        case legend(String)
    }

    /// A battle at a station is over. At the next station, each win counts the Pokémon beaten, and
    /// the line moves on once there are enough.
    @discardableResult
    mutating func recordStation(_ point: StationPoint, cleared: Bool, defeated: Int = 1, chapters: [Chapter]) -> Outcome {
        if repeating == nil, training == 0, point == frontier, !isLooping {
            guard cleared else {
                training = previous(point) != nil ? Losses.wildTraining : 0
                return .none
            }
            let needed = chapters.indices.contains(chapter) && chapters[chapter].stations.indices.contains(station)
                ? Chapter.winsNeeded(chapters[chapter].stations[station], isTerminus: station == Chapter.stationCount - 1) : 1
            frontierWins = wins + defeated
            guard wins >= needed else { return .none }
            frontierWins = 0
            station += 1
            guard isLooping else { return .advanced }
            return moveOn(chapters) ? .chapter : .advanced
        }
        guard cleared else { return .none }
        if training > 0 { training -= 1 }
        if isLooping { cursor += 1 }
        return .none
    }

    /// A cleared line leads straight on to the next chapter, unless that one isn't open yet.
    @discardableResult
    mutating func moveOn(_ chapters: [Chapter]) -> Bool {
        guard isLooping else { return false }
        // Training holds the line back, and a cleared line has nothing left to hold.
        training = 0
        guard chapter < lastChapter(chapters) else { return false }
        chapter += 1
        station = 0
        cursor = 0
        frontierWins = 0
        return true
    }

    @discardableResult
    mutating func recordBoss(cleared: Bool, chapters: [Chapter]) -> Outcome {
        guard let next = nextBoss(chapters) else { return .none }
        guard cleared else {
            losses += 1
            return .none
        }
        losses = 0
        let current = chapters[next.chapter]
        if current.isLeague, next.index + 1 < current.bosses.count {
            boss += 1
            return .advanced
        }
        boss = 0
        if let badge = current.badge {
            badges = max(badges, badge)
            return .badge(badge)
        }
        guard current.isLeague else { return .advanced }
        isChampion = true
        // The line past the League opens.
        moveOn(chapters)
        return .champion
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

    /// A save from when each of Kanto's legs was one chapter: the same place, now in one of its
    /// `parts` chapters.
    mutating func splitChapters(into parts: Int) {
        func split(_ point: StationPoint) -> StationPoint {
            let position = point.station * parts
            return StationPoint(chapter: point.chapter * parts + position / Chapter.stationCount, station: position % Chapter.stationCount)
        }
        if station >= Chapter.stationCount {
            chapter = chapter * parts + parts - 1
        } else {
            let point = split(frontier)
            chapter = point.chapter
            station = point.station
        }
        cursor = 0
        frontierWins = 0
        repeating = repeating.map(split)
    }
}

// MARK: Losing

nonisolated enum Losses {
    /// After a rare loss on the line, clears of the station before.
    static let wildTraining = 3
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
    /// Rolled when the balls are dealt, shown only once one is opened.
    var shiny = false

    init(id: UUID, species: Int, level: Int, rarity: Rarity, shiny: Bool = false) {
        self.id = id
        self.species = species
        self.level = level
        self.rarity = rarity
        self.shiny = shiny
    }

    /// Tolerant, so balls dealt before shinies existed still read.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        species = try container.decode(Int.self, forKey: .species)
        level = try container.decode(Int.self, forKey: .level)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        shiny = try container.decodeIfPresent(Bool.self, forKey: .shiny) ?? false
    }
}

/// Shiny Pokémon: a rare recoloring, rolled for each discovery and each gacha ball.
nonisolated enum Shiny {
    /// One in this many; with about 17 rolls a day, roughly one a week.
    static let odds = 128

    static func roll(_ rng: inout SeededRNG) -> Bool { rng.unit() < 1 / Double(odds) }
}

/// Three face-up cards; the user keeps one. Nothing can go wrong.
nonisolated enum Gacha {
    /// In stardust.
    static let price = 400
    static let cardCount = 3
    /// A new journey starts with one pull's worth.
    static let startingStardust = price

    /// Every Pokémon that starts a line, from the first pull: pulls come a little under the party's
    /// level, so a strong one early grows with the rest instead of carrying them. Rarity follows how
    /// often it's met anywhere in Kanto, and one never met in the wild is rare. Evolved forms come
    /// from evolving, the legendaries by beating them, and Mew once you're the Champion.
    static func pool(progress: JourneyProgress, data: GameData) -> [(species: Int, rarity: GachaCard.Rarity)] {
        var best: [Int: Double] = [:]
        var stretches: Set<String> = []
        for station in data.chapters.flatMap(\.stations) where stretches.insert(station.stretch.id).inserted {
            for entry in data.encounters.pool(for: station.stretch, dex: data.dex) {
                best[entry.species] = max(best[entry.species] ?? 0, entry.share)
            }
        }
        let legends = Set(Kanto.legends.map(\.species))
        var pool: [(species: Int, rarity: GachaCard.Rarity)] = data.dex.species
            .filter { $0.evolvesFrom == nil && !$0.isSpecial && !legends.contains($0.id) }
            .map { species in
                let share = best[species.id] ?? 0
                return (species.id, share >= 15 ? .common : (share >= 5 ? .uncommon : .rare))
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

    /// One to three levels under the party, so a strong pull joins the others rather than carrying
    /// them. Further under (as discoveries come) left it too weak to use for hours in the sim.
    static func level(partyLevel: Int, cap: Int, rng: inout SeededRNG) -> Int {
        min(cap, PokeMath.maxLevel, max(3, partyLevel - 2 + rng.pick(-1...1)))
    }
}

// MARK: Rewards

nonisolated enum Rewards {
    /// Stardust for winning. The dungeons pay by stage instead (`DailyDungeon.stardust(stage:)`).
    static func stardust(for kind: StagePlan.Kind) -> Int {
        switch kind {
        case .wild: 1
        case .trainer: 30
        case .legend: 60
        case .dungeon: 0
        case .tower: BattleTower.stardustPerFloor
        }
    }

    /// Stardust for reaching a new station, or for clearing a line's terminus. Early stations go
    /// by in minutes, so this pays most at the start and fades as stations take longer.
    static func arrival(terminus: Bool) -> Int { terminus ? arrivalTerminus : arrivalStation }

    nonisolated(unsafe) static var arrivalStation = 20
    nonisolated(unsafe) static var arrivalTerminus = 100
}

// MARK: Daily dungeons

/// The two dungeons: one pays stardust, the other experience.
nonisolated enum DungeonKind: String, Codable, CaseIterable, Sendable {
    case stardust, experience
}

/// One dungeon's climb: the highest stage cleared, and the tries left today.
nonisolated struct DungeonClimb: Codable, Equatable, Sendable {
    /// 0 before the first clear.
    var best = 0
    var tries = DailyDungeon.triesPerDay

    /// The stage a try at a new one takes on, while there is one.
    var next: Int? { best < DailyDungeon.stages ? best + 1 : nil }
}

/// Both climbs, and the dungeon day their tries belong to.
nonisolated struct DungeonState: Codable, Equatable, Sendable {
    var day: String
    var stardust = DungeonClimb()
    var experience = DungeonClimb()

    subscript(kind: DungeonKind) -> DungeonClimb {
        get { kind == .stardust ? stardust : experience }
        set { if kind == .stardust { stardust = newValue } else { experience = newValue } }
    }

    /// A new day fills the tries again; the stages stay where they were.
    mutating func refill(for today: String) {
        guard day != today else { return }
        day = today
        stardust.tries = DailyDungeon.triesPerDay
        experience.tries = DailyDungeon.triesPerDay
    }

    /// A try is over. Clearing a new stage moves the climb up and gives the try back; a loss uses
    /// it. True when the stage was cleared for the first time.
    @discardableResult
    mutating func record(_ kind: DungeonKind, stage: Int, cleared: Bool) -> Bool {
        let isNew = cleared && stage == self[kind].next
        if isNew {
            self[kind].best = stage
        } else {
            self[kind].tries = max(0, self[kind].tries - 1)
        }
        return isNew
    }

    /// Clears the best stage again without the battle, for one try. The stage swept, while there
    /// is one and a try left.
    mutating func sweep(_ kind: DungeonKind) -> Int? {
        guard self[kind].best > 0, self[kind].tries > 0 else { return nil }
        self[kind].tries -= 1
        return self[kind].best
    }
}

/// Stages that climb two levels at a time, three Pokémon each, the last a boss. Each dungeon has
/// three tries a day; clearing a new stage gives the try back, so a strong party climbs until it
/// loses, then can sweep its best stage with what's left, for the reward without the battle.
nonisolated enum DailyDungeon {
    static let resetHour = 4
    static let triesPerDay = 3
    static let stages = 50
    static let foesPerStage = 3
    /// The boss has this much more HP than its level gives.
    static let bossHP = 1.5
    /// Every this many stages first cleared in the stardust dungeon pays an Ultra Ball.
    static let ultraBallEvery = 10

    /// Stage 1 is Lv 5, and each stage two more, up to 100.
    static func level(stage: Int) -> Int { min(PokeMath.maxLevel, 3 + 2 * stage) }

    static func stardust(stage: Int) -> Int { 80 + 8 * stage }

    /// A sixth of a level at the stage's level, for each of the party. Half a level made the
    /// Champion come 40% sooner in the sim; a sixth, about 15%.
    static func experience(stage: Int) -> Int {
        let level = min(level(stage: stage), PokeMath.maxLevel - 1)
        return (PokeMath.xp(forLevel: level + 1) - PokeMath.xp(forLevel: level)) / 6
    }

    /// A first clear of this stage in the stardust dungeon brings an Ultra Ball.
    static func paysUltraBall(stage: Int) -> Bool { stage % ultraBallEvery == 0 }

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

    /// The stardust dungeon's types, by weekday. The experience dungeon is always Normal and Fairy.
    static func types(_ kind: DungeonKind, on date: Date, calendar: Calendar = .current) -> [PokeType] {
        guard kind == .stardust else { return [.normal, .fairy] }
        return switch calendar.component(.weekday, from: shifted(date)) {
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
        case .normal: .gym
        default: .tower
        }
    }

    /// Species of the types that could be met at a level, legendaries aside. `evolved` keeps each
    /// line only in the most evolved form it would have by then, for the boss.
    static func species(types: [PokeType], level: Int, evolved: Bool, dex: DexView) -> [PokeSpecies] {
        let matching = dex.species.filter { species in
            !species.isSpecial && !Set(species.types).isDisjoint(with: types) && (species.evolveLevel ?? 0) <= level
                && (!evolved || !dex.evolutions(species.id).contains { (dex[$0]?.evolveLevel ?? .max) <= level })
        }
        return matching.isEmpty ? dex.species.filter { !$0.isSpecial && ($0.evolveLevel ?? 0) <= level } : matching
    }

    /// One Pokémon on stage 1 and two on stage 2, so a lone starter can clear the first; three from
    /// stage 3, the last a boss.
    static func foes(stage: Int) -> Int { min(foesPerStage, max(1, stage)) }

    /// The same foes all day for a stage, so a retry faces what beat you: a little below the stage's
    /// level, then, from stage 3, one of the strongest around at it.
    static func plan(_ kind: DungeonKind, stage: Int, on date: Date, data: GameData) -> StagePlan {
        let key = "\(day(of: date))-\(kind.rawValue)-\(stage)"
        var rng = SeededRNG(seed: key.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
        let types = types(kind, on: date)
        let level = level(stage: stage)
        let count = foes(stage: stage)
        let foes = (0..<count).map { index -> StagePlan.Foe in
            let isBoss = count == foesPerStage && index == count - 1
            // A short stage starts lower still: Lv 2, then Lv 4–5, then Lv 7–9 with the boss.
            let foeLevel = max(2, level - (foesPerStage - 1) + index - (foesPerStage - count))
            var candidates = species(types: types, level: foeLevel, evolved: isBoss, dex: data.dex)
            if isBoss { candidates = Array(candidates.sorted { $0.stats.total > $1.stats.total }.prefix(3)) }
            let pick = candidates.isEmpty ? 19 : candidates[Int(rng.next() % UInt64(candidates.count))].id
            return StagePlan.Foe(species: pick, level: foeLevel, hpScale: isBoss ? bossHP : 1)
        }
        return StagePlan(kind: .dungeon(kind, stage: stage), foes: foes, scenery: scenery(for: types))
    }
}

// MARK: Battle Tower

/// After the Champion: floor after floor of three fully evolved Pokémon, a level higher each
/// floor, until the party loses. The best floor is kept.
nonisolated enum BattleTower {
    static let foesPerFloor = 3
    static let stardustPerFloor = 20
    /// Every this many floors cleared pays an Ultra Ball.
    static let ultraBallEvery = 10

    static func level(floor: Int) -> Int { min(PokeMath.maxLevel, 50 + floor) }

    /// The same three for a floor all week, so a retry faces them again.
    static func plan(floor: Int, on date: Date, data: GameData, calendar: Calendar = .current) -> StagePlan {
        let week = calendar.component(.yearForWeekOfYear, from: date) * 100 + calendar.component(.weekOfYear, from: date)
        var rng = SeededRNG(seed: UInt64(week) &* 1_000_003 &+ UInt64(floor))
        let pool = data.dex.species.filter { !$0.isSpecial && data.dex.evolutions($0.id).isEmpty && $0.stats.total >= 400 }
        let level = level(floor: floor)
        let foes = (0..<foesPerFloor).map { _ in
            StagePlan.Foe(species: pool.isEmpty ? 143 : pool[Int(rng.next() % UInt64(pool.count))].id, level: level)
        }
        return StagePlan(kind: .tower(floor), foes: foes, scenery: .tower)
    }
}

/// A Battle Tower run: the floor being climbed, if any, and the best floor cleared.
nonisolated struct TowerState: Codable, Equatable, Sendable {
    var best = 0
    var floor: Int?
}

// MARK: Pokédex rewards

nonisolated enum DexRewards {
    /// Every this many species caught pays an Ultra Ball.
    static let every = 10

    static func earned(caught: Int) -> Int { caught / every }
    static func next(caught: Int) -> Int? { caught >= PokeDexStore.maxID ? nil : min(PokeDexStore.maxID, (caught / every + 1) * every) }
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

// MARK: Guidance

/// What it would take to beat a boss: everyone at `level` (evolving on the way) wins `chance`
/// of the time. `atCap` means even the level cap falls short of a good chance.
nonisolated struct LevelHint: Equatable, Sendable {
    let level: Int
    let chance: Double
    let atCap: Bool
}

/// How one Pokémon fares against a boss's team.
nonisolated enum Matchup: Equatable, Sendable {
    /// One of its moves hits the team hard.
    case strong
    /// The team's own types hit it hard.
    case weak
}

/// Where a species can be met, for Pokédex entries you don't have.
nonisolated enum Habitat: Equatable, Sendable {
    case gacha
    /// Chapters are 0-based.
    case legend(chapter: Int)
    case mythical
    case evolves(from: Int, level: Int?)
    case unknown
}

/// Hints for what to do next: the level a boss needs, the types that beat it, where to find a species.
nonisolated enum Guidance {
    /// A chance worth waiting for, and the forecast's "good" color.
    static let goodChance = 0.6

    /// The lowest level, up to the cap, at which the whole party would have a good chance, or
    /// the chance at the cap when none does. Nil when everyone is at the cap already.
    static func levelHint(party: [(species: PokeSpecies, level: Int)], plan: StagePlan, cap: Int, data: GameData) -> LevelHint? {
        guard let lowest = party.map(\.level).min(), lowest < cap else { return nil }
        var hint: LevelHint?
        for level in (lowest + 1)...cap {
            let members = party.map { member -> Combatant in
                let grown = max(member.level, level)
                return Combatant(species: evolved(member.species, at: grown, dex: data.dex), level: grown, moves: data.moves)
            }
            let chance = Forecast.winChance(party: members, plan: plan, data: data)
            hint = LevelHint(level: level, chance: chance, atCap: chance < goodChance)
            if chance >= goodChance { break }
        }
        return hint
    }

    /// The form a species reaches by this level, taking the first branch where there are several.
    static func evolved(_ species: PokeSpecies, at level: Int, dex: DexView) -> PokeSpecies {
        var current = species
        while let next = dex.evolutions(current.id).compactMap({ dex[$0] }).first(where: { ($0.evolveLevel ?? .max) <= level }) {
            current = next
        }
        return current
    }

    /// Strong when one of its moves hits most of the team hard, weak when the team's types hit it hard.
    static func matchup(moves: [PokeMove], types: [PokeType], against foes: [PokeSpecies]) -> Matchup? {
        guard !foes.isEmpty else { return nil }
        func share(_ hits: (PokeSpecies) -> Bool) -> Double { Double(foes.filter(hits).count) / Double(foes.count) }
        let attack = moves.filter { $0.id != PokeMove.struggle.id }
            .map { move in share { move.type.effectiveness(against: $0.types) >= 2 } }
            .max() ?? 0
        let threat = Set(foes.flatMap(\.types)).filter { $0.effectiveness(against: types) >= 2 }
            .map { type in share { $0.types.contains(type) } }
            .max() ?? 0
        if attack >= 0.5 { return .strong }
        if threat >= 0.5 { return .weak }
        return nil
    }

    /// Where each species turns up first: a legendary's branch, a chapter's stations, the gacha,
    /// or by evolving.
    static func habitats(data: GameData) -> [Int: Habitat] {
        var found: [Int: Habitat] = [:]
        for (index, chapter) in data.chapters.enumerated() {
            if let legend = chapter.legend { found[legend.species] = found[legend.species] ?? .legend(chapter: index) }
        }
        for entry in Gacha.pool(progress: JourneyProgress(), data: data) where found[entry.species] == nil {
            found[entry.species] = .gacha
        }
        if found[Kanto.mew] == nil { found[Kanto.mew] = .mythical }
        for species in data.dex.species where found[species.id] == nil {
            found[species.id] = species.evolvesFrom.map { .evolves(from: $0, level: species.evolveLevel) } ?? .unknown
        }
        return found
    }

    /// The next move that will make its moveset, and the level it comes at.
    static func nextMove(species: PokeSpecies, level: Int, moves: MoveDex) -> (level: Int, move: PokeMove)? {
        guard level < PokeMath.maxLevel else { return nil }
        let known = Set(moves.moveset(species: species.id, types: species.types, level: level).map(\.id))
        for next in (level + 1)...min(PokeMath.maxLevel, level + 40) {
            for move in moves.learned(species: species.id, at: next) where !known.contains(move.id) {
                if moves.moveset(species: species.id, types: species.types, level: next).contains(where: { $0.id == move.id }) {
                    return (next, move)
                }
            }
        }
        return nil
    }
}
