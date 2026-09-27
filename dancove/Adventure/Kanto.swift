import Foundation

// The journey through Kanto: chapters of ten stations ending at a gym or the League, the
// legendaries, and which real FireRed/LeafGreen encounter areas stock each stretch. Trainer teams are
// written here because PokéAPI has none; wild encounter tables are downloaded at runtime.

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

/// The look of a stage's backdrop.
nonisolated enum Scenery: Int, Sendable {
    case meadow, forest, cave, sea, volcano, ice, tower, gym, league, plant
}

/// FireRed/LeafGreen areas that stock a run of stations: their wild Pokémon and their look.
nonisolated struct Stretch: Equatable, Sendable {
    let id: String
    /// For the simulation and debugging; place names aren't shown in the app.
    let nameEn: String
    /// PokéAPI location-area names whose encounters make up the pool.
    let areas: [String]
    /// Fishing and surfing count in full here, not just walking.
    let water: Bool
    let scenery: Scenery
    /// Evolved forms that only appear well past this level stay out of the pool.
    let topLevel: Int
}

/// One stop on a chapter's line.
nonisolated struct Station: Equatable, Sendable {
    let stretch: Stretch
    let level: Int
}

/// A legendary on a branch off its chapter's line. It joins when beaten.
nonisolated struct LegendSpot: Identifiable, Equatable, Sendable {
    let id: String
    let species: Int
    let level: Int
    let scenery: Scenery
}

/// Ten stations in a row, then the chapter's boss: a gym leader, or the League's five.
nonisolated struct Chapter: Identifiable, Equatable, Sendable {
    static let stationCount = 10

    /// 1-based, as shown ("1장").
    let number: Int
    let stations: [Station]
    /// Empty for the chapter after the League, which loops.
    let bosses: [Trainer]
    let legend: LegendSpot?

    var id: Int { number }
    var isLeague: Bool { bosses.count > 1 }
    var badge: Int? { bosses.count == 1 ? bosses[0].badge : nil }
    var bossScenery: Scenery { isLeague ? .league : .gym }
}

