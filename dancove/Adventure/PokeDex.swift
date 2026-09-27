import Foundation
import Observation

// Pokémon data is downloaded from PokéAPI at runtime and cached on this Mac; nothing is bundled.
// Pokémon and all related names are trademarks of Nintendo, Game Freak and The Pokémon Company.

nonisolated enum PokeType: String, Codable, CaseIterable, Sendable {
    case normal, fire, water, electric, grass, ice, fighting, poison, ground
    case flying, psychic, bug, rock, ghost, dragon, dark, steel, fairy

    var title: String {
        switch self {
        case .normal: String(localized: "Normal")
        case .fire: String(localized: "Fire")
        case .water: String(localized: "Water")
        case .electric: String(localized: "Electric")
        case .grass: String(localized: "Grass")
        case .ice: String(localized: "Ice")
        case .fighting: String(localized: "Fighting")
        case .poison: String(localized: "Poison")
        case .ground: String(localized: "Ground")
        case .flying: String(localized: "Flying")
        case .psychic: String(localized: "Psychic")
        case .bug: String(localized: "Bug")
        case .rock: String(localized: "Rock")
        case .ghost: String(localized: "Ghost")
        case .dragon: String(localized: "Dragon")
        case .dark: String(localized: "Dark")
        case .steel: String(localized: "Steel")
        case .fairy: String(localized: "Fairy")
        }
    }

    var hex: UInt32 {
        switch self {
        case .normal: 0xA8A77A
        case .fire: 0xEE8130
        case .water: 0x6390F0
        case .electric: 0xF7D02C
        case .grass: 0x7AC74C
        case .ice: 0x96D9D6
        case .fighting: 0xC22E28
        case .poison: 0xA33EA1
        case .ground: 0xE2BF65
        case .flying: 0xA98FF3
        case .psychic: 0xF95587
        case .bug: 0xA6B91A
        case .rock: 0xB6A136
        case .ghost: 0x735797
        case .dragon: 0x6F35FC
        case .dark: 0x705746
        case .steel: 0xB7B7CE
        case .fairy: 0xD685AD
        }
    }

    /// Damage multiplier for a move of this type hitting `defender`.
    func effectiveness(against defender: PokeType) -> Double {
        Self.chart[self]?[defender] ?? 1
    }

    func effectiveness(against defenders: [PokeType]) -> Double {
        defenders.reduce(1) { $0 * effectiveness(against: $1) }
    }

    private static let chart: [PokeType: [PokeType: Double]] = [
        .normal: [.rock: 0.5, .ghost: 0, .steel: 0.5],
        .fire: [.fire: 0.5, .water: 0.5, .grass: 2, .ice: 2, .bug: 2, .rock: 0.5, .dragon: 0.5, .steel: 2],
        .water: [.fire: 2, .water: 0.5, .grass: 0.5, .ground: 2, .rock: 2, .dragon: 0.5],
        .electric: [.water: 2, .electric: 0.5, .grass: 0.5, .ground: 0, .flying: 2, .dragon: 0.5],
        .grass: [.fire: 0.5, .water: 2, .grass: 0.5, .poison: 0.5, .ground: 2, .flying: 0.5, .bug: 0.5, .rock: 2,
                 .dragon: 0.5, .steel: 0.5],
        .ice: [.fire: 0.5, .water: 0.5, .grass: 2, .ice: 0.5, .ground: 2, .flying: 2, .dragon: 2, .steel: 0.5],
        .fighting: [.normal: 2, .ice: 2, .poison: 0.5, .flying: 0.5, .psychic: 0.5, .bug: 0.5, .rock: 2, .ghost: 0,
                    .dark: 2, .steel: 2, .fairy: 0.5],
        .poison: [.grass: 2, .poison: 0.5, .ground: 0.5, .rock: 0.5, .ghost: 0.5, .steel: 0, .fairy: 2],
        .ground: [.fire: 2, .electric: 2, .grass: 0.5, .poison: 2, .flying: 0, .bug: 0.5, .rock: 2, .steel: 2],
        .flying: [.electric: 0.5, .grass: 2, .fighting: 2, .bug: 2, .rock: 0.5, .steel: 0.5],
        .psychic: [.fighting: 2, .poison: 2, .psychic: 0.5, .dark: 0, .steel: 0.5],
        .bug: [.fire: 0.5, .grass: 2, .fighting: 0.5, .poison: 0.5, .flying: 0.5, .psychic: 2, .ghost: 0.5, .dark: 2,
               .steel: 0.5, .fairy: 0.5],
        .rock: [.fire: 2, .ice: 2, .fighting: 0.5, .ground: 0.5, .flying: 2, .bug: 2, .steel: 0.5],
        .ghost: [.normal: 0, .psychic: 2, .ghost: 2, .dark: 0.5],
        .dragon: [.dragon: 2, .steel: 0.5, .fairy: 0],
        .dark: [.fighting: 0.5, .psychic: 2, .ghost: 2, .dark: 0.5, .fairy: 0.5],
        .steel: [.fire: 0.5, .water: 0.5, .electric: 0.5, .ice: 2, .rock: 2, .steel: 0.5, .fairy: 2],
        .fairy: [.fire: 0.5, .fighting: 2, .poison: 0.5, .dragon: 2, .dark: 2, .steel: 0.5],
    ]
}

