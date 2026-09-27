import Foundation

// The journey through Kanto: places on the map, the gyms and the League, the legendaries, and
// which real FireRed/LeafGreen encounter areas stock each stretch. Trainer teams and place names are
// written here because PokéAPI has neither; wild encounter tables are downloaded at runtime.

/// A gym leader, Elite Four member or champion, with their FireRed/LeafGreen team.
nonisolated struct Trainer: Equatable, Sendable {
    struct Member: Equatable, Sendable {
        let species: Int
        let level: Int
    }

    let id: String
    let nameKo: String
    let nameEn: String
    let titleKo: String
    let titleEn: String
    /// Showdown's trainer sprite, in its FireRed/LeafGreen style.
    let sprite: String
    let specialty: PokeType?
    let team: [Member]
    /// 1–8 for gym leaders.
    let badge: Int?

    var name: String { PokeLanguage.isKorean ? nameKo : nameEn }
    var title: String { PokeLanguage.isKorean ? titleKo : titleEn }
    var isChampion: Bool { id == "blue" }

    /// Trainers bring three, like the party: the last three of their team, ace included.
    var battleTeam: [Member] { Array(team.suffix(Self.maxTeam)) }
    static let maxTeam = 3
}

/// A point on the 54×30 Kanto map grid.
nonisolated struct MapPoint: Equatable, Sendable {
    let x: Double
    let y: Double
}

/// The look of a stage's backdrop.
nonisolated enum Scenery: Int, Sendable {
    case meadow, forest, cave, sea, volcano, ice, tower, gym, league, plant
}

nonisolated struct JourneyNode: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Wild stages. `areas` are PokéAPI location-area names whose encounters make up the pool.
        case route(stages: Int, levels: ClosedRange<Int>, areas: [String], water: Bool)
        /// One trainer per stage: a gym has one, the League five.
        case trainers([Trainer])
        /// An optional boss that joins when beaten. `after` is the main node that reveals it.
        case legend(species: Int, level: Int, after: String)
    }

    let id: String
    let nameKo: String
    let nameEn: String
    let kind: Kind
    let point: MapPoint
    let scenery: Scenery

    var name: String { PokeLanguage.isKorean ? nameKo : nameEn }

    var stageCount: Int {
        switch kind {
        case .route(let stages, _, _, _): stages
        case .trainers(let trainers): trainers.count
        case .legend: 1
        }
    }

    var isRoute: Bool { if case .route = kind { true } else { false } }
    var trainers: [Trainer] { if case .trainers(let list) = kind { list } else { [] } }
    var isGym: Bool { trainers.count == 1 && trainers[0].badge != nil }

    var areas: [String] { if case .route(_, _, let areas, _) = kind { areas } else { [] } }
}

/// A town drawn on the map. Gyms sit on their town's point.
nonisolated struct MapTown: Equatable, Sendable {
    let nameKo: String
    let nameEn: String
    let point: MapPoint

    var name: String { PokeLanguage.isKorean ? nameKo : nameEn }
}

