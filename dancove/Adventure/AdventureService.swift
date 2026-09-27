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

    var level: Int { PokeMath.level(forXP: xp) }
    /// Progress from this level to the next, 0–1.
    var levelProgress: Double {
        let level = level
        guard level < PokeMath.maxLevel else { return 1 }
        let floor = PokeMath.xp(forLevel: level), ceiling = PokeMath.xp(forLevel: level + 1)
        return Double(xp - floor) / Double(max(1, ceiling - floor))
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
}

/// What happened since the adventure page was last looked at.
nonisolated struct AdventureRecap: Codable, Equatable, Sendable {
    struct Learned: Codable, Equatable, Sendable {
        let species: Int
        let move: Int
    }

    var clears = 0
    var coins = 0
    var levels = 0
    /// Species new to the dex, from discoveries.
    var discovered: [Int] = []
    var evolved: [Int] = []
    var learned: [Learned] = []
    var badges: [Int] = []

    var isEmpty: Bool { clears == 0 && levels == 0 && discovered.isEmpty && evolved.isEmpty && badges.isEmpty }
}

/// The adventure: a party of up to three travels Kanto on its own while a coding agent works,
/// battling wild Pokémon and gym leaders in a 1:1 relay. Pokémon join through discoveries and
/// the gacha; badges raise the level cap.
@Observable
final class AdventureService {
    private(set) var owned: [OwnedPokemon] = []
    private(set) var partyIDs: [UUID] = []
    private(set) var seen: Set<Int> = []
    private(set) var caught: Set<Int> = []
    private(set) var coins = 0
    private(set) var progress = JourneyProgress()
    private(set) var starter: Int?
    private(set) var battle: BattleState?
    /// What the current battle is for.
    private(set) var target: BattleTarget?
    /// The latest battle event, for the scene; `eventSerial` bumps on every one.
    private(set) var lastEvent: BattleEvent?
    private(set) var eventSerial = 0
    /// Three cards waiting for the user to pick one.
    private(set) var offer: [GachaCard]?
    private(set) var recap = AdventureRecap()
    private(set) var clears = 0
    private(set) var wipes = 0
    private(set) var pulls = 0
    /// True while the party is fighting (an agent is working).
    private(set) var isBattling = false
    /// Forecast chance of beating the trainer at the frontier with the current party.
    private(set) var readiness: Double?
    /// Challenge gyms by itself once the party is likely to win.
    var autoChallenge = true {
        didSet {
            guard autoChallenge != oldValue else { return }
            if autoChallenge { progress.challenge = false }
            restartIfHolding()
            scheduleSave()
        }
    }

    let dex: PokeDexStore
    /// Set by the app: whether any coding agent is mid-turn right now.
    @ObservationIgnored var isAgentWorking: () -> Bool = { false }

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var turns: [String: Date] = [:]
    /// New species found mid-turn, shown with the next "finished" banner.
    @ObservationIgnored private var pendingDiscoveries: [PokeEncounter] = []
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SeededRNG(seed: UInt64.random(in: 0...UInt64.max))
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// Set by the adventure page while it's on screen: what happens then isn't news later.
    @ObservationIgnored var isWatching = false
    @ObservationIgnored private var cachedData: GameData?
    @ObservationIgnored private var cachedStarter: Int?
    @ObservationIgnored private var forecastKey: String?

    static let secondsPerAction: Double = 1.5
    static let maxParty = 3
    static let starters = [1, 4, 7]

    init(preferences: Preferences, activity: ActivityCenter, dex: PokeDexStore = PokeDexStore(),
         storeURL: URL = AdventureService.defaultStoreURL) {
        self.preferences = preferences
        self.activity = activity
        self.dex = dex
        self.storeURL = storeURL
        load()
    }

