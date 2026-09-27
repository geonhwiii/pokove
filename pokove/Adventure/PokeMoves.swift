import Foundation

// Moves and level-up learnsets as they were in FireRed/LeafGreen, downloaded from PokéAPI at
// runtime like the rest of the dex.

nonisolated extension PokeType {
    /// Gen 3 decided physical or special by the move's type.
    var isPhysical: Bool {
        switch self {
        case .normal, .fighting, .flying, .poison, .ground, .rock, .bug, .ghost, .steel: true
        default: false
        }
    }

    /// PokéAPI's type ids.
    init?(apiID: Int) {
        let order: [PokeType] = [.normal, .fighting, .flying, .poison, .ground, .rock, .bug, .ghost, .steel,
                                 .fire, .water, .grass, .electric, .psychic, .ice, .dragon, .dark, .fairy]
        guard (1...order.count).contains(apiID) else { return nil }
        self = order[apiID - 1]
    }
}

/// Status conditions a damaging move can leave behind. Sleep and freeze never come from the
/// damaging moves Pokémon use here, so they aren't modeled.
nonisolated enum Ailment: String, Codable, Sendable {
    case poison, burn, paralysis

    /// PokéAPI's move_meta_ailment ids.
    init?(apiID: Int?) {
        switch apiID {
        case 1: self = .paralysis
        case 4: self = .burn
        case 5: self = .poison
        default: return nil
        }
    }

    /// Poison and Steel types can't be poisoned, Fire types can't be burned (Gen 3).
    func affects(_ types: [PokeType]) -> Bool {
        switch self {
        case .poison: !types.contains(.poison) && !types.contains(.steel)
        case .burn: !types.contains(.fire)
        case .paralysis: true
        }
    }
}

nonisolated struct PokeMove: Codable, Identifiable, Equatable, Sendable {
    /// How a move decides its damage.
    enum Damage: Codable, Equatable, Sendable {
        case power(Int)
        /// Always this much (Sonic Boom, Dragon Rage).
        case fixed(Int)
        /// As much as the user's level (Seismic Toss, Night Shade).
        case level
        /// Half the target's remaining HP (Super Fang).
        case halfHP
    }

    let id: Int
    let slug: String
    let nameKo: String
    let nameEn: String
    let type: PokeType
    let damage: Damage
    /// nil never misses.
    let accuracy: Int?
    let priority: Int
    let minHits: Int
    let maxHits: Int
    /// Percent of the damage dealt that heals the user, or hurts it when negative (recoil).
    let drain: Int
    /// 1 for moves with a high critical-hit ratio.
    let critStage: Int
    /// A status the target may be left with, and the percent chance.
    let ailment: Ailment?
    let ailmentChance: Int

    var name: String { PokeLanguage.isKorean ? nameKo : nameEn }
    var isPhysical: Bool { type.isPhysical }

    var power: Int? { if case .power(let power) = damage { power } else { nil } }

    /// Roughly how much damage the move does for a Pokémon of these types at this level, as a
    /// power value, for choosing a moveset.
    func rating(types: [PokeType], level: Int) -> Double {
        let hits: Double = maxHits > minHits ? (minHits == 2 && maxHits == 5 ? 3 : Double(minHits + maxHits) / 2) : Double(minHits)
        let chance = Double(accuracy ?? 100) / 100
        // Fixed damage as the power that would do as much between evenly matched Pokémon.
        let scale = 2 * Double(level) / 5 + 2
        let equivalent: Double = switch damage {
        case .power(let power): Double(power) * (types.contains(type) ? 1.5 : 1)
        case .fixed(let amount): max(0, Double(amount - 2)) * 50 / scale
        case .level: max(0, Double(level - 2)) * 50 / scale
        case .halfHP: 60
        }
        // Resting moves are worth a bit less than their raw power.
        return equivalent * hits * chance * (1 - 0.08 * Double(cooldown))
    }

    /// Turns a strong move rests after it's used, so a moveset rotates like an idle game's skills.
    var cooldown: Int {
        switch damage {
        case .power(let power): power >= 95 ? 3 : (power >= 75 ? 2 : (power >= 60 ? 1 : 0))
        case .fixed, .level, .halfHP: 1
        }
    }

    /// What anyone uses when nothing else can do damage. Typeless here, so it always lands.
    static let struggle = PokeMove(id: 165, slug: "struggle", nameKo: "발버둥", nameEn: "Struggle", type: .normal,
                                   damage: .power(50), accuracy: nil, priority: 0, minHits: 1, maxHits: 1, drain: -25,
                                   critStage: 0, ailment: nil, ailmentChance: 0)
}