nonisolated enum Kanto {
    static let mapSize = (width: 54.0, height: 30.0)

    // MARK: Trainers

    private static func member(_ species: Int, _ level: Int) -> Trainer.Member { Trainer.Member(species: species, level: level) }

    static let brock = Trainer(id: "brock", nameKo: "웅", nameEn: "Brock", titleKo: "회색체육관 관장", titleEn: "Pewter Gym Leader",
                               sprite: "brock-gen3", specialty: .rock, team: [member(74, 12), member(95, 14)], badge: 1)
    static let misty = Trainer(id: "misty", nameKo: "이슬", nameEn: "Misty", titleKo: "블루체육관 관장", titleEn: "Cerulean Gym Leader",
                               sprite: "misty-gen3", specialty: .water, team: [member(120, 18), member(121, 21)], badge: 2)
    static let surge = Trainer(id: "surge", nameKo: "마티스", nameEn: "Lt. Surge", titleKo: "갈색체육관 관장", titleEn: "Vermilion Gym Leader",
                               sprite: "ltsurge-gen3", specialty: .electric,
                               team: [member(100, 21), member(25, 18), member(26, 24)], badge: 3)
    static let erika = Trainer(id: "erika", nameKo: "민화", nameEn: "Erika", titleKo: "무지개체육관 관장", titleEn: "Celadon Gym Leader",
                               sprite: "erika-gen3", specialty: .grass,
                               team: [member(114, 24), member(71, 29), member(45, 29)], badge: 4)
    static let koga = Trainer(id: "koga", nameKo: "독수", nameEn: "Koga", titleKo: "연분홍체육관 관장", titleEn: "Fuchsia Gym Leader",
                              sprite: "koga-gen3", specialty: .poison,
                              team: [member(109, 37), member(89, 39), member(109, 37), member(110, 43)], badge: 5)
    static let sabrina = Trainer(id: "sabrina", nameKo: "초련", nameEn: "Sabrina", titleKo: "노랑체육관 관장", titleEn: "Saffron Gym Leader",
                                 sprite: "sabrina-gen3", specialty: .psychic,
                                 team: [member(64, 38), member(122, 37), member(49, 38), member(65, 43)], badge: 6)
    static let blaine = Trainer(id: "blaine", nameKo: "강연", nameEn: "Blaine", titleKo: "홍련체육관 관장", titleEn: "Cinnabar Gym Leader",
                                sprite: "blaine-gen3", specialty: .fire,
                                team: [member(58, 42), member(77, 40), member(78, 42), member(59, 47)], badge: 7)
    static let giovanni = Trainer(id: "giovanni", nameKo: "비주기", nameEn: "Giovanni", titleKo: "상록체육관 관장", titleEn: "Viridian Gym Leader",
                                  sprite: "giovanni-gen3", specialty: .ground,
                                  team: [member(111, 45), member(51, 42), member(31, 44), member(34, 45), member(112, 50)], badge: 8)
    static let lorelei = Trainer(id: "lorelei", nameKo: "칸나", nameEn: "Lorelei", titleKo: "사천왕", titleEn: "Elite Four",
                                 sprite: "lorelei-gen3", specialty: .ice,
                                 team: [member(87, 52), member(91, 51), member(80, 52), member(124, 54), member(131, 54)], badge: nil)
    static let bruno = Trainer(id: "bruno", nameKo: "시바", nameEn: "Bruno", titleKo: "사천왕", titleEn: "Elite Four",
                               sprite: "bruno-gen3", specialty: .fighting,
                               team: [member(95, 51), member(107, 53), member(106, 53), member(95, 54), member(68, 56)], badge: nil)
    static let agatha = Trainer(id: "agatha", nameKo: "국화", nameEn: "Agatha", titleKo: "사천왕", titleEn: "Elite Four",
                                sprite: "agatha-gen3", specialty: .ghost,
                                team: [member(94, 54), member(42, 54), member(93, 53), member(24, 56), member(94, 58)], badge: nil)
    static let lance = Trainer(id: "lance", nameKo: "목호", nameEn: "Lance", titleKo: "사천왕", titleEn: "Elite Four",
                               sprite: "lance-gen3", specialty: .dragon,
                               team: [member(130, 56), member(148, 54), member(148, 54), member(142, 58), member(149, 60)], badge: nil)

    /// The rival's team follows the starter you didn't pick: he takes the one strong against yours.
    static func champion(starter: Int) -> Trainer {
        let tail: [Trainer.Member] = switch starter {
        case 1: [member(103, 59), member(130, 61), member(6, 63)]     // you took Bulbasaur, he has Charizard
        case 7: [member(130, 59), member(59, 61), member(3, 63)]      // you took Squirtle, he has Venusaur
        default: [member(59, 59), member(103, 61), member(9, 63)]     // you took Charmander, he has Blastoise
        }
        return Trainer(id: "blue", nameKo: "그린", nameEn: "Blue", titleKo: "챔피언", titleEn: "Champion", sprite: "blue-gen3",
                       specialty: nil, team: [member(18, 59), member(65, 57), member(112, 59)] + tail, badge: nil)
    }

    // MARK: Journey

    private static func route(_ id: String, _ ko: String, _ en: String, stages: Int, levels: ClosedRange<Int>, areas: [String],
                              water: Bool = false, at point: MapPoint, _ scenery: Scenery) -> JourneyNode {
        JourneyNode(id: id, nameKo: ko, nameEn: en, kind: .route(stages: stages, levels: levels, areas: areas, water: water),
                    point: point, scenery: scenery)
    }

    private static func gym(_ trainer: Trainer, _ ko: String, _ en: String, at point: MapPoint) -> JourneyNode {
        JourneyNode(id: "gym-\(trainer.id)", nameKo: ko, nameEn: en, kind: .trainers([trainer]), point: point, scenery: .gym)
    }

    private static func p(_ x: Double, _ y: Double) -> MapPoint { MapPoint(x: x, y: y) }

    /// The main path, in order. The League's champion depends on the starter.
    static func main(starter: Int) -> [JourneyNode] {
        [
            route("route-1", "1번도로", "Route 1", stages: 3, levels: 3...5, areas: ["kanto-route-1-area"], at: p(12, 20), .meadow),
            route("viridian-forest", "상록숲", "Viridian Forest", stages: 3, levels: 5...9,
                  areas: ["viridian-forest-area", "kanto-route-2-south-towards-viridian-city", "kanto-route-22-area"],
                  at: p(12, 12), .forest),
            gym(brock, "회색체육관", "Pewter Gym", at: p(12, 7)),
            route("route-3", "3번도로", "Route 3", stages: 3, levels: 10...13, areas: ["kanto-route-3-area"], at: p(18, 7), .meadow),
            route("mt-moon", "달맞이산", "Mt. Moon", stages: 3, levels: 11...15, areas: ["mt-moon-1f", "mt-moon-b1f", "mt-moon-b2f"],
                  at: p(24, 5), .cave),
            route("route-24", "24·25번도로", "Routes 24–25", stages: 3, levels: 14...18,
                  areas: ["kanto-route-4-area", "kanto-route-24-area", "kanto-route-25-area"], at: p(37, 2), .meadow),
            gym(misty, "블루체육관", "Cerulean Gym", at: p(34, 5)),
            route("route-5", "5·6번도로", "Routes 5–6", stages: 3, levels: 17...21, areas: ["kanto-route-5-area", "kanto-route-6-area"],
                  at: p(34, 9), .meadow),
            route("digletts-cave", "디그다굴", "Diglett's Cave", stages: 2, levels: 19...23,
                  areas: ["digletts-cave-area", "kanto-route-11-area"], at: p(42, 19), .cave),
            gym(surge, "갈색체육관", "Vermilion Gym", at: p(36, 19)),
            route("route-9", "9·10번도로", "Routes 9–10", stages: 2, levels: 21...24, areas: ["kanto-route-9-area", "kanto-route-10-area"],
                  at: p(41, 5), .meadow),
            route("rock-tunnel", "돌산터널", "Rock Tunnel", stages: 3, levels: 22...26, areas: ["rock-tunnel-1f", "rock-tunnel-b1f"],
                  at: p(46, 7), .cave),
            route("pokemon-tower", "포켓몬타워", "Pokémon Tower", stages: 3, levels: 23...27,
                  areas: ["pokemon-tower-3f", "pokemon-tower-4f", "pokemon-tower-5f", "pokemon-tower-6f", "pokemon-tower-7f"],
                  at: p(46, 13), .tower),
            route("route-8", "7·8번도로", "Routes 7–8", stages: 2, levels: 25...28, areas: ["kanto-route-7-area", "kanto-route-8-area"],
                  at: p(40, 13), .meadow),
            gym(erika, "무지개체육관", "Celadon Gym", at: p(22, 13)),
            route("route-12", "12~15번도로", "Routes 12–15", stages: 3, levels: 28...33,
                  areas: ["kanto-route-12-area", "kanto-route-13-area", "kanto-route-14-area", "kanto-route-15-area"],
                  at: p(46, 23), .meadow),
            route("cycling-road", "사이클링로드", "Cycling Road", stages: 3, levels: 30...36,
                  areas: ["kanto-route-16-area", "kanto-route-17-area", "kanto-route-18-area"], at: p(22, 20), .meadow),
            route("safari-zone", "사파리존", "Safari Zone", stages: 3, levels: 33...40,
                  areas: ["kanto-safari-zone-middle", "kanto-safari-zone-area-1-east", "kanto-safari-zone-area-2-north",
                          "kanto-safari-zone-area-3-west"], at: p(32, 21), .forest),
            gym(koga, "연분홍체육관", "Fuchsia Gym", at: p(32, 25)),
            gym(sabrina, "노랑체육관", "Saffron Gym", at: p(34, 13)),
            route("seafoam-islands", "쌍둥이섬", "Seafoam Islands", stages: 3, levels: 38...44,
                  areas: ["seafoam-islands-1f", "seafoam-islands-b1f", "seafoam-islands-b2f", "seafoam-islands-b3f",
                          "seafoam-islands-b4f", "kanto-sea-route-19-area", "kanto-sea-route-20-area"],
                  water: true, at: p(24, 28), .ice),
            route("pokemon-mansion", "포켓몬저택", "Pokémon Mansion", stages: 3, levels: 40...46,
                  areas: ["pokemon-mansion-1f", "pokemon-mansion-2f", "pokemon-mansion-3f", "pokemon-mansion-b1f"],
                  at: p(9, 28), .volcano),
            gym(blaine, "홍련체육관", "Cinnabar Gym", at: p(13, 28)),
            route("route-21", "21번수로", "Sea Route 21", stages: 2, levels: 44...48,
                  areas: ["kanto-sea-route-21-area", "pallet-town-area", "cinnabar-island-area"], water: true, at: p(12, 25.5), .sea),
            gym(giovanni, "상록체육관", "Viridian Gym", at: p(12, 17)),
            route("victory-road", "챔피언로드", "Victory Road", stages: 3, levels: 48...54,
                  areas: ["kanto-route-23-area", "kanto-victory-road-2-1f", "kanto-victory-road-2-2f", "kanto-victory-road-2-3f"],
                  at: p(4, 11), .cave),
            JourneyNode(id: "pokemon-league", nameKo: "포켓몬리그", nameEn: "Pokémon League",
                        kind: .trainers([lorelei, bruno, agatha, lance, champion(starter: starter)]), point: p(4, 4), scenery: .league),
            route("cerulean-cave", "미지의동굴", "Cerulean Cave", stages: 3, levels: 55...65,
                  areas: ["cerulean-cave-1f", "cerulean-cave-2f", "cerulean-cave-b1f"], at: p(30, 2), .cave),
        ]
    }

    /// Optional bosses, revealed once the party reaches `after`.
    static let legends: [JourneyNode] = [
        JourneyNode(id: "snorlax", nameKo: "잠자는 잠만보", nameEn: "Sleeping Snorlax", kind: .legend(species: 143, level: 30, after: "route-12"),
                    point: p(47.5, 18), scenery: .meadow),
        JourneyNode(id: "zapdos", nameKo: "무인발전소", nameEn: "Power Plant", kind: .legend(species: 145, level: 50, after: "gym-koga"),
                    point: p(51, 10), scenery: .plant),
        JourneyNode(id: "articuno", nameKo: "쌍둥이섬 깊은 곳", nameEn: "Seafoam Depths", kind: .legend(species: 144, level: 50, after: "seafoam-islands"),
                    point: p(26.5, 28.5), scenery: .ice),
        JourneyNode(id: "moltres", nameKo: "챔피언로드 깊은 곳", nameEn: "Victory Road Depths", kind: .legend(species: 146, level: 50, after: "victory-road"),
                    point: p(2, 8.5), scenery: .volcano),
        JourneyNode(id: "mewtwo", nameKo: "미지의동굴 깊은 곳", nameEn: "Cerulean Cave Depths", kind: .legend(species: 150, level: 70, after: "cerulean-cave"),
                    point: p(27.5, 1.5), scenery: .cave),
    ]

    static let towns: [MapTown] = [
        MapTown(nameKo: "태초마을", nameEn: "Pallet Town", point: p(12, 23)),
        MapTown(nameKo: "상록시티", nameEn: "Viridian City", point: p(12, 17)),
        MapTown(nameKo: "회색시티", nameEn: "Pewter City", point: p(12, 7)),
        MapTown(nameKo: "블루시티", nameEn: "Cerulean City", point: p(34, 5)),
        MapTown(nameKo: "갈색시티", nameEn: "Vermilion City", point: p(36, 19)),
        MapTown(nameKo: "보라타운", nameEn: "Lavender Town", point: p(46, 13)),
        MapTown(nameKo: "무지개시티", nameEn: "Celadon City", point: p(22, 13)),
        MapTown(nameKo: "노랑시티", nameEn: "Saffron City", point: p(34, 13)),
        MapTown(nameKo: "연분홍시티", nameEn: "Fuchsia City", point: p(32, 25)),
        MapTown(nameKo: "홍련섬", nameEn: "Cinnabar Island", point: p(13, 28)),
        MapTown(nameKo: "석영고원", nameEn: "Indigo Plateau", point: p(4, 4)),
    ]

    /// Roads drawn on the map, as polylines between points.
    static let roads: [[MapPoint]] = [
        [p(12, 23), p(12, 17), p(12, 7)],                   // Route 1, Viridian Forest
        [p(12, 17), p(6, 17), p(4, 11), p(4, 4)],           // Routes 22–23, Victory Road
        [p(12, 7), p(24, 5), p(34, 5)],                     // Route 3, Mt. Moon, Route 4
        [p(34, 5), p(37, 2)],                               // Nugget Bridge
        [p(34, 5), p(30, 2)],                               // Cerulean Cave
        [p(34, 5), p(41, 5), p(46, 7), p(46, 13)],          // Routes 9–10, Rock Tunnel
        [p(46, 7), p(51, 10)],                              // Power Plant
        [p(34, 5), p(34, 13), p(36, 19)],                   // Routes 5–6
        [p(36, 19), p(42, 19)],                             // Route 11
        [p(22, 13), p(34, 13), p(46, 13)],                  // Routes 7–8
        [p(46, 13), p(47.5, 18), p(46, 23), p(32, 25)],     // Routes 12–15
        [p(22, 13), p(22, 20), p(32, 25)],                  // Cycling Road, Route 18
        [p(32, 25), p(32, 21)],                             // Safari Zone
        [p(32, 25), p(24, 28), p(13, 28)],                  // Sea Routes 19–20
        [p(13, 28), p(12, 23)],                             // Sea Route 21
    ]

    // MARK: Rules tied to the journey

    /// The highest level a Pokémon reaches with this many badges; experience past it is banked.
    static func levelCap(badges: Int, champion: Bool) -> Int {
        if champion { return PokeMath.maxLevel }
        let caps = [16, 23, 27, 32, 45, 47, 50, 54, 65]
        return caps[min(max(0, badges), caps.count - 1)]
    }

    /// Pokémon that never turn up in the wild, only in the gacha, from the node where the games
    /// give them away.
    static let gachaOnly: [(species: Int, after: String)] = [
        (1, "route-1"), (4, "route-1"), (7, "route-1"),
        (122, "viridian-forest"),                            // Mr. Mime, traded on Route 2
        (138, "mt-moon"), (140, "mt-moon"), (142, "mt-moon"),  // fossils
        (124, "gym-misty"),                                  // Jynx, traded in Cerulean
        (83, "route-5"),                                     // Farfetch'd, traded in Vermilion
        (133, "gym-erika"), (137, "gym-erika"),              // Eevee and Porygon, Celadon
        (108, "cycling-road"),                               // Lickitung, traded on Route 18
        (106, "gym-sabrina"), (107, "gym-sabrina"), (131, "gym-sabrina"),  // Fighting Dojo, Silph Co.
    ]

    /// Mew only shows up in the gacha once you're the champion.
    static let mew = 151

    static func badgeName(_ badge: Int) -> String {
        let names: [(ko: String, en: String)] = [
            ("회색배지", "Boulder Badge"), ("블루배지", "Cascade Badge"), ("오렌지배지", "Thunder Badge"),
            ("무지개배지", "Rainbow Badge"), ("핑크배지", "Soul Badge"), ("골드배지", "Marsh Badge"),
            ("진홍배지", "Volcano Badge"), ("그린배지", "Earth Badge"),
        ]
        guard (1...names.count).contains(badge) else { return "" }
        return PokeLanguage.isKorean ? names[badge - 1].ko : names[badge - 1].en
    }
}

