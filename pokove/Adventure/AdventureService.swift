import AppKit
import Observation

nonisolated struct OwnedPokemon: Codable, Identifiable, Equatable, Sendable {
    enum Origin: String, Codable, Sendable { case starter, wild, gacha, legend }

    let id: UUID
    var speciesID: Int
    var xp: Int
    /// Experience earned past the level cap, released when a badge raises it.
    var banked = 0
    let caughtAt: Date
    var origin: Origin
    var shiny = false

    var level: Int { PokeMath.level(forXP: xp) }
    /// Progress from this level to the next, 0–1.
    var levelProgress: Double {
        let level = level
        guard level < PokeMath.maxLevel else { return 1 }
        let floor = PokeMath.xp(forLevel: level), ceiling = PokeMath.xp(forLevel: level + 1)
        return Double(xp - floor) / Double(max(1, ceiling - floor))
    }
}

nonisolated extension OwnedPokemon {
    /// Tolerant, so Pokémon saved before shinies existed still read.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        speciesID = try container.decode(Int.self, forKey: .speciesID)
        xp = try container.decode(Int.self, forKey: .xp)
        banked = try container.decodeIfPresent(Int.self, forKey: .banked) ?? 0
        caughtAt = try container.decode(Date.self, forKey: .caughtAt)
        origin = try container.decode(Origin.self, forKey: .origin)
        shiny = try container.decodeIfPresent(Bool.self, forKey: .shiny) ?? false
    }
}

/// A Pokémon that turned up and joined, for banners.
nonisolated struct PokeEncounter: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let speciesID: Int
    let level: Int
    let caught: Bool
    /// First of its species in the dex.
    let isNew: Bool
    let isSpecial: Bool
    let date: Date
    var shiny = false
}

/// What happened since the adventure page was last looked at.
nonisolated struct AdventureRecap: Codable, Equatable, Sendable {
    struct Learned: Codable, Equatable, Sendable {
        let species: Int
        let move: Int
    }

    /// One Pokémon's levels over the recap.
    struct Growth: Codable, Equatable, Sendable {
        let member: UUID
        /// The species it is now, after any evolution.
        var species: Int
        let from: Int
        var to: Int
    }

    struct Evolution: Codable, Equatable, Sendable {
        let from: Int
        let to: Int
    }

    /// Where it happened; nil for recaps from before Johto, which were all in Kanto.
    var region: Region?
    /// When the first thing was recorded.
    var since: Date?
    /// When the page opened and the recap moved to the history.
    var until: Date?
    var clears = 0
    /// The first and furthest frontier stations cleared.
    var start: StationPoint?
    var reached: StationPoint?
    /// Station wins that didn't move the line (training and repeats), and where the last one was.
    var training = 0
    var stayed: StationPoint?
    var stardust = 0
    var ultraBalls = 0
    var growth: [Growth] = []
    /// Species that joined: discoveries and legendaries.
    var discovered: [Int] = []
    var evolutions: [Evolution] = []
    var learned: [Learned] = []
    var badges: [Int] = []
    /// Chapters (0-based) whose gym, or the League, opened as their line was cleared.
    var gymsOpened: [Int] = []
    /// Bosses that won, by trainer ID, and how many times.
    var losses: [String: Int] = [:]
    /// Dungeon stages cleared, and what they paid.
    var dungeonStages: [DungeonClear] = []
    /// Shinies met: newcomers, and ones you had that started to shine.
    var shinies: [Int] = []
    /// Pokédex milestones reached (10, 20, …), each worth an Ultra Ball.
    var dexMilestones: [Int] = []
    /// The highest Battle Tower floor cleared.
    var tower: Int?

    var isEmpty: Bool {
        clears == 0 && growth.isEmpty && discovered.isEmpty && evolutions.isEmpty && badges.isEmpty && gymsOpened.isEmpty && losses.isEmpty
            && dungeonStages.isEmpty && shinies.isEmpty && dexMilestones.isEmpty && tower == nil
    }

    /// Worth a line over the battle when the page opens; the rest waits in the history.
    var isNotable: Bool {
        !badges.isEmpty || !gymsOpened.isEmpty || !evolutions.isEmpty || !discovered.isEmpty || !losses.isEmpty || !dungeonStages.isEmpty
            || !shinies.isEmpty || !dexMilestones.isEmpty
    }

    /// A dungeon stage cleared while the page was closed.
    struct DungeonClear: Codable, Equatable, Sendable {
        let kind: DungeonKind
        let stage: Int
        var stardust = 0
        var xp = 0
        var ultraBall = false
    }

    init() {}

    private enum LegacyKeys: String, CodingKey { case coins, evolved }

    /// Tolerant, so a recap saved by an older version still reads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        region = try container.decodeIfPresent(Region.self, forKey: .region)
        since = try container.decodeIfPresent(Date.self, forKey: .since)
        until = try container.decodeIfPresent(Date.self, forKey: .until)
        clears = try container.decodeIfPresent(Int.self, forKey: .clears) ?? 0
        start = try container.decodeIfPresent(StationPoint.self, forKey: .start)
        reached = try container.decodeIfPresent(StationPoint.self, forKey: .reached)
        training = try container.decodeIfPresent(Int.self, forKey: .training) ?? 0
        stayed = try container.decodeIfPresent(StationPoint.self, forKey: .stayed)
        stardust = try container.decodeIfPresent(Int.self, forKey: .stardust) ?? legacy.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        ultraBalls = try container.decodeIfPresent(Int.self, forKey: .ultraBalls) ?? 0
        growth = try container.decodeIfPresent([Growth].self, forKey: .growth) ?? []
        discovered = try container.decodeIfPresent([Int].self, forKey: .discovered) ?? []
        // Older recaps kept only what each Pokémon evolved into.
        evolutions = try container.decodeIfPresent([Evolution].self, forKey: .evolutions)
            ?? (legacy.decodeIfPresent([Int].self, forKey: .evolved) ?? []).map { Evolution(from: $0, to: $0) }
        learned = try container.decodeIfPresent([Learned].self, forKey: .learned) ?? []
        badges = try container.decodeIfPresent([Int].self, forKey: .badges) ?? []
        gymsOpened = try container.decodeIfPresent([Int].self, forKey: .gymsOpened) ?? []
        losses = try container.decodeIfPresent([String: Int].self, forKey: .losses) ?? [:]
        dungeonStages = try container.decodeIfPresent([DungeonClear].self, forKey: .dungeonStages) ?? []
        shinies = try container.decodeIfPresent([Int].self, forKey: .shinies) ?? []
        dexMilestones = try container.decodeIfPresent([Int].self, forKey: .dexMilestones) ?? []
        tower = try container.decodeIfPresent(Int.self, forKey: .tower)
    }
}

/// One region's journey: its box and party, what it has earned, and how far it has come. The
/// region being played lives in `AdventureService`'s own properties; the other waits here.
nonisolated struct RegionState: Codable, Equatable, Sendable {
    var starter: Int?
    /// Empty once the boxes are merged: the one box is kept with the region being played.
    var owned: [OwnedPokemon] = []
    var partyIDs: [UUID] = []
    var stardust = 0
    var ultraBalls = 0
    var progress = JourneyProgress()
    var offer: [GachaCard]?
    var clears = 0
    var wipes = 0
    var pulls = 0
    var tower = TowerState()
    var dungeons = DungeonState(day: DailyDungeon.day(of: Date()))
}

/// A station left behind for the next one, or a terminus cleared, and the stardust it paid.
nonisolated struct Arrival: Equatable, Sendable {
    let cleared: StationPoint
    let terminus: Bool
    let stardust: Int
}

/// A finished challenge, for the battle scene's win or loss card.
nonisolated struct ChallengeResult: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case boss(Trainer)
        case legend(species: Int)
        case dungeon(DungeonKind, stage: Int)
        /// The floor a Battle Tower run ended on.
        case tower(Int)
    }

    let kind: Kind
    let cleared: Bool
    /// The tower's best floor, after a run.
    var best: Int?
    var badge: Int?
    /// The level cap before and after a badge raised it.
    var cap: ClosedRange<Int>?
    var stardust = 0
    /// Experience for each of the party, from the experience dungeon.
    var xp = 0
    var ultraBall = false
    /// The forecast for the next try, after a loss.
    var chance: Double?
}