nonisolated struct BaseStats: Codable, Equatable, Sendable {
    var hp: Int
    var attack: Int
    var defense: Int
    var spAttack: Int
    var spDefense: Int
    var speed: Int

    var total: Int { hp + attack + defense + spAttack + spDefense + speed }
}

nonisolated struct PokeSpecies: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let slug: String
    let nameKo: String
    let nameEn: String
    let genusKo: String
    let genusEn: String
    let flavorKo: String
    let flavorEn: String
    let types: [PokeType]
    let stats: BaseStats
    let baseExperience: Int
    let captureRate: Int
    let isLegendary: Bool
    let isMythical: Bool
    /// The species this one evolves from, when it's in the dex.
    let evolvesFrom: Int?
    /// The level at which `evolvesFrom` becomes this species. Item, trade and friendship
    /// evolutions are mapped to levels.
    let evolveLevel: Int?

    var name: String { PokeLanguage.isKorean ? nameKo : nameEn }
    var genus: String { PokeLanguage.isKorean ? genusKo : genusEn }
    var flavor: String { PokeLanguage.isKorean ? flavorKo : flavorEn }
    var isSpecial: Bool { isLegendary || isMythical }
    /// "#025".
    var number: String { String(format: "#%03d", id) }
}

nonisolated enum PokeLanguage {
    static let isKorean = Bundle.main.preferredLocalizations.first?.hasPrefix("ko") ?? false
}

/// The Pokédex: species, moves and Kanto's wild encounters, fetched once from PokéAPI and cached.
@Observable
final class PokeDexStore {
    enum State: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    nonisolated static let maxID = 151
    static let cacheVersion = 1

    private(set) var state: State = .idle
    private(set) var species: [PokeSpecies] = []
    /// FireRed/LeafGreen moves and learnsets.
    private(set) var moves: MoveDex?
    /// FireRed/LeafGreen wild encounters for the journey's areas.
    private(set) var encounters: EncounterDex?

    @ObservationIgnored private var byID: [Int: PokeSpecies] = [:]
    @ObservationIgnored private var evolutionsByID: [Int: [Int]] = [:]
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored let directory: URL

    init(directory: URL = PokeDexStore.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("dancove", isDirectory: true)
            .appendingPathComponent("pokemon", isDirectory: true)
    }

    private var cacheURL: URL { directory.appendingPathComponent("dex-v\(Self.cacheVersion).json") }
    private var movesURL: URL { directory.appendingPathComponent("moves-v1.json") }
    private var encountersURL: URL { directory.appendingPathComponent("encounters-v1.json") }

    var isReady: Bool { state == .ready }

    func species(_ id: Int) -> PokeSpecies? { byID[id] }

    /// Species that evolve directly from `id`.
    func evolutions(of id: Int) -> [PokeSpecies] { (evolutionsByID[id] ?? []).compactMap { byID[$0] } }

    /// 1 for a base form, 2 or 3 for evolved forms.
    func stage(of id: Int) -> Int {
        var stage = 1
        var current = byID[id]
        while let from = current?.evolvesFrom, let previous = byID[from] {
            stage += 1
            current = previous
        }
        return stage
    }