/// Every move the 151 learn by leveling up in FireRed/LeafGreen, and when.
nonisolated struct MoveDex: Codable, Sendable {
    struct Learn: Codable, Equatable, Sendable {
        let species: Int
        let level: Int
        let move: Int
    }

    let moves: [PokeMove]
    let learnsets: [Learn]

    private var byID: [Int: PokeMove] = [:]
    private var bySpecies: [Int: [Learn]] = [:]

    private enum CodingKeys: String, CodingKey { case moves, learnsets }

    init(moves: [PokeMove], learnsets: [Learn]) {
        self.moves = moves
        self.learnsets = learnsets
        index()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        moves = try container.decode([PokeMove].self, forKey: .moves)
        learnsets = try container.decode([Learn].self, forKey: .learnsets)
        index()
    }

    private mutating func index() {
        byID = Dictionary(moves.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        bySpecies = Dictionary(grouping: learnsets, by: \.species)
    }

    func move(_ id: Int) -> PokeMove? { byID[id] }

    /// The four best damaging moves learned by this level: strongest first, favoring its own
    /// types, with at most two of any type so it has answers to more matchups. Struggle when
    /// there are none.
    func moveset(species: Int, types: [PokeType], level: Int) -> [PokeMove] {
        var known: [PokeMove] = []
        for learn in bySpecies[species] ?? [] where learn.level <= level {
            guard let move = byID[learn.move], !known.contains(where: { $0.id == move.id }) else { continue }
            known.append(move)
        }
        let ranked = known.sorted { $0.rating(types: types, level: level) > $1.rating(types: types, level: level) }
        var set: [PokeMove] = []
        for move in ranked where set.count < 4 && set.filter({ $0.type == move.type }).count < 2 {
            set.append(move)
        }
        for move in ranked where set.count < 4 && !set.contains(move) { set.append(move) }
        return set.isEmpty ? [PokeMove.struggle] : set
    }

    /// Moves a species learns on reaching exactly this level.
    func learned(species: Int, at level: Int) -> [PokeMove] {
        (bySpecies[species] ?? []).filter { $0.level == level }.compactMap { byID[$0.move] }
    }
}

nonisolated extension PokeAPI {
    /// FireRed/LeafGreen.
    private static let versionGroup = 7

    static func fetchMoves(maxID: Int) async throws -> MoveDex {
        let learnFilter = "version_group_id: {_eq: \(versionGroup)}, move_learn_method_id: {_eq: 1}, pokemon_id: {_lte: \(maxID)}"
        let query = """
        query { learnsets: pokemon_v2_pokemonmove(where: {\(learnFilter)}, order_by: [{pokemon_id: asc}, {level: asc}, {order: asc}]) { p: pokemon_id l: level m: move_id } \
        moves: pokemon_v2_move(where: {pokemon_v2_pokemonmoves: {\(learnFilter)}}, order_by: {id: asc}) { \
        id name power accuracy priority type_id c: move_damage_class_id \
        names: pokemon_v2_movenames(where: {language_id: {_in: [3, 9]}}) { language_id name } \
        meta: pokemon_v2_movemeta { min_hits max_hits drain crit_rate ailment_chance move_meta_ailment_id } \
        changes: pokemon_v2_movechanges(order_by: {version_group_id: asc}) { version_group_id power accuracy type_id move_effect_chance } } }
        """
        let data = try await post(query)
        let decoded = try JSONDecoder().decode(MoveResponse.self, from: data)
        guard let payload = decoded.data, !payload.moves.isEmpty else { throw URLError(.cannotParseResponse) }
        let moves = payload.moves.compactMap(\.move)
        let usable = Set(moves.map(\.id))
        let learnsets = payload.learnsets.filter { usable.contains($0.m) }.map { MoveDex.Learn(species: $0.p, level: $0.l, move: $0.m) }
        return MoveDex(moves: moves, learnsets: learnsets)
    }

    private struct MoveResponse: Decodable {
        var data: Payload?
        struct Payload: Decodable {
            var learnsets: [LearnRow]
            var moves: [MoveRow]
        }
        struct LearnRow: Decodable { var p: Int; var l: Int; var m: Int }
    }

    private struct MoveRow: Decodable {
        var id: Int
        var name: String
        var power: Int?
        var accuracy: Int?
        var priority: Int?
        var type_id: Int?
        var c: Int?
        var names: [Name]
        var meta: [Meta]
        var changes: [Change]

        struct Name: Decodable { var language_id: Int; var name: String }
        struct Meta: Decodable {
            var min_hits: Int?; var max_hits: Int?; var drain: Int?; var crit_rate: Int?
            var ailment_chance: Int?; var move_meta_ailment_id: Int?
        }
        struct Change: Decodable { var version_group_id: Int; var power: Int?; var accuracy: Int?; var type_id: Int?; var move_effect_chance: Int? }

        /// Moves that make no sense in an auto-battle: the user faints, the target must be
        /// asleep, damage depends on things this game doesn't track, or it's a one-hit KO.
        static let excluded: Set<String> = [
            "explosion", "self-destruct", "dream-eater", "snore", "spit-up", "endeavor", "horn-drill", "fissure",
            "guillotine", "sheer-cold", "flail", "reversal", "counter", "mirror-coat", "bide", "future-sight",
            "present", "return", "frustration", "false-swipe",
        ]

        var move: PokeMove? {
            // PokéAPI keeps today's numbers and lists what they were before each change. The first
            // change after FireRed/LeafGreen holds the Gen 3 value. Colosseum and XD don't count.
            let later = changes.filter { $0.version_group_id > 7 && $0.version_group_id != 12 && $0.version_group_id != 13 }
            let power = later.first { $0.power != nil }?.power ?? power
            let accuracy = later.first { $0.accuracy != nil }?.accuracy ?? accuracy
            let typeID = later.first { $0.type_id != nil }?.type_id ?? type_id
            guard c != 1, !Self.excluded.contains(name), let type = typeID.flatMap(PokeType.init(apiID:)) else { return nil }

            let damage: PokeMove.Damage
            switch name {
            case "sonic-boom": damage = .fixed(20)
            case "dragon-rage": damage = .fixed(40)
            case "seismic-toss", "night-shade": damage = .level
            case "super-fang": damage = .halfHP
            case "magnitude": damage = .power(70)
            case "low-kick": damage = .power(50)
            default:
                guard let power, power > 0 else { return nil }
                damage = .power(power)
            }
            let meta = meta.first
            let ailment = Ailment(apiID: meta?.move_meta_ailment_id)
            let ailmentChance = later.first { $0.move_effect_chance != nil }?.move_effect_chance ?? meta?.ailment_chance ?? 0
            let ko = names.first { $0.language_id == 3 }?.name
            let en = names.first { $0.language_id == 9 }?.name
            return PokeMove(
                id: id, slug: name, nameKo: ko ?? en ?? name, nameEn: en ?? name.capitalized, type: type, damage: damage,
                accuracy: accuracy, priority: priority ?? 0,
                minHits: max(1, meta?.min_hits ?? 1), maxHits: max(1, meta?.max_hits ?? meta?.min_hits ?? 1),
                drain: meta?.drain ?? 0, critStage: meta?.crit_rate ?? 0,
                ailment: ailment, ailmentChance: ailment == nil ? 0 : ailmentChance
            )
        }
    }
}