/// The adventure: a party of up to three rides a line of stations while a coding agent works,
/// battling wild Pokémon in a 1:1 relay. Gym leaders, the League, legendaries and the daily dungeons
/// are challenges the user starts, which then play out on their own. Pokémon join through discoveries and the
/// gacha; badges raise the level cap.
@Observable
final class AdventureService {
    /// The region being played. Everything below that isn't shared belongs to it.
    private(set) var region: Region = .kanto
    /// The regions not being played, as they were left.
    private var away: [Region: RegionState] = [:]
    /// After Johto's Champion, both regions share one box.
    private(set) var boxMerged = false
    private(set) var owned: [OwnedPokemon] = []
    private(set) var partyIDs: [UUID] = []
    private(set) var seen: Set<Int> = []
    private(set) var caught: Set<Int> = []
    private(set) var stardust = 0
    /// Won in the stardust dungeon, the tower and the Pokédex: each opens a gacha round of rare balls.
    private(set) var ultraBalls = 0
    private(set) var progress = JourneyProgress()
    private(set) var starter: Int?
    private(set) var battle: BattleState?
    /// What the current battle is for.
    private(set) var target: BattleTarget?
    /// The latest battle event, for the scene; `eventSerial` bumps on every one.
    private(set) var lastEvent: BattleEvent?
    private(set) var eventSerial = 0
    /// Experience from the last knockout at a station, for the scene; `xpSerial` bumps on every one.
    private(set) var lastXP = 0
    private(set) var xpSerial = 0
    /// The last challenge's outcome, for the scene's result card; `resultSerial` bumps on every one.
    private(set) var lastResult: ChallengeResult?
    private(set) var resultSerial = 0
    /// The last new station reached and what it paid, for the scene; `arrivalSerial` bumps on every one.
    private(set) var lastArrival: Arrival?
    private(set) var arrivalSerial = 0
    /// While someone watches, battles wait here for a challenge's intro or result card to play.
    private var holdUntil: Date?
    /// Three balls waiting for the user to pick one.
    private(set) var offer: [GachaCard]?
    /// What has happened since the page was last open; it moves to `history` when the page opens.
    private(set) var recap = AdventureRecap()
    /// Earlier recaps, newest first, from today and yesterday.
    private(set) var history: [AdventureRecap] = []
    /// A recap landed in the history since it was last opened.
    private(set) var historyUnread = false
    private(set) var clears = 0
    private(set) var wipes = 0
    private(set) var pulls = 0
    /// The Battle Tower: the floor being climbed and the best one.
    private(set) var tower = TowerState()
    /// Pokédex milestones already paid out.
    private(set) var dexRewards = 0
    /// The two dungeons' stages and today's tries.
    private(set) var dungeons = DungeonState(day: DailyDungeon.day(of: Date()))
    /// True while a battle is playing: at a station while an agent works, or any challenge.
    private(set) var isBattling = false
    /// Forecast chance of beating the next boss with the current party.
    private(set) var readiness: Double?
    /// The level the party needs for the next boss, while its chance is poor.
    private(set) var levelHint: LevelHint?

    let dex: PokeDexStore
    /// Set by the app: whether any coding agent is mid-turn right now.
    @ObservationIgnored var isAgentWorking: () -> Bool = { false }

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private let legacyURL: URL?
    @ObservationIgnored private var turns: [String: Date] = [:]
    /// New species found mid-turn, shown with the next "finished" banner.
    @ObservationIgnored private var pendingDiscoveries: [PokeEncounter] = []
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SeededRNG(seed: UInt64.random(in: 0...UInt64.max))
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Set by the adventure page while it's on screen: what happens then isn't news later.
    @ObservationIgnored var isWatching = false
    @ObservationIgnored private var cachedData: GameData?
    @ObservationIgnored private var cachedKey: String?
    @ObservationIgnored private var forecastKey: String?
    @ObservationIgnored private var hintTask: Task<Void, Never>?
    @ObservationIgnored private var habitatCache: [Int: Habitat]?
    @ObservationIgnored private var forecasts: [String: Double] = [:]
    /// Experience earned in a challenge, granted only if it's won.
    @ObservationIgnored private var challengeXP = 0
    @ObservationIgnored private var clock: Double = 0

    static let tickInterval: Double = 0.5
    /// Seconds per action at a station, while an agent works.
    static let stationInterval: Double = 1.5
    /// Seconds per action in a challenge.
    static let challengeInterval: Double = 1.0
    /// How long the scene's VS intro and result cards hold the battle, while someone watches.
    static let introHold: Double = 2.4
    static let resultHold: Double = 3.2
    static let maxParty = 3
    static let historyLimit = 40

    init(preferences: Preferences, activity: ActivityCenter, dex: PokeDexStore = PokeDexStore(),
         storeURL: URL = AdventureService.defaultStoreURL, legacyURL: URL? = AdventureService.legacyStoreURL) {
        self.preferences = preferences
        self.activity = activity
        self.dex = dex
        self.storeURL = storeURL
        self.legacyURL = legacyURL
        load()
    }