    /// The whole line, from the base form, following the first branch after `id`.
    func line(of id: Int) -> [PokeSpecies] {
        var base = byID[id]
        while let from = base?.evolvesFrom, let previous = byID[from] { base = previous }
        guard let base else { return [] }
        var line = [base]
        var current = base
        while let next = evolutions(of: current.id).first(where: { isAncestor(id, of: $0.id) || $0.id == id })
            ?? evolutions(of: current.id).first {
            line.append(next)
            current = next
        }
        return line
    }

    private func isAncestor(_ id: Int, of other: Int) -> Bool {
        var current = byID[id]
        while let from = current?.evolvesFrom {
            if from == other { return true }
            current = byID[from]
        }
        return false
    }

    // MARK: Loading

    /// Loads the cached dex, moves and encounters, or downloads what's missing (three requests
    /// in parallel, a few seconds the first time).
    func load() {
        guard state != .ready, state != .loading else { return }
        let cachedSpecies = (try? Data(contentsOf: cacheURL)).flatMap { try? JSONDecoder().decode([PokeSpecies].self, from: $0) }
            .flatMap { $0.count == Self.maxID ? $0 : nil }
        let cachedMoves = (try? Data(contentsOf: movesURL)).flatMap { try? JSONDecoder().decode(MoveDex.self, from: $0) }
        let cachedEncounters = (try? Data(contentsOf: encountersURL)).flatMap { try? JSONDecoder().decode(EncounterDex.self, from: $0) }
        if let cachedSpecies, let cachedMoves, let cachedEncounters {
            apply(cachedSpecies, moves: cachedMoves, encounters: cachedEncounters)
            return
        }
        state = .loading
        let directory = directory, cacheURL = cacheURL, movesURL = movesURL, encountersURL = encountersURL
        loadTask = Task { [weak self] in
            let maxID = Self.maxID, areas = Self.journeyAreas
            do {
                async let species = Self.fetch(cachedSpecies) { try await PokeAPI.fetchSpecies(maxID: maxID) }
                async let moves = Self.fetch(cachedMoves) { try await PokeAPI.fetchMoves(maxID: maxID) }
                async let encounters = Self.fetch(cachedEncounters) { try await PokeAPI.fetchEncounters(areas: areas) }
                let (speciesList, moveDex, encounterDex) = try await (species, moves, encounters)
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if cachedSpecies == nil { try? JSONEncoder().encode(speciesList).write(to: cacheURL, options: .atomic) }
                if cachedMoves == nil { try? JSONEncoder().encode(moveDex).write(to: movesURL, options: .atomic) }
                if cachedEncounters == nil { try? JSONEncoder().encode(encounterDex).write(to: encountersURL, options: .atomic) }
                self?.apply(speciesList, moves: moveDex, encounters: encounterDex)
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
        }
    }

    static let journeyAreas = Array(Set(Kanto.main(starter: 4).flatMap(\.areas))).sorted()

    private nonisolated static func fetch<T: Sendable>(_ cached: T?, _ download: @Sendable () async throws -> T) async throws -> T {
        if let cached { return cached }
        return try await download()
    }

    func retry() {
        if case .failed = state { state = .idle }
        load()
    }

    private func apply(_ list: [PokeSpecies], moves: MoveDex, encounters: EncounterDex) {
        self.moves = moves
        self.encounters = encounters
        species = list.sorted { $0.id < $1.id }
        byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        var evolutions: [Int: [Int]] = [:]
        for entry in species {
            if let from = entry.evolvesFrom { evolutions[from, default: []].append(entry.id) }
        }
        evolutionsByID = evolutions
        state = .ready
    }
}

/// PokéAPI's GraphQL endpoint: the whole Gen 1 dex in one request.
nonisolated enum PokeAPI {
    static let graphQL = URL(string: "https://beta.pokeapi.co/graphql/v1beta")!
    static let spriteBase = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
    static let badgeBase = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/badges"
    static let itemBase = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items"
    static let trainerBase = "https://play.pokemonshowdown.com/sprites/trainers"

    private static let koreanID = 3
    private static let englishID = 9

    static func fetchSpecies(maxID: Int) async throws -> [PokeSpecies] {
        let query = """
        query { species: pokemon_v2_pokemonspecies(where: {id: {_lte: \(maxID)}}, order_by: {id: asc}) { \
        id name capture_rate is_legendary is_mythical evolves_from_species_id \
        names: pokemon_v2_pokemonspeciesnames(where: {language_id: {_in: [\(koreanID), \(englishID)]}}) { name genus language_id } \
        flavorKo: pokemon_v2_pokemonspeciesflavortexts(where: {language_id: {_eq: \(koreanID)}}, order_by: {version_id: desc}, limit: 1) { flavor_text } \
        flavorEn: pokemon_v2_pokemonspeciesflavortexts(where: {language_id: {_eq: \(englishID)}}, order_by: {version_id: desc}, limit: 1) { flavor_text } \
        evolutions: pokemon_v2_pokemonevolutions { min_level evolution_trigger_id } \
        pokemon: pokemon_v2_pokemons(where: {is_default: {_eq: true}}) { base_experience \
        types: pokemon_v2_pokemontypes { slot type: pokemon_v2_type { name } } \
        stats: pokemon_v2_pokemonstats { base_stat stat: pokemon_v2_stat { name } } } } }
        """
        let data = try await post(query)
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let rows = decoded.data?.species, !rows.isEmpty else { throw URLError(.cannotParseResponse) }
        return rows.compactMap { $0.species(maxID: maxID) }
    }

    static func post(_ query: String) async throws -> Data {
        var request = URLRequest(url: graphQL, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private struct Response: Decodable {
        var data: Payload?
        struct Payload: Decodable { var species: [Row] }
    }

    private struct Row: Decodable {
        var id: Int
        var name: String
        var capture_rate: Int?
        var is_legendary: Bool
        var is_mythical: Bool
        var evolves_from_species_id: Int?
        var names: [Name]
        var flavorKo: [Flavor]
        var flavorEn: [Flavor]
        var evolutions: [Evolution]
        var pokemon: [Pokemon]

        struct Name: Decodable { var name: String; var genus: String; var language_id: Int? }
        struct Flavor: Decodable { var flavor_text: String }
        struct Evolution: Decodable { var min_level: Int?; var evolution_trigger_id: Int? }
        struct Pokemon: Decodable {
            var base_experience: Int?
            var types: [TypeSlot]
            var stats: [Stat]
            struct TypeSlot: Decodable { var slot: Int; var type: Named }
            struct Stat: Decodable { var base_stat: Int; var stat: Named }
            struct Named: Decodable { var name: String }
        }

        func species(maxID: Int) -> PokeSpecies? {
            guard let pokemon = pokemon.first else { return nil }
            let ko = names.first { $0.language_id == PokeAPI.koreanID }
            let en = names.first { $0.language_id == PokeAPI.englishID }
            let types = pokemon.types.sorted { $0.slot < $1.slot }.compactMap { PokeType(rawValue: $0.type.name) }
            func stat(_ name: String) -> Int { pokemon.stats.first { $0.stat.name == name }?.base_stat ?? 50 }
            let from = evolves_from_species_id.flatMap { $0 <= maxID ? $0 : nil }
            return PokeSpecies(
                id: id,
                slug: name,
                nameKo: ko?.name ?? name.capitalized,
                nameEn: en?.name ?? name.capitalized,
                genusKo: ko?.genus ?? "",
                genusEn: en?.genus ?? "",
                flavorKo: Self.clean(flavorKo.first?.flavor_text),
                flavorEn: Self.clean(flavorEn.first?.flavor_text),
                types: types.isEmpty ? [.normal] : types,
                stats: BaseStats(hp: stat("hp"), attack: stat("attack"), defense: stat("defense"),
                                 spAttack: stat("special-attack"), spDefense: stat("special-defense"), speed: stat("speed")),
                baseExperience: pokemon.base_experience ?? 60,
                captureRate: capture_rate ?? 45,
                isLegendary: is_legendary,
                isMythical: is_mythical,
                evolvesFrom: from,
                evolveLevel: from == nil ? nil : Self.level(for: evolutions)
            )
        }

        /// Item, trade and friendship evolutions get a level, so everything evolves by leveling.
        static func level(for evolutions: [Evolution]) -> Int {
            if let level = evolutions.compactMap(\.min_level).min() { return level }
            switch evolutions.first?.evolution_trigger_id {
            case 2: return 36   // trade
            case 3: return 30   // use-item
            default: return 22  // friendship and other level-up conditions
            }
        }

        static func clean(_ text: String?) -> String {
            guard let text else { return "" }
            return text
                .replacingOccurrences(of: "\u{0C}", with: " ")
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
        }
    }
}
