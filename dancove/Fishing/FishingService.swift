import Foundation
import Observation

/// A fish landed at the end of a Claude turn.
nonisolated struct FishCatch: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let speciesID: String
    /// Centimeters.
    let size: Double
    let date: Date
    let project: String?
    /// First of its species in the collection.
    var isNew: Bool
    /// Bigger than every earlier catch of the species.
    var isRecord: Bool
    /// In the top slice of the species' size range: a 월척.
    var isTrophy: Bool

    var species: FishSpecies? { FishCatalog.species(id: speciesID) }
}

/// The fishing mini-game: while Claude works a line is in the water, every tool call is a nibble,
/// and a finished turn reels something in. Longer, busier turns bring rarer fish.
@Observable
final class FishingService {
    struct Entry: Codable, Equatable, Sendable {
        var count: Int
        var firstCaughtAt: Date
        var lastCaughtAt: Date
        var bestSize: Double
    }

    /// One line in the water, per Claude session.
    struct Cast: Equatable, Sendable {
        var startedAt: Date
        var nibbles: Int
    }

    /// What happened when the line last came out of the water.
    enum Outcome: Equatable, Sendable {
        case caught(FishCatch)
        /// The turn ended too soon for a bite.
        case tooQuick
        case escaped
        /// Interrupted or failed: the line snapped.
        case snapped
    }

    private(set) var entries: [String: Entry] = [:]
    private(set) var recent: [FishCatch] = []
    private(set) var totalCatches = 0
    private(set) var casts: [String: Cast] = [:]
    private(set) var lastOutcome: Outcome?
    /// Bumps on every nibble so the bobber can dip.
    private(set) var nibbleTick = 0

    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let storeURL: URL
    /// Catches since the last Legendary or Mythic, for a pity guarantee.
    @ObservationIgnored private var dryStreak = 0
    @ObservationIgnored private var escapes = 0

    /// Turns shorter than this never get a bite.
    static let minimumTurn: TimeInterval = 6
    static let maximumTurn: TimeInterval = 2 * 60 * 60
    /// A Legendary is guaranteed after this many catches without one.
    static let pityThreshold = 120

    init(preferences: Preferences, storeURL: URL = FishingService.defaultStoreURL) {
        self.preferences = preferences
        self.storeURL = storeURL
        load()
    }