    private static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("pokove", isDirectory: true)
    }

    static var defaultStoreURL: URL {
        #if DEBUG
        folder.appendingPathComponent("adventure-v3-debug.json")
        #else
        folder.appendingPathComponent("adventure-v3.json")
        #endif
    }

    /// v2's save, migrated on first launch and then left alone.
    static var legacyStoreURL: URL {
        #if DEBUG
        folder.appendingPathComponent("adventure-v2-debug.json")
        #else
        folder.appendingPathComponent("adventure-v2.json")
        #endif
    }

    // MARK: Derived

    var isEnabled: Bool { preferences.adventureEnabled }
    var hasStarted: Bool { !owned.isEmpty }
    var party: [OwnedPokemon] { partyIDs.compactMap { id in owned.first { $0.id == id } } }
    var partyLevel: Int { party.isEmpty ? 5 : party.map(\.level).reduce(0, +) / party.count }
    var leader: OwnedPokemon? { party.first }
    var levelCap: Int { region.levelCap(badges: progress.badges, champion: progress.isChampion) }
    var canPull: Bool { hasStarted && offer == nil && stardust >= Gacha.price }
    var canOpenUltraBall: Bool { hasStarted && offer == nil && ultraBalls > 0 }
    /// Balls to pick from, or enough to get some: the gacha's dot.
    var hasGachaWaiting: Bool { canPull || canOpenUltraBall || offer != nil }

    /// Species, moves and encounters together, once everything is downloaded (for Johto, the full dex).
    var data: GameData? {
        guard dex.isReady, let moves = dex.moves, let encounters = dex.encounters, region == .kanto || dex.hasJohto else { return nil }
        let key = "\(region.rawValue)-\(starter ?? 0)-\(dex.revision)"
        if let cachedData, cachedKey == key { return cachedData }
        let built = GameData(species: dex.species, moves: moves, encounters: encounters, region: region, starter: starter ?? 4)
        cachedData = built
        cachedKey = key
        habitatCache = nil
        return built
    }

    var chapters: [Chapter] { data?.chapters ?? region.chapters(starter: starter ?? 4) }

    // MARK: Regions

    /// A region's journey, whether it's being played or waiting.
    func journey(in other: Region) -> JourneyProgress? {
        other == region ? progress : away[other]?.progress
    }

    /// Johto opens with Kanto's Champion.
    func isOpen(_ other: Region) -> Bool {
        switch other {
        case .kanto: true
        case .johto: journey(in: .kanto)?.isChampion == true
        }
    }

    /// Some region besides Kanto is open, so there's a choice to show.
    var hasRegionChoice: Bool { isOpen(.johto) }

    /// An open region whose journey hasn't started: the region menu's dot.
    var hasUnvisitedRegion: Bool {
        Region.allCases.contains { other in other != region && isOpen(other) && away[other]?.starter == nil }
    }

    /// Leaves this region as it is and picks up the other where it was left. A new region starts
    /// with its starter to pick. Not while a challenge plays out.
    func travel(to next: Region) {
        guard next != region, isOpen(next), !isChallenging else { return }
        closeRecap()
        away[region] = currentState()
        let arriving = away.removeValue(forKey: next) ?? RegionState()
        let box = owned
        region = next
        restore(arriving)
        if boxMerged { owned = box }
        battle = nil
        target = nil
        lastEvent = nil
        holdUntil = nil
        cachedData = nil
        habitatCache = nil
        forecasts = [:]
        forecastKey = nil
        readiness = nil
        levelHint = nil
        // A hint still being worked out is for the region left behind.
        hintTask?.cancel()
        hintTask = nil
        dungeons.refill(for: DailyDungeon.day(of: Date()))
        refreshReadiness()
        saveNow()
    }

    /// The region being played, as a state to set aside or save.
    private func currentState() -> RegionState {
        RegionState(starter: starter, owned: boxMerged ? [] : owned, partyIDs: partyIDs, stardust: stardust, ultraBalls: ultraBalls,
                    progress: progress, offer: offer, clears: clears, wipes: wipes, pulls: pulls, tower: tower, dungeons: dungeons)
    }

    private func restore(_ state: RegionState) {
        starter = state.starter
        owned = state.owned
        partyIDs = state.partyIDs.filter { id in state.owned.contains { $0.id == id } || boxMerged }
        stardust = state.stardust
        ultraBalls = state.ultraBalls
        progress = state.progress
        offer = state.offer
        clears = state.clears
        wipes = state.wipes
        pulls = state.pulls
        tower = state.tower
        tower.floor = nil
        dungeons = state.dungeons
    }

    /// A region's state for the save: the one being played from its properties.
    private func state(of other: Region) -> RegionState? {
        other == region ? currentState() : away[other]
    }

    /// Johto's Champion: Kanto's box joins Johto's, and either region can field anyone.
    private func mergeBoxes() {
        guard !boxMerged else { return }
        for other in Region.allCases where other != region {
            owned += away[other]?.owned ?? []
            away[other]?.owned = []
        }
        boxMerged = true
    }

    /// Switching regions ends the recap, so each one is about one region.
    private func closeRecap() {
        guard !recap.isEmpty else { recap = AdventureRecap(); return }
        var finished = recap
        finished.until = Date()
        recap = AdventureRecap()
        history.insert(finished, at: 0)
        trimHistory()
        historyUnread = true
    }

    func pokemon(_ id: UUID) -> OwnedPokemon? { owned.first { $0.id == id } }

    /// The best-raised Pokémon of a species, if one is owned.
    func owned(species id: Int) -> OwnedPokemon? {
        owned.filter { $0.speciesID == id }.max { $0.xp < $1.xp }
    }

    /// The owned Pokémon of the same evolution line, which a duplicate would strengthen.
    func owned(family id: Int) -> OwnedPokemon? {
        guard let data else { return owned(species: id) }
        let base = data.dex.base(of: id)
        return owned.filter { data.dex.base(of: $0.speciesID) == base }.max { $0.xp < $1.xp }
    }

    func isInParty(_ id: UUID) -> Bool { partyIDs.contains(id) }

    /// Shinies in the box.
    var shinyCount: Int { owned.filter(\.shiny).count }

    /// Whether the party member behind a combatant shines.
    func isShiny(_ combatant: Combatant) -> Bool { combatant.ownedID.flatMap(pokemon)?.shiny == true }

    func moves(of member: OwnedPokemon) -> [PokeMove] {
        guard let data, let species = data.dex[member.speciesID] else { return [] }
        return data.moves.moveset(species: species.id, types: species.types, level: member.level)
    }

    /// A challenge is playing out (or about to): the stage line waits.
    var isChallenging: Bool { target?.isChallenge == true && battle.map { !$0.isOver } == true }

    /// The station the stage line is on, whether or not it's being fought right now.
    var stationPoint: StationPoint { progress.stationTarget(chapters) }

    /// Repeating a cleared station, or training after a loss: the next one waits.
    var isBehindFrontier: Bool { !progress.isLooping && stationPoint != progress.frontier }

    /// The next boss and its trainer, once or before the line is cleared.
    var nextBoss: (chapter: Int, index: Int, trainer: Trainer)? {
        guard let next = progress.nextBoss(chapters) else { return nil }
        return (next.chapter, next.index, chapters[next.chapter].bosses[next.index])
    }

    /// The level a station's wild Pokémon are met at: its own, but never above the party. On a
    /// terminus, its boss's, which doesn't follow the party.
    func foeLevel(_ station: Station, isTerminus: Bool = false) -> Int {
        isTerminus ? max(2, station.level + StagePlan.lastStationBoost) : max(2, min(station.level, partyLevel - 1))
    }

    /// Wild Pokémon beaten at the next station, and how many open the one after.
    var stationWins: (wins: Int, needed: Int)? {
        guard !progress.isLooping, let station = chapters[safeChapter: progress.chapter]?.stations[safe: progress.station] else { return nil }
        return (progress.wins, Chapter.winsNeeded(station, isTerminus: progress.station == Chapter.stationCount - 1))
    }

    /// Stations still to clear on the current line.
    var stationsLeft: Int { max(0, Chapter.stationCount - progress.station) }

    /// Stations still to clear before the next boss's gym opens, across chapters.
    var stationsToNextBoss: Int? {
        guard let next = nextBoss, next.chapter >= progress.chapter else { return nil }
        return (next.chapter - progress.chapter) * Chapter.stationCount + stationsLeft
    }

    /// Legendaries whose branch the party has reached and hasn't beaten.
    func isLegendOpen(_ spot: LegendSpot) -> Bool {
        guard let index = chapters.firstIndex(where: { $0.legend?.id == spot.id }) else { return false }
        return progress.hasReached(chapter: index) && !progress.beatenLegends.contains(spot.id)
    }

    func dungeonTypes(_ kind: DungeonKind) -> [PokeType] { DailyDungeon.types(kind, on: Date()) }

    /// A dungeon's climb, with today's tries even before the first tick of the day.
    func climb(_ kind: DungeonKind) -> DungeonClimb {
        var state = dungeons
        state.refill(for: DailyDungeon.day(of: Date()))
        return state[kind]
    }

    /// A dungeon's three for a stage today.
    func dungeonFoes(_ kind: DungeonKind, stage: Int) -> [StagePlan.Foe] {
        data.map { DailyDungeon.plan(kind, stage: stage, on: Date(), data: $0).foes } ?? []
    }

    /// Forecast chance of winning a challenge with the current party (or another), cached per party.
    func winChance(_ target: BattleTarget, party ids: [UUID]? = nil) -> Double? {
        guard let data, let plan = plan(for: target, data: data, forecast: true) else { return nil }
        let team = ids.map { $0.compactMap(pokemon) } ?? party
        let members = combatants(team, data)
        guard !members.isEmpty else { return nil }
        let key = team.map { "\($0.speciesID):\($0.level)" }.joined(separator: ",") + "@" + plan.foes.map { "\($0.species):\($0.level)" }.joined(separator: ",")
        if let known = forecasts[key] { return known }
        let chance = Forecast.winChance(party: members, plan: plan, data: data)
        if forecasts.count > 64 { forecasts.removeAll() }
        forecasts[key] = chance
        return chance
    }

    /// The next boss's team, for matchups.
    var nextBossTeam: [PokeSpecies] {
        nextBoss.map { $0.trainer.battleTeam.compactMap { dex.species($0.species) } } ?? []
    }

    /// How a Pokémon you have would fare against the next boss.
    func matchup(of member: OwnedPokemon) -> Matchup? {
        guard let species = dex.species(member.speciesID) else { return nil }
        return Guidance.matchup(moves: moves(of: member), types: species.types, against: nextBossTeam)
    }

    /// Where a species turns up first.
    func habitat(of species: Int) -> Habitat {
        guard let data else { return .unknown }
        if habitatCache == nil { habitatCache = Guidance.habitats(data: data) }
        return habitatCache?[species] ?? .unknown
    }

    /// A dungeon with tries left today, stardust first.
    var openDungeon: DungeonKind? { DungeonKind.allCases.first { climb($0).tries > 0 } }

    /// The backdrop behind the scene.
    var scenery: Scenery {
        if let battle { return battle.plan.scenery }
        let point = stationPoint
        return chapters[safeChapter: point.chapter]?.stations[point.station].stretch.scenery ?? .meadow
    }

    // MARK: Lifecycle

    func start() {
        dex.load()
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.tickInterval))
                self?.tick()
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        saveNow()
    }

    // MARK: Party

    func chooseStarter(_ speciesID: Int) {
        guard starter == nil, boxMerged || owned.isEmpty, dex.species(speciesID) != nil else { return }
        let first = OwnedPokemon(id: UUID(), speciesID: speciesID, xp: PokeMath.xp(forLevel: 5), caughtAt: Date(), origin: .starter)
        owned.append(first)
        partyIDs = [first.id]
        // The Pokédex carries over from the other region.
        seen.insert(speciesID)
        caught.insert(speciesID)
        starter = speciesID
        stardust = Gacha.startingStardust
        progress = JourneyProgress()
        battle = nil
        target = nil
        cachedData = nil
        habitatCache = nil
        claimDexRewards()
        saveNow()
    }

    /// Adds to or removes from the party. Returns false when the party is full.
    @discardableResult
    func toggleParty(_ id: UUID) -> Bool {
        if let index = partyIDs.firstIndex(of: id) {
            guard partyIDs.count > 1 else { return false }
            partyIDs.remove(at: index)
        } else {
            guard partyIDs.count < Self.maxParty, pokemon(id) != nil else { return false }
            partyIDs.append(id)
        }
        partyChanged()
        return true
    }

    /// Puts a Pokémon in a party slot, from a drag: a party member swaps places with whoever is
    /// there; one from the box takes the slot, or joins at the end when the slot is empty.
    func place(_ id: UUID, at slot: Int) {
        guard pokemon(id) != nil, (0..<Self.maxParty).contains(slot) else { return }
        if let from = partyIDs.firstIndex(of: id) {
            guard from != slot else { return }
            if slot < partyIDs.count { partyIDs.swapAt(from, slot) } else { partyIDs.append(partyIDs.remove(at: from)) }
        } else if slot < partyIDs.count {
            partyIDs[slot] = id
        } else {
            partyIDs.append(id)
        }
        partyChanged()
    }

    /// Moves a party member to the front, where it battles first.
    func makeLeader(_ id: UUID) {
        guard let index = partyIDs.firstIndex(of: id), index > 0 else { return }
        partyIDs.remove(at: index)
        partyIDs.insert(id, at: 0)
        partyChanged()
    }

    /// Sets up the best three for what's next: the challenge underway, else the next boss, else
    /// simply the strongest.
    func autoParty() {
        guard let data else { return }
        let candidates = owned.compactMap { member in
            data.dex[member.speciesID].map { Recommend.Candidate(id: member.id, species: $0, level: member.level) }
        }
        let foes: [StagePlan.Foe]
        if let battle, target?.isChallenge == true {
            foes = battle.plan.foes
        } else if let next = nextBoss {
            foes = StagePlan.boss(next.trainer, scenery: .gym).foes
        } else {
            foes = []
        }
        let picks = Recommend.party(from: candidates, against: foes, data: data, size: Self.maxParty)
        guard !picks.isEmpty, picks != partyIDs else { return }
        partyIDs = picks
        partyChanged()
    }

    private func partyChanged() {
        // A station lines up the new party at once; a challenge underway keeps its team.
        if !isChallenging { battle = nil }
        refreshReadiness()
        scheduleSave()
    }

    // MARK: Journey controls

    /// Takes on the next gym leader, or the next of the League's five, once its chapter is cleared.
    func challengeBoss() {
        guard !isChallenging, progress.isBossOpen(chapters), let next = progress.nextBoss(chapters), let data else { return }
        start(.boss(chapter: next.chapter, index: next.index), data: data)
    }

    func challengeLegend(_ id: String) {
        guard !isChallenging, let data, let spot = data.legend(id), isLegendOpen(spot) else { return }
        start(.legend(id), data: data)
    }

    /// Starts a Battle Tower run from the first floor.
    func enterTower() {
        guard progress.isChampion, !isChallenging, let data else { return }
        tower.floor = 1
        start(.tower(1), data: data)
    }

    /// A try at a dungeon's next stage.
    func enterDungeon(_ kind: DungeonKind) {
        let climb = climb(kind)
        guard !isChallenging, climb.tries > 0, let stage = climb.next, let data else { return }
        dungeons.refill(for: DailyDungeon.day(of: Date()))
        start(.dungeon(kind, stage: stage), data: data)
    }

    /// Sweeps a dungeon's best stage for one try: what beating it would pay, at once, with the same
    /// card over the scene.
    func sweepDungeon(_ kind: DungeonKind) {
        guard !isChallenging, let data else { return }
        dungeons.refill(for: DailyDungeon.day(of: Date()))
        guard let stage = dungeons.sweep(kind) else { return }
        let plan = DailyDungeon.plan(kind, stage: stage, on: Date(), data: data)
        let level = partyLevel
        award(plan.foes.reduce(0) { xp, foe in
            xp + (dex.species(foe.species).map {
                PokeMath.defeatXP(baseExperience: $0.baseExperience, level: foe.level, partyLevel: level, kind: plan.kind)
            } ?? 0)
        })
        var result = ChallengeResult(kind: .dungeon(kind, stage: stage), cleared: true)
        payDungeon(kind, stage: stage, isNew: false, into: &result)
        refreshReadiness()
        lastResult = result
        resultSerial &+= 1
        if isWatching { hold(Self.resultHold) }
        saveNow()
    }

    /// Repeats a cleared station, to meet its Pokémon.
    func repeatStation(_ point: StationPoint) {
        guard progress.isCleared(point), point != progress.frontier else { return }
        progress.repeating = point
        if !isChallenging { battle = nil }
        scheduleSave()
    }

    /// Back to the next station: stops repeating one, or training after a loss.
    func resumeJourney() {
        guard progress.repeating != nil || progress.isTraining else { return }
        progress.pushOn()
        if !isChallenging { battle = nil }
        scheduleSave()
    }

    // MARK: Gacha

    func pull() {
        guard canPull else { return }
        stardust -= Gacha.price
        deal(floor: .common)
    }

    /// A dungeon prize: three balls, all rare or better.
    func openUltraBall() {
        guard canOpenUltraBall else { return }
        ultraBalls -= 1
        deal(floor: .rare)
    }

    private func deal(floor: GachaCard.Rarity) {
        guard let data else { return }
        pulls += 1
        let pool = Gacha.pool(progress: progress, data: data)
        var levels = SeededRNG(seed: rng.next())
        let partyLevel = partyLevel, cap = levelCap
        // The first pull always brings someone new.
        var cards = Gacha.draw(pool: pool, level: { _ in
            Gacha.level(partyLevel: partyLevel, cap: cap, rng: &levels)
        }, isOwned: { self.owned(family: $0) != nil }, duplicateWeight: pulls == 1 ? 0 : 0.3, floor: floor, rng: &rng)
        for index in cards.indices { cards[index].shiny = Shiny.roll(&rng) }
        offer = cards
        saveNow()
    }

    /// Keeps one ball: a new Pokémon joins, or the one you have of its line grows.
    func pick(_ cardID: UUID) {
        guard let card = offer?.first(where: { $0.id == cardID }), let species = dex.species(card.species) else { return }
        offer = nil
        if let existing = owned(family: card.species), let index = owned.firstIndex(where: { $0.id == existing.id }) {
            grant(Gacha.duplicateXP(level: existing.level), to: index)
            if card.shiny { makeShiny(at: index, announce: false) }
        } else {
            receive(species, level: card.level, origin: .gacha, shiny: card.shiny)
        }
        saveNow()
    }

    // MARK: Agent turns

    func turnStarted(sessionID: String, at date: Date = Date()) {
        guard isEnabled else { return }
        turns[sessionID] = date
    }

    func hasTurn(for sessionID: String) -> Bool { turns[sessionID] != nil }
    var turnIDs: [String] { Array(turns.keys) }

    /// A finished turn carries the best new Pokémon found while it ran, for its banner.
    @discardableResult
    func turnFinished(sessionID: String, at date: Date = Date()) -> PokeEncounter? {
        turns.removeValue(forKey: sessionID)
        defer { pendingDiscoveries = [] }
        return pendingDiscoveries.max { ($0.isSpecial ? 1 : 0, $0.date) < ($1.isSpecial ? 1 : 0, $1.date) }
    }

    /// Interrupted or failed: nothing to show with it, so a find gets its own banner.
    func turnAborted(sessionID: String) {
        turns[sessionID] = nil
        if turns.isEmpty { flushDiscoveries() }
    }

    func endAllTurns() {
        turns.removeAll()
        flushDiscoveries()
    }

    private func flushDiscoveries() {
        guard let best = pendingDiscoveries.last else { return }
        pendingDiscoveries = []
        announceDiscovery(best)
    }

    // MARK: Battle

    private func tick() {
        guard isEnabled, hasStarted, let data else { return }
        dungeons.refill(for: DailyDungeon.day(of: Date()))
        // Something is always lined up, so the scene shows who's next even while agents rest.
        if battle == nil || battle?.isOver == true { lineUp(data) }
        guard let target else { return }
        if let holdUntil, Date() < holdUntil { return }
        let working = target.isChallenge || isAgentWorking()
        if isBattling != working { isBattling = working }
        guard working else { clock = 0; return }
        clock += Self.tickInterval
        let interval = target.isChallenge ? Self.challengeInterval : Self.stationInterval
        guard clock + 0.001 >= interval else { return }
        clock = 0
        if !target.isChallenge { discover(data) }
        step(data)
    }

    private func step(_ data: GameData) {
        guard var state = battle, let target else { return }
        let event = state.step()
        battle = state
        guard let event else { return }
        lastEvent = event
        eventSerial &+= 1

        switch event {
        case .sentOut(let side, let id):
            if side == .foe, let foe = battle?.combatant(id) { seen.insert(foe.speciesID) }
        case .action(let action):
            // A foe goes down to a hit, or to its own recoil.
            let foeID = action.byParty ? (action.targetFainted ? action.targetID : nil) : (action.attackerFainted ? action.attackerID : nil)
            if let foeID { defeated(foeID, in: target) }
        case .status(let status):
            // Or to poison or a burn.
            if status.fainted, !status.onParty { defeated(status.targetID, in: target) }
        case .cleared:
            finish(cleared: true, data: data)
        case .wiped:
            finish(cleared: false, data: data)
        }
    }

    private func defeated(_ foeID: UUID, in target: BattleTarget) {
        guard let foe = battle?.combatant(foeID), let species = dex.species(foe.speciesID), let plan = battle?.plan else { return }
        let xp = PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: partyLevel, kind: plan.kind)
        if target.isChallenge {
            challengeXP += xp
        } else {
            award(xp)
            lastXP = xp
            xpSerial &+= 1
        }
    }

    /// The next battle: the station, unless a tower run or the League is underway.
    private func lineUp(_ data: GameData, goOn: BattleTarget? = nil) {
        // A tower run climbs on by itself until it ends.
        if let floor = tower.floor {
            start(.tower(floor), data: data)
        } else if let goOn {
            start(goOn, data: data)
        } else {
            start(.station(progress.stationTarget(data.chapters)), data: data)
        }
    }

    private func plan(for target: BattleTarget, data: GameData, forecast: Bool = false) -> StagePlan? {
        switch target {
        case .station(let point):
            guard let chapter = data.chapters[safeChapter: point.chapter], chapter.stations.indices.contains(point.station) else { return nil }
            return StagePlan.station(chapter.stations[point.station], isLast: point.station == Chapter.stationCount - 1, data: data,
                                     partyLevel: forecast ? 100 : partyLevel, rng: &rng)
        case .boss(let chapter, let index):
            guard let chapter = data.chapters[safeChapter: chapter], chapter.bosses.indices.contains(index) else { return nil }
            return StagePlan.boss(chapter.bosses[index], scenery: chapter.bossScenery)
        case .legend(let id):
            return data.legend(id).map(StagePlan.legend)
        case .dungeon(let kind, let stage):
            return DailyDungeon.plan(kind, stage: stage, on: Date(), data: data)
        case .tower(let floor):
            return BattleTower.plan(floor: floor, on: Date(), data: data)
        }
    }

    private func combatants(_ data: GameData) -> [Combatant] { combatants(party, data) }

    private func combatants(_ team: [OwnedPokemon], _ data: GameData) -> [Combatant] {
        team.compactMap { member in
            data.dex[member.speciesID].map { Combatant(species: $0, level: member.level, moves: data.moves, ownedID: member.id) }
        }
    }

    private func start(_ next: BattleTarget, data: GameData) {
        refreshReadiness()
        guard let plan = plan(for: next, data: data) else { battle = nil; target = nil; return }
        let members = combatants(data)
        guard !members.isEmpty else { battle = nil; return }
        target = next
        challengeXP = 0
        clock = 0
        let state = BattleState(plan: plan, party: members, data: data, seed: rng.next())
        if let foe = state.foeActive { seen.insert(foe.speciesID) }
        battle = state
        if next.isChallenge, !isBattling { isBattling = true }
        if next.showsIntro, isWatching { hold(Self.introHold) }
    }

    /// Holds the battle for a card, after any hold already running.
    private func hold(_ seconds: Double) {
        let now = Date()
        holdUntil = max(holdUntil ?? now, now).addingTimeInterval(seconds)
    }

    private func finish(cleared: Bool, data: GameData) {
        guard let target, let plan = battle?.plan else { return }
        var goOn: BattleTarget?
        let capBefore = levelCap
        var result: ChallengeResult?
        var reward = 0
        if cleared {
            clears += 1
            if target.isChallenge { award(challengeXP) }
            reward = Rewards.stardust(for: plan.kind)
            stardust += reward
            note { $0.clears += 1; $0.stardust += reward }
        } else {
            wipes += 1
        }
        challengeXP = 0

        switch target {
        case .station(let point):
            // Only the frontier counts as progress; repeats and training don't move the line.
            let wasOpen = progress.isBossOpen(data.chapters)
            let outcome = progress.recordStation(point, cleared: cleared, defeated: plan.foes.count, chapters: data.chapters)
            let frontier = outcome == .advanced || outcome == .chapter
            if frontier {
                let terminus = point.station == Chapter.stationCount - 1
                let prize = Rewards.arrival(terminus: terminus)
                stardust += prize
                note { $0.stardust += prize }
                lastArrival = Arrival(cleared: point, terminus: terminus, stardust: prize)
                arrivalSerial &+= 1
            }
            if !wasOpen, progress.isBossOpen(data.chapters), let next = progress.nextBoss(data.chapters) {
                note { $0.gymsOpened.append(next.chapter) }
            }
            if cleared {
                note { recap in
                    if frontier {
                        if recap.start == nil { recap.start = point }
                        if let reached = recap.reached, (reached.chapter, reached.station) >= (point.chapter, point.station) { return }
                        recap.reached = point
                    } else {
                        recap.training += 1
                        recap.stayed = point
                    }
                }
            }
        case .boss:
            let outcome = progress.recordBoss(cleared: cleared, chapters: data.chapters)
            if let trainer = plan.trainer {
                if cleared {
                    note { $0.losses[trainer.id] = nil }
                } else {
                    note { $0.losses[trainer.id, default: 0] += 1 }
                }
            }
            if let trainer = plan.trainer { result = ChallengeResult(kind: .boss(trainer), cleared: cleared, stardust: reward) }
            switch outcome {
            case .advanced:
                // The League's five come one after another.
                if let next = progress.nextBoss(data.chapters) { goOn = .boss(chapter: next.chapter, index: next.index) }
            case .badge(let badge):
                releaseBank()
                note { $0.badges.append(badge) }
                // The badge can open the next gym, or the League, on a line already cleared.
                if progress.isBossOpen(data.chapters), let next = progress.nextBoss(data.chapters) {
                    note { $0.gymsOpened.append(next.chapter) }
                }
                announceBadge(badge)
                result?.badge = badge
                if levelCap > capBefore { result?.cap = capBefore...levelCap }
            case .champion:
                releaseBank()
                switch region {
                case .kanto:
                    announce(title: String(localized: "You're the Champion!"),
                             detail: RegionText.johtoOpened, pokemonID: plan.foes.last?.species)
                case .johto:
                    mergeBoxes()
                    announce(title: String(localized: "You're the Champion!"),
                             detail: RegionText.boxesMerged, pokemonID: plan.foes.last?.species)
                }
            default:
                break
            }
        case .legend(let id):
            progress.recordLegend(id, cleared: cleared)
            if let spot = data.legend(id) { result = ChallengeResult(kind: .legend(species: spot.species), cleared: cleared, stardust: reward) }
            if cleared, let spot = data.legend(id), let species = dex.species(spot.species) {
                let isNew = !caught.contains(spot.species)
                receive(species, level: min(spot.level, levelCap), origin: .legend, shiny: spot.shiny)
                note { $0.discovered.append(spot.species) }
                let encounter = PokeEncounter(id: UUID(), speciesID: spot.species, level: spot.level, caught: true, isNew: isNew,
                                              isSpecial: true, date: Date(), shiny: spot.shiny)
                announceDiscovery(encounter, title: String(localized: "\(species.name) joined your team!"))
            }
        case .dungeon(let kind, let stage):
            var card = ChallengeResult(kind: .dungeon(kind, stage: stage), cleared: cleared)
            let isNew = dungeons.record(kind, stage: stage, cleared: cleared)
            if cleared { payDungeon(kind, stage: stage, isNew: isNew, into: &card) }
            result = card
        case .tower(let floor):
            if cleared {
                tower.best = max(tower.best, floor)
                tower.floor = floor + 1
                note { $0.tower = max($0.tower ?? 0, floor) }
                if floor % BattleTower.ultraBallEvery == 0 {
                    ultraBalls += 1
                    note { $0.ultraBalls += 1 }
                }
            } else {
                // The run ends; only its end gets a card.
                tower.floor = nil
                result = ChallengeResult(kind: .tower(floor), cleared: false, best: tower.best)
            }
        }
        battle = nil
        refreshReadiness()
        if var result {
            if !cleared, case .boss = result.kind { result.chance = readiness }
            lastResult = result
            resultSerial &+= 1
            if isWatching { hold(Self.resultHold) }
        }
        // The next battle lines up at once, so the scene never sits empty.
        lineUp(data, goOn: goOn)
        saveNow()
    }

    /// A dungeon stage's prize, cleared or swept, onto its card and into the recap.
    private func payDungeon(_ kind: DungeonKind, stage: Int, isNew: Bool, into result: inout ChallengeResult) {
        var clear = AdventureRecap.DungeonClear(kind: kind, stage: stage)
        switch kind {
        case .stardust:
            let prize = DailyDungeon.stardust(stage: stage)
            stardust += prize
            clear.stardust = prize
            result.stardust = prize
            if isNew, DailyDungeon.paysUltraBall(stage: stage) {
                ultraBalls += 1
                clear.ultraBall = true
                result.ultraBall = true
            }
        case .experience:
            let xp = DailyDungeon.experience(stage: stage)
            award(xp)
            clear.xp = xp
            result.xp = xp
        }
        note { recap in
            recap.stardust += clear.stardust
            if clear.ultraBall { recap.ultraBalls += 1 }
            recap.dungeonStages.append(clear)
        }
    }

    // MARK: Growth

    /// Every party member shares the experience, fainted or not.
    private func award(_ xp: Int) {
        guard xp > 0 else { return }
        for id in partyIDs {
            guard let index = owned.firstIndex(where: { $0.id == id }) else { continue }
            grant(xp, to: index)
        }
        scheduleSave()
    }

    /// Adds experience up to the level cap and banks the rest, then handles level-ups, new moves
    /// and evolution.
    private func grant(_ xp: Int, to index: Int) {
        let before = owned[index]
        let limit = PokeMath.xpLimit(cap: levelCap)
        let total = before.xp + xp
        owned[index].xp = max(before.xp, min(total, limit))
        owned[index].banked += total - owned[index].xp
        grew(from: before, at: index)
    }

    private func grew(from before: OwnedPokemon, at index: Int) {
        let after = owned[index]
        guard after.level != before.level else { return }
        note { recap in
            if let row = recap.growth.firstIndex(where: { $0.member == after.id }) {
                recap.growth[row].to = after.level
            } else {
                recap.growth.append(.init(member: after.id, species: after.speciesID, from: before.level, to: after.level))
            }
        }
        checkEvolution(at: index)
        let member = owned[index]
        if let data, let species = data.dex[member.speciesID], let old = data.dex[before.speciesID] {
            let known = Set(data.moves.moveset(species: old.id, types: old.types, level: before.level).map(\.id))
            for move in data.moves.moveset(species: species.id, types: species.types, level: member.level) where !known.contains(move.id) {
                note { $0.learned.append(AdventureRecap.Learned(species: species.id, move: move.id)) }
            }
        }
        syncCombatant(member)
    }

    /// A badge raised the cap: banked experience flows back in.
    private func releaseBank() {
        let limit = PokeMath.xpLimit(cap: levelCap)
        for index in owned.indices where owned[index].banked > 0 {
            let before = owned[index]
            let moved = min(before.banked, max(0, limit - before.xp))
            owned[index].xp += moved
            owned[index].banked -= moved
            grew(from: before, at: index)
        }
    }

    private func syncCombatant(_ member: OwnedPokemon) {
        guard var state = battle, let data, let index = state.party.firstIndex(where: { $0.ownedID == member.id }),
              let species = data.dex[member.speciesID] else { return }
        state.party[index].become(species, level: member.level, moves: data.moves)
        battle = state
    }

    private func checkEvolution(at index: Int) {
        let member = owned[index]
        let ready = dex.evolutions(of: member.speciesID).filter { ($0.evolveLevel ?? .max) <= member.level }
        guard let next = ready.randomElement() else { return }
        let from = member.speciesID
        owned[index].speciesID = next.id
        caught.insert(next.id)
        seen.insert(next.id)
        claimDexRewards()
        note { recap in
            recap.evolutions.append(.init(from: from, to: next.id))
            if let row = recap.growth.firstIndex(where: { $0.member == member.id }) { recap.growth[row].species = next.id }
        }
        announceEvolution(from: from, to: next.id)
        // Two-stage jumps (a high-level find) evolve all the way.
        checkEvolution(at: index)
    }

    // MARK: Discovery

    private func discover(_ data: GameData) {
        guard rng.unit() < Self.stationInterval / Discovery.meanInterval(boxCount: owned.count) else { return }
        let pool = Discovery.pool(at: stationPoint, data: data)
        guard let speciesID = Discovery.roll(pool: pool, rng: &rng), let species = dex.species(speciesID) else { return }
        let level = Discovery.level(of: species, partyLevel: partyLevel, cap: levelCap, range: region.dexRange, rng: &rng)
        seen.insert(speciesID)
        let shiny = Shiny.roll(&rng)
        if let existing = owned(family: speciesID), let index = owned.firstIndex(where: { $0.id == existing.id }) {
            grant(Discovery.duplicateXP(level: level), to: index)
            if shiny { makeShiny(at: index, announce: true) }
            return
        }
        receive(species, level: level, origin: .wild, shiny: shiny)
        note { recap in
            recap.discovered.append(speciesID)
            if shiny { recap.shinies.append(speciesID) }
        }
        let encounter = PokeEncounter(id: UUID(), speciesID: speciesID, level: level, caught: true, isNew: true,
                                      isSpecial: species.isSpecial, date: Date(), shiny: shiny)
        if turns.isEmpty { announceDiscovery(encounter) } else { pendingDiscoveries.append(encounter) }
        saveNow()
    }

    /// A new Pokémon joins the box, and the party if there's room (at the back of the relay).
    private func receive(_ species: PokeSpecies, level: Int, origin: OwnedPokemon.Origin, shiny: Bool = false) {
        seen.insert(species.id)
        caught.insert(species.id)
        defer { claimDexRewards() }
        let newcomer = OwnedPokemon(id: UUID(), speciesID: species.id, xp: PokeMath.xp(forLevel: level), caughtAt: Date(), origin: origin,
                                    shiny: shiny)
        owned.append(newcomer)
        guard partyIDs.count < Self.maxParty else { return }
        partyIDs.append(newcomer.id)
        if var state = battle, let data, target?.isChallenge != true {
            state.party.append(Combatant(species: species, level: level, moves: data.moves, ownedID: newcomer.id))
            battle = state
        }
        refreshReadiness()
    }

    /// A shiny duplicate: the one you have starts to shine, at the level it's at.
    private func makeShiny(at index: Int, announce: Bool) {
        guard owned.indices.contains(index), !owned[index].shiny else { return }
        owned[index].shiny = true
        let species = owned[index].speciesID
        note { $0.shinies.append(species) }
        if announce, let name = dex.species(species)?.name {
            self.announce(title: RecapText.shinyNow(name), detail: nil, pokemonID: species, shiny: true)
        }
        saveNow()
    }

    /// An Ultra Ball for every ten species caught, including ones reached before this existed.
    private func claimDexRewards() {
        let earned = DexRewards.earned(caught: caught.count)
        guard earned > dexRewards else { return }
        let milestones = ((dexRewards + 1)...earned).map { $0 * DexRewards.every }
        ultraBalls += milestones.count
        dexRewards = earned
        note { recap in
            recap.dexMilestones += milestones
            recap.ultraBalls += milestones.count
        }
        if let top = milestones.last { announce(title: RecapText.dexMilestone(top), detail: nil, pokemonID: nil) }
        scheduleSave()
    }

    // MARK: Forecast

    private func refreshReadiness() {
        guard let next = progress.nextBoss(chapters) else {
            readiness = nil; levelHint = nil; forecastKey = nil
            return
        }
        // The box size counts too: a newcomer may make a better team.
        let key = party.map { "\($0.speciesID):\($0.level)" }.joined(separator: ",") + "@\(next.chapter).\(next.index)#\(owned.count)"
        guard key != forecastKey else { return }
        forecastKey = key
        let goal = BattleTarget.boss(chapter: next.chapter, index: next.index)
        readiness = winChance(goal)
        refreshLevelHint(goal)
    }

    /// Works out the level the party needs off the main thread; it takes a few forecasts.
    private func refreshLevelHint(_ goal: BattleTarget) {
        hintTask?.cancel()
        guard let data, let chance = readiness, chance < Guidance.goodChance, let plan = plan(for: goal, data: data, forecast: true) else {
            levelHint = nil
            return
        }
        let members = party.compactMap { member in data.dex[member.speciesID].map { (species: $0, level: member.level) } }
        let cap = levelCap
        hintTask = Task { [weak self] in
            let hint = await Task.detached(priority: .utility) {
                Guidance.levelHint(party: members, plan: plan, cap: cap, data: data)
            }.value
            guard !Task.isCancelled else { return }
            self?.levelHint = hint
        }
    }

    // MARK: Recap

    /// Records something for "while you were away", unless the page is showing it right now.
    private func note(_ change: (inout AdventureRecap) -> Void) {
        guard !isWatching else { return }
        if recap.since == nil { recap.since = Date() }
        recap.region = region
        change(&recap)
    }

    /// The page opened: what happened while it was closed moves to the history, and comes back
    /// once for the line over the battle.
    func takeRecap() -> AdventureRecap? {
        guard !recap.isEmpty else { return nil }
        var finished = recap
        finished.until = Date()
        recap = AdventureRecap()
        history.insert(finished, at: 0)
        trimHistory()
        historyUnread = true
        scheduleSave()
        return finished
    }

    func markHistoryRead() {
        guard historyUnread else { return }
        historyUnread = false
        scheduleSave()
    }

    /// Keeps today's and yesterday's recaps (days turn at 04:00, as the dungeon's do).
    private func trimHistory(now: Date = Date()) {
        let days = [DailyDungeon.day(of: now), DailyDungeon.day(of: now.addingTimeInterval(-86_400))]
        history = Array(history.filter { days.contains(DailyDungeon.day(of: $0.until ?? $0.since ?? now)) }.prefix(Self.historyLimit))
    }

    // MARK: Banners

    private func announceDiscovery(_ encounter: PokeEncounter, title: String? = nil) {
        guard preferences.adventureAnnounceCatches, let species = dex.species(encounter.speciesID) else { return }
        let fallback = encounter.shiny ? RecapText.shinyJoined(species.name) : String(localized: "\(species.name) joined your team!")
        var banner = NotchBanner(style: .adventure, title: title ?? fallback, encounter: encounter,
                                 duration: encounter.isSpecial || encounter.shiny ? 8 : 5)
        banner.pokemonID = species.id
        banner.shiny = encounter.shiny
        activity.post(banner)
        if preferences.adventureSound { NSSound(named: encounter.isSpecial ? "Hero" : "Glass")?.play() }
    }

    private func announceEvolution(from: Int, to: Int) {
        guard let before = dex.species(from), let after = dex.species(to) else { return }
        announce(title: String(localized: "\(before.name) evolved!"),
                 detail: String(localized: "It became \(after.name)."), pokemonID: to)
    }

    private func announceBadge(_ badge: Int) {
        guard preferences.adventureAnnounceCatches else { return }
        var banner = NotchBanner(style: .adventure, title: String(localized: "\(region.badgeName(badge)) earned!"),
                                 detail: String(localized: "Level cap raised to \(levelCap)."), duration: 6)
        banner.badge = region.badgeImage(badge)
        activity.post(banner)
        if preferences.adventureSound { NSSound(named: "Hero")?.play() }
    }

    private func announce(title: String, detail: String?, pokemonID: Int?, shiny: Bool = false) {
        guard preferences.adventureAnnounceCatches else { return }
        var banner = NotchBanner(style: .adventure, title: title, detail: detail, duration: shiny ? 8 : 5)
        banner.pokemonID = pokemonID
        banner.shiny = shiny
        activity.post(banner)
        if preferences.adventureSound { NSSound(named: "Glass")?.play() }
    }

    // MARK: Reset

    func resetAdventure() {
        region = .kanto
        away = [:]
        boxMerged = false
        owned = []
        partyIDs = []
        seen = []
        caught = []
        stardust = 0
        ultraBalls = 0
        progress = JourneyProgress()
        starter = nil
        battle = nil
        target = nil
        lastEvent = nil
        offer = nil
        recap = AdventureRecap()
        history = []
        historyUnread = false
        tower = TowerState()
        dexRewards = 0
        clears = 0
        wipes = 0
        pulls = 0
        dungeons = DungeonState(day: DailyDungeon.day(of: Date()))
        readiness = nil
        levelHint = nil
        forecastKey = nil
        forecasts = [:]
        cachedData = nil
        habitatCache = nil
        saveNow()
    }

    #if DEBUG
    func debugDiscover(_ speciesID: Int?) -> PokeEncounter? {
        guard hasStarted, let species = dex.species(speciesID ?? Int.random(in: 1...PokeDexStore.maxID)) else { return nil }
        let isNew = owned(family: species.id) == nil
        let level = Discovery.level(of: species, partyLevel: partyLevel, cap: levelCap, range: region.dexRange, rng: &rng)
        if isNew { receive(species, level: level, origin: .wild); note { $0.discovered.append(species.id) } }
        saveNow()
        return PokeEncounter(id: UUID(), speciesID: species.id, level: level, caught: true, isNew: isNew,
                             isSpecial: species.isSpecial, date: Date())
    }

    func debugXP(_ amount: Int) { award(amount) }

    /// Crowns the party, which opens the Battle Tower (and Johto, or in Johto merges the boxes).
    func debugChampion() {
        progress.isChampion = true
        if region == .johto { mergeBoxes() }
        saveNow()
    }

    /// Makes the party leader shine, as a shiny duplicate would.
    func debugShiny() {
        guard let leader, let index = owned.firstIndex(where: { $0.id == leader.id }) else { return }
        makeShiny(at: index, announce: true)
    }

    func debugBadgeBanner(_ badge: Int) { announceBadge(badge) }

    func debugStardust(_ amount: Int) { stardust += amount; saveNow() }

    func debugUltraBall() { ultraBalls += 1; saveNow() }

    /// Chapter and station are 1-based, as shown; station 11 means the line is cleared.
    func debugJump(chapter: Int, station: Int, badges: Int) {
        progress.chapter = max(0, min(chapter - 1, chapters.count - 1))
        progress.station = max(0, min(station - 1, Chapter.stationCount))
        progress.boss = 0
        progress.badges = badges
        progress.training = 0
        progress.repeating = nil
        progress.frontierWins = 0
        progress.moveOn(chapters)
        battle = nil
        target = nil
        releaseBank()
        refreshReadiness()
        saveNow()
    }

    /// Gives both dungeons their tries back; `stages` also starts their climbs over.
    func debugResetDungeon(stages: Bool) {
        let kept = dungeons
        dungeons = DungeonState(day: DailyDungeon.day(of: Date()))
        if !stages { dungeons.stardust.best = kept.stardust.best; dungeons.experience.best = kept.experience.best }
        saveNow()
    }

    /// Plays battle actions without waiting for an agent or the clock.
    func debugTicks(_ count: Int) {
        guard let data else { return }
        for _ in 0..<count {
            if battle == nil || battle?.isOver == true { lineUp(data) }
            step(data)
        }
    }
    #endif

    // MARK: Persistence

    /// The fields up to `dungeons` are Kanto's, as 1.2 wrote them, so 1.2 still reads its journey
    /// from a save with Johto in it; Johto sits beside them.
    private struct SaveFile: Codable {
        /// 4 split each of Kanto's legs into three chapters; 5 added Johto.
        var version = 5
        var starter: Int?
        var owned: [OwnedPokemon]
        var partyIDs: [UUID]
        var seen: [Int]
        var caught: [Int]
        var stardust: Int
        var ultraBalls: Int
        var progress: JourneyProgress
        /// AUTO is gone; still written so an older version can read the save.
        var autoChallenge = false
        var offer: [GachaCard]?
        var recap: AdventureRecap
        var history: [AdventureRecap]?
        var historyUnread: Bool?
        var tower: TowerState?
        var dexRewards: Int?
        var clears: Int
        var wipes: Int
        var pulls: Int
        var dungeons: DungeonState?
        /// The region being played; nil means Kanto.
        var region: Region?
        var johto: RegionState?
        /// After Johto's Champion the one box is the top-level `owned`, and Johto's is empty.
        var boxMerged: Bool?
    }

    /// v2's save: the same box, coins instead of stardust, and a position on the old map.
    private struct LegacySaveFile: Decodable {
        struct Progress: Decodable {
            struct Point: Decodable { var node: Int; var stage: Int }
            var frontier: Point
            var badges: Int
            var isChampion: Bool
            var beatenLegends: [String]
        }

        var starter: Int?
        var owned: [OwnedPokemon]
        var partyIDs: [UUID]
        var seen: [Int]
        var caught: [Int]
        var coins: Int
        var progress: Progress
        var autoChallenge: Bool
        var offer: [GachaCard]?
        var recap: AdventureRecap
        var clears: Int
        var wipes: Int
        var pulls: Int
    }

    private func load() {
        if let data = try? Data(contentsOf: storeURL) {
            do {
                let file = try JSONDecoder.adventure.decode(SaveFile.self, from: data)
                apply(starter: file.starter, owned: file.owned, partyIDs: file.partyIDs, seen: file.seen, caught: file.caught,
                      offer: file.offer, recap: file.recap, clears: file.clears, wipes: file.wipes, pulls: file.pulls)
                stardust = file.stardust
                ultraBalls = file.ultraBalls
                progress = file.progress
                if file.version < 4 { progress.splitChapters(into: Kanto.chaptersPerLeg) }
                // Lines used to wait at their end for the gym; they now go on to the next chapter.
                progress.moveOn(chapters)
                if let state = file.dungeons { dungeons = state }
                history = file.history ?? []
                historyUnread = file.historyUnread ?? false
                tower = file.tower ?? TowerState()
                // A run can't resume mid-floor across launches.
                tower.floor = nil
                trimHistory()
                // What was just read is Kanto's; Johto waits beside it, or is played.
                boxMerged = file.boxMerged ?? false
                if var johto = file.johto {
                    johto.progress.moveOn(Region.johto.chapters(starter: johto.starter ?? 0))
                    away[.johto] = johto
                }
                if file.region == .johto, isOpen(.johto) {
                    let box = owned
                    away[.kanto] = currentState()
                    region = .johto
                    restore(away.removeValue(forKey: .johto) ?? RegionState())
                    if boxMerged { owned = box }
                }
                if let rewards = file.dexRewards {
                    dexRewards = rewards
                } else {
                    // Saves from before the rewards count them from zero, so milestones already
                    // reached pay out once.
                    dexRewards = 0
                }
                claimDexRewards()
            } catch {
                // Never let the next save overwrite an adventure we couldn't read.
                let backup = storeURL.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: storeURL, to: backup)
                NSLog("pokove: couldn't read the adventure (\(error.localizedDescription)); moved it to \(backup.lastPathComponent)")
            }
            return
        }
        guard let legacyURL, let data = try? Data(contentsOf: legacyURL),
              let file = try? JSONDecoder.adventure.decode(LegacySaveFile.self, from: data) else { return }
        apply(starter: file.starter, owned: file.owned, partyIDs: file.partyIDs, seen: file.seen, caught: file.caught,
              offer: file.offer, recap: file.recap, clears: file.clears, wipes: file.wipes, pulls: file.pulls)
        stardust = file.coins
        progress = JourneyProgress.migrated(fromNode: file.progress.frontier.node, stage: file.progress.frontier.stage,
                                            badges: file.progress.badges, isChampion: file.progress.isChampion,
                                            beatenLegends: file.progress.beatenLegends)
        progress.splitChapters(into: Kanto.chaptersPerLeg)
        progress.moveOn(chapters)
        saveNow()
    }

    private func apply(starter: Int?, owned: [OwnedPokemon], partyIDs: [UUID], seen: [Int], caught: [Int],
                       offer: [GachaCard]?, recap: AdventureRecap, clears: Int, wipes: Int, pulls: Int) {
        self.starter = starter
        self.owned = owned
        self.partyIDs = partyIDs.filter { id in owned.contains { $0.id == id } }
        self.seen = Set(seen)
        self.caught = Set(caught)
        self.offer = offer
        self.recap = recap
        self.clears = clears
        self.wipes = wipes
        self.pulls = pulls
    }

    /// Experience ticks in constantly during battles; write at most every few seconds.
    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            self?.saveTask = nil
            self?.saveNow()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        let kanto = state(of: .kanto) ?? RegionState()
        var johto = state(of: .johto)
        // One box after the merge, kept where 1.2 looks for Kanto's.
        let box = boxMerged ? owned : kanto.owned
        if boxMerged { johto?.owned = [] }
        let file = SaveFile(starter: kanto.starter, owned: box, partyIDs: kanto.partyIDs, seen: seen.sorted(), caught: caught.sorted(),
                            stardust: kanto.stardust, ultraBalls: kanto.ultraBalls, progress: kanto.progress, offer: kanto.offer,
                            recap: recap, history: history, historyUnread: historyUnread, tower: kanto.tower, dexRewards: dexRewards,
                            clears: kanto.clears, wipes: kanto.wipes, pulls: kanto.pulls,
                            dungeons: kanto.dungeons, region: region == .kanto ? nil : region, johto: johto,
                            boxMerged: boxMerged ? true : nil)
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.adventure.encode(file).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("pokove: couldn't save the adventure: \(error.localizedDescription)")
        }
    }
}

private extension JSONEncoder {
    static var adventure: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var adventure: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension Array where Element == Chapter {
    subscript(safeChapter index: Int) -> Chapter? { indices.contains(index) ? self[index] : nil }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
