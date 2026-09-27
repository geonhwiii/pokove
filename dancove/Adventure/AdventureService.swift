import AppKit
import Observation

nonisolated struct OwnedPokemon: Codable, Identifiable, Equatable, Sendable {
    enum Origin: String, Codable, Sendable { case starter, wild, boss }

    let id: UUID
    var speciesID: Int
    var xp: Int
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

/// Who turned up at the end of a turn, and whether they joined.
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

/// The adventure: a party of up to three auto-battles through stages while a coding agent works,
/// and each finished turn may bring a wild Pokémon along.
@Observable
final class AdventureService {
    private(set) var owned: [OwnedPokemon] = []
    private(set) var partyIDs: [UUID] = []
    private(set) var seen: Set<Int> = []
    private(set) var caught: Set<Int> = []
    private(set) var progress = StageProgress()
    private(set) var battle: BattleState?
    /// The latest hit, for the scene to animate; `attackSerial` bumps on every one.
    private(set) var lastAttack: BattleAttack?
    private(set) var attackSerial = 0
    private(set) var lastEncounter: PokeEncounter?
    private(set) var clears = 0
    private(set) var wipes = 0
    /// True while the party is fighting (an agent is working).
    private(set) var isBattling = false

    let dex: PokeDexStore
    /// Set by the app: whether any coding agent is mid-turn right now.
    @ObservationIgnored var isAgentWorking: () -> Bool = { false }

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let storeURL: URL
    @ObservationIgnored private var turns: [String: Date] = [:]
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SeededRNG(seed: UInt64.random(in: 0...UInt64.max))
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    static let secondsPerAction: Double = 1.5
    static let maxParty = 3
    static let starters = [1, 4, 7]
    /// Chance that a boss beaten for the first time joins the party.
    static let bossJoinChance = 0.6

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
        let name = "adventure-debug.json"
        #else
        let name = "adventure.json"
        #endif
        return support.appendingPathComponent("dancove", isDirectory: true).appendingPathComponent(name)
    }

    // MARK: Derived

    var isEnabled: Bool { preferences.adventureEnabled }
    var hasStarted: Bool { !owned.isEmpty }
    var party: [OwnedPokemon] { partyIDs.compactMap { id in owned.first { $0.id == id } } }
    var partyLevel: Int { party.isEmpty ? 5 : party.map(\.level).reduce(0, +) / party.count }
    var leader: OwnedPokemon? { party.first }

    func pokemon(_ id: UUID) -> OwnedPokemon? { owned.first { $0.id == id } }

    /// The best-raised Pokémon of a species, if one is owned.
    func owned(species id: Int) -> OwnedPokemon? {
        owned.filter { $0.speciesID == id }.max { $0.xp < $1.xp }
    }

    func isInParty(_ id: UUID) -> Bool { partyIDs.contains(id) }

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
        let starter = OwnedPokemon(id: UUID(), speciesID: speciesID, xp: PokeMath.xp(forLevel: 5), caughtAt: Date(), origin: .starter)
        owned = [starter]
        partyIDs = [starter.id]
        seen.insert(speciesID)
        caught.insert(speciesID)
        progress = StageProgress()
        battle = nil
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
        // The next tick lines up the new party.
        battle = nil
        scheduleSave()
        return true
    }

    /// Moves a party member to the front, where it takes the first hits.
    func makeLeader(_ id: UUID) {
        guard let index = partyIDs.firstIndex(of: id), index > 0 else { return }
        partyIDs.remove(at: index)
        partyIDs.insert(id, at: 0)
        battle = nil
        scheduleSave()
    }

    // MARK: Agent turns

    func turnStarted(sessionID: String, at date: Date = Date()) {
        guard isEnabled else { return }
        turns[sessionID] = date
    }

    func hasTurn(for sessionID: String) -> Bool { turns[sessionID] != nil }
    var turnIDs: [String] { Array(turns.keys) }

    /// A finished turn: long enough, and something may turn up.
    @discardableResult
    func turnFinished(sessionID: String, at date: Date = Date()) -> PokeEncounter? {
        guard let start = turns.removeValue(forKey: sessionID), isEnabled, hasStarted, dex.isReady else { return nil }
        let duration = date.timeIntervalSince(start)
        guard duration >= WildEncounter.minimumTurn, duration <= 2 * 60 * 60 else { return nil }
        guard rng.unit() < WildEncounter.encounterChance else { return nil }
        return encounter(at: date)
    }

    /// Interrupted or failed: nothing turns up.
    func turnAborted(sessionID: String) {
        turns[sessionID] = nil
    }

    func endAllTurns() {
        turns.removeAll()
    }

    private func encounter(at date: Date, forcing speciesID: Int? = nil) -> PokeEncounter? {
        let view = DexView(dex.species)
        guard var wild = WildEncounter.roll(dex: view, partyLevel: partyLevel, rng: &rng) else { return nil }
        if let speciesID, let forced = dex.species(speciesID) {
            wild.speciesID = speciesID
            wild.level = WildEncounter.level(of: forced, partyLevel: partyLevel, rng: &rng)
        }
        guard let species = dex.species(wild.speciesID) else { return nil }
        let isNew = !caught.contains(species.id)
        seen.insert(species.id)
        let joined = speciesID != nil || rng.unit() < WildEncounter.captureChance(of: species)
        if joined { receive(species, level: wild.level, origin: .wild) }
        let result = PokeEncounter(id: UUID(), speciesID: species.id, level: wild.level, caught: joined,
                                   isNew: joined && isNew, isSpecial: species.isSpecial, date: date)
        lastEncounter = result
        saveNow()
        return result
    }

    /// A new Pokémon joins the box (and the party, if there's room). A second of the same
    /// species makes the first one stronger instead.
    private func receive(_ species: PokeSpecies, level: Int, origin: OwnedPokemon.Origin) {
        caught.insert(species.id)
        if let existing = owned(species: species.id), let index = owned.firstIndex(where: { $0.id == existing.id }) {
            owned[index].xp += WildEncounter.duplicateXP(level: level)
            checkEvolution(at: index)
            return
        }
        let newcomer = OwnedPokemon(id: UUID(), speciesID: species.id, xp: PokeMath.xp(forLevel: level), caughtAt: Date(), origin: origin)
        owned.append(newcomer)
        if partyIDs.count < Self.maxParty {
            partyIDs.append(newcomer.id)
            battle = nil
        }
    }

    // MARK: Battle

    private func tick() {
        guard isEnabled, hasStarted, dex.isReady, isAgentWorking() else {
            if isBattling { isBattling = false }
            return
        }
        if !isBattling { isBattling = true }
        let view = DexView(dex.species)
        if battle == nil || battle?.isOver == true { beginStage(view) }
        guard var state = battle else { return }
        let event = state.step(dex: view)
        battle = state
        guard let event else { return }

        switch event {
        case .waveStarted:
            if let state = battle { for enemy in state.enemies { seen.insert(enemy.speciesID) } }
        case .attack(let hit):
            lastAttack = hit
            attackSerial &+= 1
            if hit.byParty, hit.fainted, let enemy = battle?.combatant(hit.targetID), let species = dex.species(enemy.speciesID) {
                award(PokeMath.defeatXP(baseExperience: species.baseExperience, level: enemy.level, boss: enemy.isBoss))
            }
        case .stageCleared(let stage):
            clears += 1
            let opened = progress.record(cleared: true)
            if opened, stage.isBoss { bossCleared(stage) }
            battle = nil
            scheduleSave()
        case .wiped:
            wipes += 1
            progress.record(cleared: false)
            battle = nil
            scheduleSave()
        }
    }

    private func beginStage(_ view: DexView) {
        let members = party.compactMap { member in
            dex.species(member.speciesID).map { Combatant(species: $0, level: member.level, ownedID: member.id) }
        }
        guard !members.isEmpty else { battle = nil; return }
        battle = BattleState(plan: StagePlan.make(for: progress.current, dex: view), party: members, dex: view, seed: rng.next())
    }

    /// Every party member shares the experience, fainted or not.
    private func award(_ xp: Int) {
        for id in partyIDs {
            guard let index = owned.firstIndex(where: { $0.id == id }) else { continue }
            let before = owned[index].level
            owned[index].xp += xp
            let after = owned[index].level
            checkEvolution(at: index)
            if after != before || owned[index].speciesID != battle?.party.first(where: { $0.ownedID == id })?.speciesID {
                syncCombatant(owned[index])
            }
        }
        scheduleSave()
    }

    private func syncCombatant(_ member: OwnedPokemon) {
        guard var state = battle, let index = state.party.firstIndex(where: { $0.ownedID == member.id }),
              let species = dex.species(member.speciesID) else { return }
        state.party[index].become(species, level: member.level)
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
        announceEvolution(from: from, to: next.id)
        // Two-stage jumps (a high-level catch) evolve all the way.
        checkEvolution(at: index)
    }

    private func bossCleared(_ stage: Stage) {
        guard let boss = battle?.plan.waves.first?.first, let species = dex.species(boss.speciesID) else {
            announce(title: String(localized: "Stage \(stage.label) cleared!"), detail: nil, pokemonID: nil)
            return
        }
        if rng.unit() < Self.bossJoinChance {
            let isNew = !caught.contains(species.id)
            receive(species, level: max(5, partyLevel - 4), origin: .boss)
            lastEncounter = PokeEncounter(id: UUID(), speciesID: species.id, level: boss.level, caught: true, isNew: isNew,
                                          isSpecial: species.isSpecial, date: Date())
            announce(title: String(localized: "Boss \(stage.label) cleared!"),
                     detail: String(localized: "\(species.name) joined your team."), pokemonID: species.id)
        } else {
            announce(title: String(localized: "Boss \(stage.label) cleared!"),
                     detail: String(localized: "On to world \(stage.world + 1)."), pokemonID: species.id)
        }
    }

    // MARK: Banners

    private func announceEvolution(from: Int, to: Int) {
        guard let before = dex.species(from), let after = dex.species(to) else { return }
        announce(title: String(localized: "\(before.name) evolved!"),
                 detail: String(localized: "It became \(after.name)."), pokemonID: to)
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
        progress = StageProgress()
        battle = nil
        lastAttack = nil
        lastEncounter = nil
        clears = 0
        wipes = 0
        saveNow()
    }

    #if DEBUG
    func debugCatch(_ speciesID: Int?) -> PokeEncounter? {
        guard hasStarted, dex.isReady else { return nil }
        return encounter(at: Date(), forcing: speciesID ?? Int.random(in: 1...PokeDexStore.maxID))
    }

    func debugXP(_ amount: Int) { award(amount) }

    func debugStage(_ stage: Stage) {
        progress = StageProgress(frontier: stage, training: 0)
        battle = nil
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
        var version = 1
        var owned: [OwnedPokemon]
        var partyIDs: [UUID]
        var seen: [Int]
        var caught: [Int]
        var progress: StageProgress
        var clears: Int
        var wipes: Int
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        do {
            let file = try JSONDecoder.adventure.decode(SaveFile.self, from: data)
            owned = file.owned
            partyIDs = file.partyIDs.filter { id in file.owned.contains { $0.id == id } }
            seen = Set(file.seen)
            caught = Set(file.caught)
            progress = file.progress
            clears = file.clears
            wipes = file.wipes
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
        let file = SaveFile(owned: owned, partyIDs: partyIDs, seen: seen.sorted(), caught: caught.sorted(),
                            progress: progress, clears: clears, wipes: wipes)
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