nonisolated enum Kanto {
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

    private static func stretch(_ id: String, _ name: String, _ areas: [String], water: Bool = false, _ scenery: Scenery,
                                top: Int) -> Stretch {
        Stretch(id: id, nameEn: name, areas: areas, water: water, scenery: scenery, topLevel: top)
    }

    static let route1 = stretch("route-1", "Route 1", ["kanto-route-1-area"], .meadow, top: 5)
    static let viridianForest = stretch("viridian-forest", "Viridian Forest",
                                        ["viridian-forest-area", "kanto-route-2-south-towards-viridian-city", "kanto-route-22-area"],
                                        .forest, top: 9)
    static let route3 = stretch("route-3", "Route 3", ["kanto-route-3-area"], .meadow, top: 13)
    static let mtMoon = stretch("mt-moon", "Mt. Moon", ["mt-moon-1f", "mt-moon-b1f", "mt-moon-b2f"], .cave, top: 15)
    static let route24 = stretch("route-24", "Routes 4, 24–25", ["kanto-route-4-area", "kanto-route-24-area", "kanto-route-25-area"],
                                 .meadow, top: 18)
    static let route5 = stretch("route-5", "Routes 5–6", ["kanto-route-5-area", "kanto-route-6-area"], .meadow, top: 21)
    static let diglettsCave = stretch("digletts-cave", "Diglett's Cave", ["digletts-cave-area", "kanto-route-11-area"], .cave, top: 23)
    static let route9 = stretch("route-9", "Routes 9–10", ["kanto-route-9-area", "kanto-route-10-area"], .meadow, top: 24)
    static let rockTunnel = stretch("rock-tunnel", "Rock Tunnel", ["rock-tunnel-1f", "rock-tunnel-b1f"], .cave, top: 26)
    static let pokemonTower = stretch("pokemon-tower", "Pokémon Tower",
                                      ["pokemon-tower-3f", "pokemon-tower-4f", "pokemon-tower-5f", "pokemon-tower-6f", "pokemon-tower-7f"],
                                      .tower, top: 27)
    static let route8 = stretch("route-8", "Routes 7–8", ["kanto-route-7-area", "kanto-route-8-area"], .meadow, top: 28)
    static let route12 = stretch("route-12", "Routes 12–15",
                                 ["kanto-route-12-area", "kanto-route-13-area", "kanto-route-14-area", "kanto-route-15-area"],
                                 .meadow, top: 33)
    static let cyclingRoad = stretch("cycling-road", "Cycling Road", ["kanto-route-16-area", "kanto-route-17-area", "kanto-route-18-area"],
                                     .meadow, top: 36)
    static let safariZone = stretch("safari-zone", "Safari Zone",
                                    ["kanto-safari-zone-middle", "kanto-safari-zone-area-1-east", "kanto-safari-zone-area-2-north",
                                     "kanto-safari-zone-area-3-west"], .forest, top: 40)
    static let seafoam = stretch("seafoam-islands", "Seafoam Islands",
                                 ["seafoam-islands-1f", "seafoam-islands-b1f", "seafoam-islands-b2f", "seafoam-islands-b3f",
                                  "seafoam-islands-b4f", "kanto-sea-route-19-area", "kanto-sea-route-20-area"], water: true, .ice, top: 44)
    static let mansion = stretch("pokemon-mansion", "Pokémon Mansion",
                                 ["pokemon-mansion-1f", "pokemon-mansion-2f", "pokemon-mansion-3f", "pokemon-mansion-b1f"], .volcano, top: 46)
    static let route21 = stretch("route-21", "Sea Route 21", ["kanto-sea-route-21-area", "pallet-town-area", "cinnabar-island-area"],
                                 water: true, .sea, top: 48)
    static let route23 = stretch("route-23", "Route 23", ["kanto-route-23-area"], .meadow, top: 50)
    static let victoryRoad = stretch("victory-road", "Victory Road",
                                     ["kanto-victory-road-2-1f", "kanto-victory-road-2-2f", "kanto-victory-road-2-3f"], .cave, top: 54)
    static let ceruleanCave = stretch("cerulean-cave", "Cerulean Cave", ["cerulean-cave-1f", "cerulean-cave-2f", "cerulean-cave-b1f"],
                                      .cave, top: 65)

    static let stretches = [route1, viridianForest, route3, mtMoon, route24, route5, diglettsCave, route9, rockTunnel, pokemonTower,
                            route8, route12, cyclingRoad, safariZone, seafoam, mansion, route21, route23, victoryRoad, ceruleanCave]

    static let snorlax = LegendSpot(id: "snorlax", species: 143, level: 30, scenery: .meadow)
    static let zapdos = LegendSpot(id: "zapdos", species: 145, level: 50, scenery: .plant)
    static let articuno = LegendSpot(id: "articuno", species: 144, level: 50, scenery: .ice)
    static let moltres = LegendSpot(id: "moltres", species: 146, level: 50, scenery: .volcano)
    static let mewtwo = LegendSpot(id: "mewtwo", species: 150, level: 70, scenery: .cave)
    static let legends = [snorlax, zapdos, articuno, moltres, mewtwo]

    /// Ten stations from the stretches in order, their levels rising evenly across `levels`.
    private static func chapter(_ number: Int, _ levels: ClosedRange<Int>, _ parts: [(Stretch, Int)], bosses: [Trainer],
                                legend: LegendSpot? = nil) -> Chapter {
        let stretches = parts.flatMap { Array(repeating: $0.0, count: $0.1) }
        precondition(stretches.count == Chapter.stationCount)
        let stations = stretches.enumerated().map { index, stretch in
            let t = Double(index) / Double(stretches.count - 1)
            return Station(stretch: stretch, level: levels.lowerBound + Int((Double(levels.upperBound - levels.lowerBound) * t).rounded()))
        }
        return Chapter(number: number, stations: stations, bosses: bosses, legend: legend)
    }

    /// The journey, in FRLG order. The champion depends on the starter.
    static func chapters(starter: Int) -> [Chapter] {
        [
            chapter(1, 3...9, [(route1, 4), (viridianForest, 6)], bosses: [brock]),
            chapter(2, 10...18, [(route3, 3), (mtMoon, 4), (route24, 3)], bosses: [misty]),
            chapter(3, 17...23, [(route5, 5), (diglettsCave, 5)], bosses: [surge]),
            chapter(4, 21...28, [(route9, 2), (rockTunnel, 3), (pokemonTower, 3), (route8, 2)], bosses: [erika]),
            chapter(5, 28...36, [(route12, 5), (cyclingRoad, 5)], bosses: [koga], legend: snorlax),
            chapter(6, 33...40, [(safariZone, 10)], bosses: [sabrina], legend: zapdos),
            chapter(7, 38...46, [(seafoam, 5), (mansion, 5)], bosses: [blaine], legend: articuno),
            chapter(8, 44...50, [(route21, 5), (route23, 5)], bosses: [giovanni]),
            chapter(9, 48...54, [(victoryRoad, 10)], bosses: [lorelei, bruno, agatha, lance, champion(starter: starter)], legend: moltres),
            chapter(10, 55...65, [(ceruleanCave, 10)], bosses: [], legend: mewtwo),
        ]
    }

    // MARK: Rules tied to the journey

    /// The highest level a Pokémon reaches with this many badges; experience past it is banked.
    static func levelCap(badges: Int, champion: Bool) -> Int {
        if champion { return PokeMath.maxLevel }
        let caps = [16, 23, 27, 32, 45, 47, 50, 54, 65]
        return caps[min(max(0, badges), caps.count - 1)]
    }

    /// Pokémon that never turn up in the wild, only in the gacha, from the chapter (0-based) where
    /// the games give them away.
    static let gachaOnly: [(species: Int, chapter: Int)] = [
        (1, 0), (4, 0), (7, 0),
        (122, 0),                   // Mr. Mime, traded on Route 2
        (138, 1), (140, 1), (142, 1),  // fossils, Mt. Moon
        (124, 2),                   // Jynx, traded in Cerulean
        (83, 2),                    // Farfetch'd, traded in Vermilion
        (133, 4), (137, 4),         // Eevee and Porygon, Celadon
        (108, 4),                   // Lickitung, traded on Route 18
        (106, 6), (107, 6), (131, 6),  // Fighting Dojo, Silph Co.
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
    func pool(for stretch: Stretch, dex: DexView) -> [(species: Int, share: Double)] {
        var weights: [Int: Double] = [:]
        let water = stretch.water
        for area in stretch.areas {
            for slot in self.areas[area] ?? [] {
                guard let species = dex[slot.species], !species.isSpecial else { continue }
                // Evolved forms from rods or rare slots shouldn't outpace the stretch.
                if let evolveLevel = species.evolveLevel, evolveLevel > stretch.topLevel + 2 { continue }
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