    static var defaultStoreURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        // Debug catches (previews, screenshots) must never end up in the real collection.
        let name = "fishing-debug.json"
        #else
        let name = "fishing.json"
        #endif
        return support.appendingPathComponent("dancove", isDirectory: true).appendingPathComponent(name)
    }

    // MARK: Derived

    var isFishing: Bool { preferences.fishingEnabled && !casts.isEmpty }

    var caughtSpeciesCount: Int { entries.count }

    func entry(for species: FishSpecies) -> Entry? { entries[species.id] }

    func caughtCount(of rarity: FishRarity) -> Int {
        FishCatalog.species(of: rarity).filter { entries[$0.id] != nil }.count
    }

    /// The earliest line still in the water, for the bobber's timer.
    var oldestCast: Cast? { casts.values.min { $0.startedAt < $1.startedAt } }

    // MARK: Claude lifecycle

    func cast(sessionID: String, at date: Date = Date()) {
        guard preferences.fishingEnabled else { return }
        casts[sessionID] = Cast(startedAt: date, nibbles: 0)
    }

    /// A tool call during a turn. Calls outside a turn (background agents after `Stop`) don't
    /// open a new line.
    func nibble(sessionID: String) {
        guard preferences.fishingEnabled, casts[sessionID] != nil else { return }
        casts[sessionID]?.nibbles += 1
        nibbleTick &+= 1
    }

    func hasLine(for sessionID: String) -> Bool { casts[sessionID] != nil }

    /// Ends a turn normally and rolls for a catch.
    @discardableResult
    func reel(sessionID: String, project: String?, at date: Date = Date()) -> FishCatch? {
        // Take the line out of the water first, even when fishing was turned off mid-turn.
        guard let cast = casts.removeValue(forKey: sessionID), preferences.fishingEnabled else { return nil }
        let duration = date.timeIntervalSince(cast.startedAt)
        // A line left out for hours (missed hooks, sleep) is stale, not a record-breaking turn.
        guard duration <= Self.maximumTurn else {
            lastOutcome = .snapped
            return nil
        }
        guard duration >= Self.minimumTurn else {
            lastOutcome = .tooQuick
            return nil
        }
        let biteChance = min(1, 0.45 + duration / 60 + Double(cast.nibbles) * 0.04)
        guard Double.random(in: 0..<1) < biteChance else {
            escapes += 1
            lastOutcome = .escaped
            return nil
        }
        let rarity = rollRarity(duration: duration, nibbles: cast.nibbles)
        return land(pickSpecies(of: rarity), project: project, at: date)
    }

    /// Interrupted, failed or closed: the line comes back empty.
    func snap(sessionID: String) {
        guard casts.removeValue(forKey: sessionID) != nil else { return }
        lastOutcome = .snapped
    }

    /// Pulls every line out, e.g. when fishing or the Claude integration is switched off.
    func reelInAll() {
        guard !casts.isEmpty else { return }
        casts.removeAll()
    }

    // MARK: Rolls

    /// Longer turns and more tool calls tilt the odds toward rarer fish, up to 4×.
    static func luck(duration: TimeInterval, nibbles: Int) -> Double {
        1 + min(2, duration / 300) + min(1, Double(nibbles) / 30)
    }

    static func weights(luck: Double) -> [FishRarity: Double] {
        var weights: [FishRarity: Double] = [:]
        for rarity in FishRarity.allCases {
            let boost = rarity >= .rare ? luck : 1
            weights[rarity] = rarity.baseWeight * boost
        }
        return weights
    }

    private func rollRarity(duration: TimeInterval, nibbles: Int) -> FishRarity {
        if dryStreak + 1 >= Self.pityThreshold { return .legendary }
        let weights = Self.weights(luck: Self.luck(duration: duration, nibbles: nibbles))
        let total = weights.values.reduce(0, +)
        var roll = Double.random(in: 0..<total)
        for rarity in FishRarity.allCases.reversed() {
            let weight = weights[rarity] ?? 0
            if roll < weight { return rarity }
            roll -= weight
        }
        return .normal
    }

    /// Leans toward species not in the collection yet, so progress keeps moving.
    private func pickSpecies(of rarity: FishRarity) -> FishSpecies {
        let pool = FishCatalog.species(of: rarity)
        let missing = pool.filter { entries[$0.id] == nil }
        if !missing.isEmpty && Double.random(in: 0..<1) < 0.6 {
            return missing.randomElement()!
        }
        return pool.randomElement()!
    }

    private func land(_ species: FishSpecies, project: String?, at date: Date) -> FishCatch {
        // Skewed toward the small end; trophies are genuinely rare.
        let roll = pow(Double.random(in: 0..<1), 1.6)
        let range = species.sizeRange
        let size = ((range.lowerBound + (range.upperBound - range.lowerBound) * roll) * 10).rounded() / 10
        let previous = entries[species.id]

        let fish = FishCatch(
            id: UUID(),
            speciesID: species.id,
            size: size,
            date: date,
            project: project,
            isNew: previous == nil,
            isRecord: previous.map { size > $0.bestSize } ?? false,
            isTrophy: roll > 0.85
        )

        var entry = previous ?? Entry(count: 0, firstCaughtAt: date, lastCaughtAt: date, bestSize: 0)
        entry.count += 1
        entry.lastCaughtAt = date
        entry.bestSize = max(entry.bestSize, size)
        entries[species.id] = entry

        totalCatches += 1
        dryStreak = species.rarity >= .legendary ? 0 : dryStreak + 1
        recent.insert(fish, at: 0)
        if recent.count > 30 { recent.removeLast(recent.count - 30) }
        lastOutcome = .caught(fish)
        save()
        return fish
    }

    // MARK: Collection management

    func resetCollection() {
        entries = [:]
        recent = []
        totalCatches = 0
        dryStreak = 0
        escapes = 0
        lastOutcome = nil
        save()
    }

    #if DEBUG
    /// Lands a fish of the given rarity immediately, for previews and screenshots.
    @discardableResult
    func debugCatch(rarity: FishRarity? = nil, speciesID: String? = nil) -> FishCatch {
        let species = speciesID.flatMap(FishCatalog.species(id:)) ?? pickSpecies(of: rarity ?? rollRarity(duration: 120, nibbles: 12))
        return land(species, project: "dancove", at: Date())
    }
    #endif

    // MARK: Persistence

    private struct SaveFile: Codable {
        var version = 1
        var entries: [String: Entry]
        var recent: [FishCatch]
        var totalCatches: Int
        var dryStreak: Int
        var escapes: Int

        init(entries: [String: Entry], recent: [FishCatch], totalCatches: Int, dryStreak: Int, escapes: Int) {
            self.entries = entries
            self.recent = recent
            self.totalCatches = totalCatches
            self.dryStreak = dryStreak
            self.escapes = escapes
        }

        /// Missing fields fall back to defaults, so older and newer files still load.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            entries = try container.decodeIfPresent([String: Entry].self, forKey: .entries) ?? [:]
            recent = (try? container.decodeIfPresent([FishCatch].self, forKey: .recent)) ?? []
            totalCatches = try container.decodeIfPresent(Int.self, forKey: .totalCatches) ?? entries.values.reduce(0) { $0 + $1.count }
            dryStreak = try container.decodeIfPresent(Int.self, forKey: .dryStreak) ?? 0
            escapes = try container.decodeIfPresent(Int.self, forKey: .escapes) ?? 0
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let file: SaveFile
        do {
            file = try JSONDecoder.fishing.decode(SaveFile.self, from: data)
        } catch {
            // Never let the next catch overwrite a collection we couldn't read: set it aside first.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = storeURL.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: storeURL, to: backup)
            NSLog("dancove: couldn't read the fishing log (\(error.localizedDescription)); moved it to \(backup.lastPathComponent)")
            return
        }
        // Species can be retired between versions; keep only the ones that still exist.
        entries = file.entries.filter { FishCatalog.species(id: $0.key) != nil }
        recent = file.recent.filter { FishCatalog.species(id: $0.speciesID) != nil }
        totalCatches = file.totalCatches
        dryStreak = file.dryStreak
        escapes = file.escapes
    }

    private func save() {
        let file = SaveFile(entries: entries, recent: recent, totalCatches: totalCatches, dryStreak: dryStreak, escapes: escapes)
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.fishing.encode(file).write(to: storeURL, options: .atomic)
        } catch {
            NSLog("dancove: couldn't save the fishing log: \(error.localizedDescription)")
        }
    }
}

private extension JSONEncoder {
    static var fishing: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var fishing: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension FishCatch {
    /// "38.2cm" or, for the giants, "3.2m".
    static func format(size: Double) -> String {
        if size >= 100 {
            let meters = size / 100
            return meters >= 100 ? String(format: "%.0fm", meters) : String(format: "%.1fm", meters)
        }
        return String(format: "%.1fcm", size)
    }
}