    static var defaultStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        let name = "adventure-v2-debug.json"
        #else
        let name = "adventure-v2.json"
        #endif
        return support.appendingPathComponent("dancove", isDirectory: true).appendingPathComponent(name)
    }

    // MARK: Derived

    var isEnabled: Bool { preferences.adventureEnabled }
    var hasStarted: Bool { !owned.isEmpty }
    var party: [OwnedPokemon] { partyIDs.compactMap { id in owned.first { $0.id == id } } }
    var partyLevel: Int { party.isEmpty ? 5 : party.map(\.level).reduce(0, +) / party.count }
    var leader: OwnedPokemon? { party.first }
    var levelCap: Int { Kanto.levelCap(badges: progress.badges, champion: progress.isChampion) }
    var canPull: Bool { hasStarted && offer == nil && coins >= Gacha.price }

    /// Species, moves and encounters together, once everything is downloaded.
    var data: GameData? {
        guard dex.isReady, let moves = dex.moves, let encounters = dex.encounters else { return nil }
        if let cachedData, cachedStarter == starter { return cachedData }
        let built = GameData(species: dex.species, moves: moves, encounters: encounters, starter: starter ?? 4)
        cachedData = built
        cachedStarter = starter
        return built
    }

    var nodes: [JourneyNode] { data?.nodes ?? Kanto.main(starter: starter ?? 4) }

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

    func moves(of member: OwnedPokemon) -> [PokeMove] {
        guard let data, let species = data.dex[member.speciesID] else { return [] }
        return data.moves.moveset(species: species.id, types: species.types, level: member.level)
    }

    /// The node the party is fighting on.
    var currentNode: JourneyNode? {
        switch target ?? progress.target(nodes, auto: autoChallenge, readiness: readiness ?? 1) {
        case .stage(let point): nodes.indices.contains(point.node) ? nodes[point.node] : nil
        case .legend(let id): Kanto.legends.first { $0.id == id }
        }
    }

    var currentPoint: StagePoint? {
        if case .stage(let point) = target ?? progress.target(nodes, auto: autoChallenge, readiness: readiness ?? 1) { return point }
        return nil
    }

    /// The trainer waiting at the frontier, if the next step is a gym or the League.
    var frontierTrainer: Trainer? {
        guard !progress.isComplete(nodes) else { return nil }
        let node = nodes[progress.frontier.node]
        return node.trainers.indices.contains(progress.frontier.stage) ? node.trainers[progress.frontier.stage] : nil
    }

    var isHolding: Bool { progress.isHolding(nodes, auto: autoChallenge, readiness: readiness ?? 0) }

    // MARK: Lifecycle

    func start() {
        dex.load()
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.secondsPerAction))
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
        guard owned.isEmpty, dex.species(speciesID) != nil else { return }
        let first = OwnedPokemon(id: UUID(), speciesID: speciesID, xp: PokeMath.xp(forLevel: 5), caughtAt: Date(), origin: .starter)
        owned = [first]
        partyIDs = [first.id]
        seen = [speciesID]
        caught = [speciesID]
        starter = speciesID
        coins = Gacha.startingCoins
        progress = JourneyProgress()
        battle = nil
        cachedData = nil
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

    /// Moves a party member to the front, where it battles first.
    func makeLeader(_ id: UUID) {
        guard let index = partyIDs.firstIndex(of: id), index > 0 else { return }
        partyIDs.remove(at: index)
        partyIDs.insert(id, at: 0)
        partyChanged()
    }

    /// Swaps in the three best for whatever comes next: the trainer ahead, or the strongest.
    func recommendParty() {
        guard let data else { return }
        let candidates = owned.compactMap { member in
            data.dex[member.speciesID].map { Recommend.Candidate(id: member.id, species: $0, level: member.level) }
        }
        let picks = Recommend.party(from: candidates, against: upcomingFoes(data), data: data, size: Self.maxParty)
        guard !picks.isEmpty, picks != partyIDs else { return }
        partyIDs = picks
        partyChanged()
    }

    /// The trainer or legendary the party should get ready for.
    private func upcomingFoes(_ data: GameData) -> [StagePlan.Foe] {
        var scratch = SeededRNG(seed: 1)
        if let legend = progress.legend, let node = data.node(legend) {
            return StagePlan.make(node: node, stage: 0, data: data, partyLevel: 100, rng: &scratch).foes
        }
        guard !progress.isComplete(data.nodes), !data.nodes[progress.frontier.node].isRoute else { return [] }
        return StagePlan.make(node: data.nodes[progress.frontier.node], stage: progress.frontier.stage, data: data,
                              partyLevel: 100, rng: &scratch).foes
    }

    private func partyChanged() {
        // The next tick lines up the new party.
        battle = nil
        refreshReadiness()
        scheduleSave()
    }

    // MARK: Journey controls

    /// Takes on the trainer at the frontier now, whatever the forecast says.
    func challengeTrainer() {
        guard frontierTrainer != nil else { return }
        progress.challenge = true
        progress.stay = nil
        battle = nil
        scheduleSave()
    }

    /// Stays on a stretch already reached, to meet its Pokémon.
    func stay(at index: Int) {
        guard nodes.indices.contains(index), nodes[index].isRoute, progress.clearedStages(of: index, in: nodes) > 0 else { return }
        progress.stay = index
        progress.cursor = 0
        battle = nil
        scheduleSave()
    }

    func resumeJourney() {
        guard progress.stay != nil || progress.legend != nil else { return }
        progress.stay = nil
        progress.legend = nil
        battle = nil
        scheduleSave()
    }

    func challengeLegend(_ id: String) {
        guard let node = Kanto.legends.first(where: { $0.id == id }), !progress.beatenLegends.contains(id),
              progress.isReached(legend: node, in: nodes) else { return }
        progress.legend = id
        battle = nil
        refreshReadiness()
        scheduleSave()
    }

    private func restartIfHolding() {
        if case .stage(let point)? = target, point != progress.frontier { battle = nil }
    }

    // MARK: Gacha

    func pull() {
        guard canPull, let data else { return }
        coins -= Gacha.price
        pulls += 1
        let pool = Gacha.pool(progress: progress, data: data)
        var levels = SeededRNG(seed: rng.next())
        let partyLevel = partyLevel, cap = levelCap
        // The first pull always brings someone new.
        offer = Gacha.draw(pool: pool, level: { id in
            data.dex[id].map { Discovery.level(of: $0, partyLevel: partyLevel, cap: cap, rng: &levels) } ?? 5
        }, isOwned: { self.owned(family: $0) != nil }, duplicateWeight: pulls == 1 ? 0 : 0.3, rng: &rng)
        saveNow()
    }

    /// Keeps one card: a new Pokémon joins, or the one you have of its line grows.
    func pick(_ cardID: UUID) {
        guard let card = offer?.first(where: { $0.id == cardID }), let species = dex.species(card.species) else { return }
        offer = nil
        if let existing = owned(family: card.species), let index = owned.firstIndex(where: { $0.id == existing.id }) {
            grant(Gacha.duplicateXP(level: existing.level), to: index)
        } else {
            receive(species, level: card.level, origin: .gacha)
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
        // A stage is always lined up, so the scene shows who's next even while agents rest.
        if battle == nil || battle?.isOver == true { beginStage(data) }
        guard isAgentWorking() else {
            if isBattling { isBattling = false }
            return
        }
        if !isBattling { isBattling = true }
        discover(data)
        guard var state = battle else { return }
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
            if let foeID, let foe = battle?.combatant(foeID), let species = dex.species(foe.speciesID), let plan = battle?.plan {
                award(PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: partyLevel, kind: plan.kind))
            }
        case .cleared:
            finishStage(cleared: true, data: data)
        case .wiped:
            finishStage(cleared: false, data: data)
        }
    }

    private func beginStage(_ data: GameData) {
        refreshReadiness()
        let next = progress.target(data.nodes, auto: autoChallenge, readiness: readiness ?? 1)
        let plan: StagePlan
        switch next {
        case .stage(let point):
            plan = StagePlan.make(node: data.nodes[point.node], stage: point.stage, data: data, partyLevel: partyLevel, rng: &rng)
        case .legend(let id):
            guard let node = data.node(id) else { progress.legend = nil; return }
            plan = StagePlan.make(node: node, stage: 0, data: data, partyLevel: partyLevel, rng: &rng)
        }
        let members = party.compactMap { member in
            data.dex[member.speciesID].map { Combatant(species: $0, level: member.level, moves: data.moves, ownedID: member.id) }
        }
        guard !members.isEmpty else { battle = nil; return }
        target = next
        let state = BattleState(plan: plan, party: members, data: data, seed: rng.next())
        if let foe = state.foeActive { seen.insert(foe.speciesID) }
        battle = state
    }

    private func finishStage(cleared: Bool, data: GameData) {
        guard let target, let plan = battle?.plan else { return }
        if cleared {
            clears += 1
            let reward = Rewards.coins(for: plan.kind)
            coins += reward
            note { $0.clears += 1; $0.coins += reward }
        } else {
            wipes += 1
        }
        let outcome = progress.record(target, cleared: cleared, nodes: data.nodes)
        switch outcome {
        case .badge(let badge):
            releaseBank()
            note { $0.badges.append(badge) }
            announceBadge(badge)
        case .champion:
            releaseBank()
            announce(title: String(localized: "You're the Champion!"),
                     detail: String(localized: "Something stirs in Cerulean Cave…"), pokemonID: plan.foes.last?.species)
        case .legend(let id):
            if let node = data.node(id), case .legend(let speciesID, let level, _) = node.kind, let species = dex.species(speciesID) {
                let isNew = !caught.contains(speciesID)
                receive(species, level: min(level, levelCap), origin: .legend, announce: false)
                let encounter = PokeEncounter(id: UUID(), speciesID: speciesID, level: level, caught: true, isNew: isNew,
                                              isSpecial: true, date: Date())
                announceDiscovery(encounter, title: String(localized: "\(species.name) joined your team!"))
            }
        case .advanced, .none:
            break
        }
        battle = nil
        refreshReadiness()
        // The next stage lines up at once, so the scene never sits empty between stages.
        beginStage(data)
        scheduleSave()
    }

    // MARK: Growth

    /// Every party member shares the experience, fainted or not.
    private func award(_ xp: Int) {
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
        note { $0.levels += after.level - before.level }
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
        note { $0.evolved.append(next.id) }
        announceEvolution(from: from, to: next.id)
        // Two-stage jumps (a high-level find) evolve all the way.
        checkEvolution(at: index)
    }

    // MARK: Discovery

    private func discover(_ data: GameData) {
        guard rng.unit() < Self.secondsPerAction / Discovery.meanInterval(boxCount: owned.count), let target else { return }
        let pool = Discovery.pool(for: target, progress: progress, data: data)
        guard let speciesID = Discovery.roll(pool: pool, rng: &rng), let species = dex.species(speciesID) else { return }
        let level = Discovery.level(of: species, partyLevel: partyLevel, cap: levelCap, rng: &rng)
        seen.insert(speciesID)
        if let existing = owned(family: speciesID), let index = owned.firstIndex(where: { $0.id == existing.id }) {
            grant(Discovery.duplicateXP(level: level), to: index)
            return
        }
        receive(species, level: level, origin: .wild)
        note { $0.discovered.append(speciesID) }
        let encounter = PokeEncounter(id: UUID(), speciesID: speciesID, level: level, caught: true, isNew: true,
                                      isSpecial: species.isSpecial, date: Date())
        if turns.isEmpty { announceDiscovery(encounter) } else { pendingDiscoveries.append(encounter) }
        saveNow()
    }

    /// A new Pokémon joins the box, and the party if there's room (at the back of the relay).
    private func receive(_ species: PokeSpecies, level: Int, origin: OwnedPokemon.Origin, announce: Bool = true) {
        seen.insert(species.id)
        caught.insert(species.id)
        let newcomer = OwnedPokemon(id: UUID(), speciesID: species.id, xp: PokeMath.xp(forLevel: level), caughtAt: Date(), origin: origin)
        owned.append(newcomer)
        guard partyIDs.count < Self.maxParty else { return }
        partyIDs.append(newcomer.id)
        if var state = battle, let data {
            state.party.append(Combatant(species: species, level: level, moves: data.moves, ownedID: newcomer.id))
            battle = state
        }
        refreshReadiness()
    }

    // MARK: Forecast

    private func refreshReadiness() {
        guard let data else { readiness = nil; return }
        let foes = upcomingFoes(data)
        guard !foes.isEmpty else { readiness = nil; forecastKey = nil; return }
        let key = party.map { "\($0.speciesID):\($0.level)" }.joined(separator: ",") + "@" + foes.map { "\($0.species):\($0.level)" }.joined(separator: ",")
        guard key != forecastKey else { return }
        forecastKey = key
        var scratch = SeededRNG(seed: 1)
        let plan: StagePlan
        if let legend = progress.legend, let node = data.node(legend) {
            plan = StagePlan.make(node: node, stage: 0, data: data, partyLevel: 100, rng: &scratch)
        } else {
            plan = StagePlan.make(node: data.nodes[progress.frontier.node], stage: progress.frontier.stage, data: data,
                                  partyLevel: 100, rng: &scratch)
        }
        let members = party.compactMap { member in
            data.dex[member.speciesID].map { Combatant(species: $0, level: member.level, moves: data.moves, ownedID: member.id) }
        }
        readiness = Forecast.winChance(party: members, plan: plan, data: data)
    }

    // MARK: Recap

    /// Records something for "while you were away", unless the page is showing it right now.
    private func note(_ change: (inout AdventureRecap) -> Void) {
        guard !isWatching else { return }
        change(&recap)
    }

    /// Called once the recap card has been shown.
    func markRecapSeen() {
        guard !recap.isEmpty else { return }
        recap = AdventureRecap()
        scheduleSave()
    }

    // MARK: Banners

    private func announceDiscovery(_ encounter: PokeEncounter, title: String? = nil) {
        guard preferences.adventureAnnounceCatches, let species = dex.species(encounter.speciesID) else { return }
        var banner = NotchBanner(style: .adventure, title: title ?? String(localized: "\(species.name) joined your team!"),
                                 encounter: encounter, duration: encounter.isSpecial ? 8 : 5)
        banner.pokemonID = species.id
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
        var banner = NotchBanner(style: .adventure, title: String(localized: "\(Kanto.badgeName(badge)) earned!"),
                                 detail: String(localized: "Level cap raised to \(levelCap)."), duration: 6)
        banner.badge = badge
        activity.post(banner)
        if preferences.adventureSound { NSSound(named: "Hero")?.play() }
    }

    private func announce(title: String, detail: String?, pokemonID: Int?) {
        guard preferences.adventureAnnounceCatches else { return }
        var banner = NotchBanner(style: .adventure, title: title, detail: detail, duration: 5)
        banner.pokemonID = pokemonID
        activity.post(banner)
        if preferences.adventureSound { NSSound(named: "Glass")?.play() }
    }

    // MARK: Reset

    func resetAdventure() {
        owned = []
        partyIDs = []
        seen = []
        caught = []
        coins = 0
        progress = JourneyProgress()
        starter = nil
        battle = nil
        target = nil
        lastEvent = nil
        offer = nil
        recap = AdventureRecap()
        clears = 0
        wipes = 0
        pulls = 0
        readiness = nil
        forecastKey = nil
        cachedData = nil
        saveNow()
    }

    #if DEBUG
    func debugDiscover(_ speciesID: Int?) -> PokeEncounter? {
        guard hasStarted, let species = dex.species(speciesID ?? Int.random(in: 1...PokeDexStore.maxID)) else { return nil }
        let isNew = owned(family: species.id) == nil
        let level = Discovery.level(of: species, partyLevel: partyLevel, cap: levelCap, rng: &rng)
        if isNew { receive(species, level: level, origin: .wild); note { $0.discovered.append(species.id) } }
        saveNow()
        return PokeEncounter(id: UUID(), speciesID: species.id, level: level, caught: true, isNew: isNew,
                             isSpecial: species.isSpecial, date: Date())
    }

    func debugXP(_ amount: Int) { award(amount) }

    func debugBadgeBanner(_ badge: Int) { announceBadge(badge) }

    func debugCoins(_ amount: Int) { coins += amount; saveNow() }

    func debugJump(node: Int, stage: Int, badges: Int) {
        progress.frontier = StagePoint(node: max(0, min(node, nodes.count)), stage: max(0, stage))
        progress.badges = badges
        progress.training = 0
        progress.stay = nil
        progress.legend = nil
        battle = nil
        releaseBank()
        refreshReadiness()
        saveNow()
    }

    /// Plays battle actions without waiting for an agent.
    func debugTicks(_ count: Int) {
        let working = isAgentWorking
        isAgentWorking = { true }
        for _ in 0..<count { tick() }
        isAgentWorking = working
    }
    #endif

    // MARK: Persistence

    private struct SaveFile: Codable {
        var version = 2
        var starter: Int?
        var owned: [OwnedPokemon]
        var partyIDs: [UUID]
        var seen: [Int]
        var caught: [Int]
        var coins: Int
        var progress: JourneyProgress
        var autoChallenge: Bool
        var offer: [GachaCard]?
        var recap: AdventureRecap
        var clears: Int
        var wipes: Int
        var pulls: Int
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        do {
            let file = try JSONDecoder.adventure.decode(SaveFile.self, from: data)
            starter = file.starter
            owned = file.owned
            partyIDs = file.partyIDs.filter { id in file.owned.contains { $0.id == id } }
            seen = Set(file.seen)
            caught = Set(file.caught)
            coins = file.coins
            progress = file.progress
            autoChallenge = file.autoChallenge
            offer = file.offer
            recap = file.recap
            clears = file.clears
            wipes = file.wipes
            pulls = file.pulls
        } catch {
            // Never let the next save overwrite an adventure we couldn't read.
            let backup = storeURL.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: storeURL, to: backup)
            NSLog("dancove: couldn't read the adventure (\(error.localizedDescription)); moved it to \(backup.lastPathComponent)")
        }
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
        let file = SaveFile(starter: starter, owned: owned, partyIDs: partyIDs, seen: seen.sorted(), caught: caught.sorted(),
                            coins: coins, progress: progress, autoChallenge: autoChallenge, offer: offer, recap: recap,
                            clears: clears, wipes: wipes, pulls: pulls)
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.adventure.encode(file).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("dancove: couldn't save the adventure: \(error.localizedDescription)")
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
