import Foundation

// The journey through Johto, after Kanto's Champion: HeartGold/SoulSilver's gyms, League and areas in
// the same thirty chapters of ten stations, and Red on Mt. Silver after the Champion. Trainer teams
// are written here (PokéAPI has none); wild encounters are downloaded at runtime, like Kanto's.

nonisolated enum Johto {
    // MARK: Trainers

    private static func member(_ species: Int, _ level: Int) -> Trainer.Member { Trainer.Member(species: species, level: level) }

    static let falkner = Trainer(id: "falkner", nameKo: "비상", nameEn: "Falkner", titleKo: "도라지체육관 관장", titleEn: "Violet Gym Leader",
                                 sprite: "falkner", specialty: .flying, team: [member(16, 9), member(17, 13)], badge: 1)
    static let bugsy = Trainer(id: "bugsy", nameKo: "호일", nameEn: "Bugsy", titleKo: "고동체육관 관장", titleEn: "Azalea Gym Leader",
                               sprite: "bugsy", specialty: .bug, team: [member(11, 15), member(14, 15), member(123, 17)], badge: 2)
    static let whitney = Trainer(id: "whitney", nameKo: "꼭두", nameEn: "Whitney", titleKo: "금빛체육관 관장", titleEn: "Goldenrod Gym Leader",
                                 sprite: "whitney", specialty: .normal, team: [member(35, 17), member(241, 19)], badge: 3)
    static let morty = Trainer(id: "morty", nameKo: "유빈", nameEn: "Morty", titleKo: "인주체육관 관장", titleEn: "Ecruteak Gym Leader",
                               sprite: "morty", specialty: .ghost,
                               team: [member(92, 21), member(93, 21), member(93, 23), member(94, 25)], badge: 4)
    static let chuck = Trainer(id: "chuck", nameKo: "사도", nameEn: "Chuck", titleKo: "진청체육관 관장", titleEn: "Cianwood Gym Leader",
                               sprite: "chuck", specialty: .fighting, team: [member(57, 29), member(62, 31)], badge: 5)
    static let jasmine = Trainer(id: "jasmine", nameKo: "규리", nameEn: "Jasmine", titleKo: "담청체육관 관장", titleEn: "Olivine Gym Leader",
                                 sprite: "jasmine", specialty: .steel, team: [member(81, 30), member(81, 30), member(208, 35)], badge: 6)
    static let pryce = Trainer(id: "pryce", nameKo: "류옹", nameEn: "Pryce", titleKo: "황토체육관 관장", titleEn: "Mahogany Gym Leader",
                               sprite: "pryce", specialty: .ice, team: [member(86, 30), member(87, 32), member(221, 34)], badge: 7)
    static let clair = Trainer(id: "clair", nameKo: "이향", nameEn: "Clair", titleKo: "검은먹체육관 관장", titleEn: "Blackthorn Gym Leader",
                               sprite: "clair", specialty: .dragon,
                               team: [member(130, 38), member(148, 38), member(148, 38), member(230, 41)], badge: 8)
    static let will = Trainer(id: "will", nameKo: "일목", nameEn: "Will", titleKo: "사천왕", titleEn: "Elite Four",
                              sprite: "will", specialty: .psychic,
                              team: [member(178, 40), member(124, 41), member(103, 41), member(80, 41), member(178, 42)], badge: nil)
    static let koga = Trainer(id: "koga-johto", nameKo: "독수", nameEn: "Koga", titleKo: "사천왕", titleEn: "Elite Four",
                              sprite: "koga", specialty: .poison,
                              team: [member(168, 40), member(49, 41), member(205, 43), member(89, 42), member(169, 44)], badge: nil)
    static let bruno = Trainer(id: "bruno-johto", nameKo: "시바", nameEn: "Bruno", titleKo: "사천왕", titleEn: "Elite Four",
                               sprite: "bruno", specialty: .fighting,
                               team: [member(237, 42), member(106, 42), member(107, 42), member(95, 43), member(68, 46)], badge: nil)
    static let karen = Trainer(id: "karen", nameKo: "카렌", nameEn: "Karen", titleKo: "사천왕", titleEn: "Elite Four",
                               sprite: "karen", specialty: .dark,
                               team: [member(197, 42), member(45, 42), member(94, 45), member(198, 44), member(229, 47)], badge: nil)
    static let lance = Trainer(id: "lance-champion", nameKo: "목호", nameEn: "Lance", titleKo: "챔피언", titleEn: "Champion",
                               sprite: "lance", specialty: .dragon,
                               team: [member(130, 46), member(149, 47), member(142, 46), member(6, 46), member(149, 47), member(149, 50)],
                               badge: nil)
    /// On top of Mt. Silver after the Champion, his Pikachu last.
    static let red = Trainer(id: "red", nameKo: "레드", nameEn: "Red", titleKo: "포켓몬 트레이너", titleEn: "Pokémon Trainer",
                             sprite: "red", specialty: nil,
                             team: [member(196, 84), member(143, 82), member(3, 84), member(6, 84), member(9, 84), member(25, 88)],
                             badge: nil)

    // MARK: Journey

    private static func stretch(_ id: String, _ name: String, _ areas: [String], water: Bool = false, _ scenery: Scenery,
                                top: Int) -> Stretch {
        Stretch(id: id, nameEn: name, areas: areas, water: water, scenery: scenery, topLevel: top)
    }

    static let route29 = stretch("johto-route-29", "Route 29", ["johto-route-29-area", "new-bark-town-area"], .meadow, top: 5)
    static let route30 = stretch("johto-route-30", "Routes 30–31",
                                 ["johto-route-30-area", "johto-route-31-area", "cherrygrove-city-area"], .meadow, top: 7)
    static let sproutTower = stretch("sprout-tower", "Sprout Tower", ["sprout-tower-2f", "sprout-tower-3f"], .tower, top: 9)
    static let darkCave = stretch("dark-cave", "Dark Cave", ["dark-cave-violet-city-entrance", "violet-city-area"], .cave, top: 10)
    static let route32 = stretch("johto-route-32", "Route 32", ["johto-route-32-area", "ruins-of-alph-outside"], .meadow, top: 12)
    static let unionCave = stretch("union-cave", "Union Cave", ["union-cave-1f", "union-cave-b1f"], .cave, top: 14)
    static let slowpokeWell = stretch("slowpoke-well", "Route 33, Slowpoke Well",
                                      ["johto-route-33-area", "slowpoke-well-1f", "slowpoke-well-b1f"], .cave, top: 15)
    static let ilexForest = stretch("ilex-forest", "Ilex Forest", ["ilex-forest-area"], .forest, top: 16)
    static let route34 = stretch("johto-route-34", "Route 34", ["johto-route-34-area"], .meadow, top: 18)
    static let nationalPark = stretch("national-park", "Route 35, National Park", ["johto-route-35-area", "national-park-area"],
                                      .forest, top: 20)
    static let route36 = stretch("johto-route-36", "Routes 36–37", ["johto-route-36-area", "johto-route-37-area", "ecruteak-city-area"],
                                 .meadow, top: 21)
    static let burnedTower = stretch("burned-tower", "Burned Tower", ["burned-tower-1f", "burned-tower-b1f"], .volcano, top: 23)
    static let route38 = stretch("johto-route-38", "Routes 38–39", ["johto-route-38-area", "johto-route-39-area"], .meadow, top: 26)
    static let route40 = stretch("johto-route-40", "Sea Routes 40–41",
                                 ["johto-sea-route-40-area", "johto-sea-route-41-area", "olivine-city-area"], water: true, .sea, top: 29)
    static let whirlIslands = stretch("whirl-islands", "Cianwood, Whirl Islands",
                                      ["cianwood-city-area", "whirl-islands-1f", "whirl-islands-b1f"], water: true, .cave, top: 30)
    static let route42 = stretch("johto-route-42", "Route 42", ["johto-route-42-area"], .meadow, top: 30)
    static let mtMortar = stretch("mt-mortar", "Mt. Mortar",
                                  ["mt-mortar-1f", "mt-mortar-lower-cave", "mt-mortar-upper-cave", "mt-mortar-b1f"], .cave, top: 34)
    static let lakeOfRage = stretch("lake-of-rage", "Route 43, Lake of Rage", ["johto-route-43-area", "lake-of-rage-area"], .sea, top: 33)
    static let route44 = stretch("johto-route-44", "Route 44", ["johto-route-44-area"], .meadow, top: 34)
    static let icePath = stretch("ice-path", "Ice Path", ["ice-path-1f", "ice-path-b1f", "ice-path-b2f", "ice-path-b3f"], .ice, top: 35)
    static let route45 = stretch("johto-route-45", "Routes 45–46, Dragon's Den",
                                 ["johto-route-45-area", "johto-route-46-area", "dragons-den-area", "blackthorn-city-area"],
                                 .cave, top: 40)
    static let route26 = stretch("kanto-route-26", "Routes 26–27, Tohjo Falls",
                                 ["kanto-route-26-area", "kanto-route-27-area", "tohjo-falls-area"], .meadow, top: 45)
    static let victoryRoad = stretch("johto-victory-road", "Victory Road",
                                     ["kanto-victory-road-1-1f", "kanto-victory-road-1-2f", "kanto-victory-road-1-3f"], .cave, top: 50)
    static let mtSilver = stretch("mt-silver", "Mt. Silver",
                                  ["mt-silver-outside", "mt-silver-mountainside", "mt-silver-1f", "mt-silver-1f-top", "mt-silver-2f",
                                   "mt-silver-3f", "mt-silver-4f", "mt-silver-top"], .ice, top: 70)

    static let stretches = [route29, route30, sproutTower, darkCave, route32, unionCave, slowpokeWell, ilexForest, route34,
                            nationalPark, route36, burnedTower, route38, route40, whirlIslands, route42, mtMortar, lakeOfRage,
                            route44, icePath, route45, route26, victoryRoad, mtSilver]

    static let sudowoodo = LegendSpot(id: "sudowoodo", species: 185, level: 20, scenery: .meadow)
    static let raikou = LegendSpot(id: "raikou", species: 243, level: 40, scenery: .plant)
    static let entei = LegendSpot(id: "entei", species: 244, level: 40, scenery: .volcano)
    static let redGyarados = LegendSpot(id: "red-gyarados", species: 130, level: 30, scenery: .sea, shiny: true)
    static let suicune = LegendSpot(id: "suicune", species: 245, level: 40, scenery: .ice)
    static let lugia = LegendSpot(id: "lugia", species: 249, level: 45, scenery: .sea)
    static let hoOh = LegendSpot(id: "ho-oh", species: 250, level: 70, scenery: .tower)
    static let legends = [sudowoodo, raikou, entei, redGyarados, suicune, lugia, hoOh]

    /// The journey, in HGSS order: thirty chapters, a gym at the end of every third, and Mt. Silver
    /// after the League with Red at its top.
    static func chapters() -> [Chapter] {
        Chapter.journey([
            Chapter.leg(3...10, [(route29, 3), (route30, 3), (sproutTower, 2), (darkCave, 2)], [falkner]),
            Chapter.leg(9...15, [(route32, 3), (unionCave, 4), (slowpokeWell, 3)], [bugsy]),
            Chapter.leg(13...18, [(ilexForest, 5), (route34, 5)], [whitney]),
            Chapter.leg(17...23, [(nationalPark, 4), (route36, 3), (burnedTower, 3)], [morty], sudowoodo),
            Chapter.leg(21...29, [(route38, 4), (route40, 3), (whirlIslands, 3)], [chuck], raikou),
            Chapter.leg(27...33, [(route42, 4), (mtMortar, 6)], [jasmine], entei),
            Chapter.leg(29...33, [(lakeOfRage, 5), (route44, 5)], [pryce], redGyarados),
            Chapter.leg(32...39, [(icePath, 4), (route45, 6)], [clair], suicune),
            Chapter.leg(38...48, [(route26, 5), (victoryRoad, 5)], [will, koga, bruno, karen, lance], lugia),
            Chapter.leg(50...70, [(mtSilver, 10)], [red], hoOh),
        ])
    }

    // MARK: Rules tied to the journey

    /// A few over the next boss's ace, like Kanto's; Pryce's ace is under Jasmine's.
    static let levelCaps = [15, 20, 23, 28, 34, 38, 38, 44, 53]

    /// Celebi only shows up in Johto's gacha once you're its Champion.
    static let celebi = 251

    static let badgeNames: [(ko: String, en: String)] = [
        ("윙배지", "Zephyr Badge"), ("인섹트배지", "Hive Badge"), ("레귤러배지", "Plain Badge"), ("팬텀배지", "Fog Badge"),
        ("쇼크배지", "Storm Badge"), ("스틸배지", "Mineral Badge"), ("아이스배지", "Glacier Badge"), ("라이징배지", "Rising Badge"),
    ]
}