// MARK: Wild encounters

/// FireRed/LeafGreen wild encounter slots for the areas the journey uses.
nonisolated struct EncounterDex: Codable, Sendable {
    struct Slot: Codable, Equatable, Sendable {
        let species: Int
        /// Percent chance of this slot within its method.
        let rarity: Int
        /// PokéAPI encounter method: 1 walk, 2–4 rods, 5 surf, 6 rock smash.
        let method: Int
    }

    let areas: [String: [Slot]]

    /// Species on a stretch of the journey and how common each is, in percent of the pool.
    /// Fishing and surfing count for less on land, since most battles there happen in the grass.
    func pool(for node: JourneyNode, dex: DexView) -> [(species: Int, share: Double)] {
        guard case .route(_, let levels, let areas, let water) = node.kind else { return [] }
        var weights: [Int: Double] = [:]
        for area in areas {
            for slot in self.areas[area] ?? [] {
                guard let species = dex[slot.species], !species.isSpecial else { continue }
                // Evolved forms from rods or rare slots shouldn't outpace the stretch.
                if let evolveLevel = species.evolveLevel, evolveLevel > levels.upperBound + 2 { continue }
                let onLand = slot.method == 1 || slot.method == 6
                weights[slot.species, default: 0] += Double(slot.rarity) * (water || onLand ? 1 : 0.35)
            }
        }
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return [] }
        return weights.map { (species: $0.key, share: $0.value / total * 100) }.sorted { $0.share > $1.share }
    }
}

nonisolated extension PokeAPI {
    static func fetchEncounters(areas: [String]) async throws -> EncounterDex {
        let names = areas.map { "\"\($0)\"" }.joined(separator: ", ")
        let versions = "version_id: {_in: [10, 11]}, pokemon_id: {_lte: \(PokeDexStore.maxID)}"
        let query = """
        query { areas: pokemon_v2_locationarea(where: {name: {_in: [\(names)]}}) { name \
        enc: pokemon_v2_encounters(where: {\(versions)}) { p: pokemon_id \
        slot: pokemon_v2_encounterslot { r: rarity m: encounter_method_id } } } }
        """
        let data = try await post(query)
        let decoded = try JSONDecoder().decode(EncounterResponse.self, from: data)
        guard let rows = decoded.data?.areas, !rows.isEmpty else { throw URLError(.cannotParseResponse) }
        var result: [String: [EncounterDex.Slot]] = [:]
        for row in rows {
            result[row.name] = row.enc.compactMap { encounter in
                guard let slot = encounter.slot, let rarity = slot.r, let method = slot.m, (1...6).contains(method) else { return nil }
                return EncounterDex.Slot(species: encounter.p, rarity: rarity, method: method)
            }
        }
        return EncounterDex(areas: result)
    }

    private struct EncounterResponse: Decodable {
        var data: Payload?
        struct Payload: Decodable { var areas: [Area] }
        struct Area: Decodable {
            var name: String
            var enc: [Encounter]
        }
        struct Encounter: Decodable {
            var p: Int
            var slot: Slot?
        }
        struct Slot: Decodable { var r: Int?; var m: Int? }
    }
}
