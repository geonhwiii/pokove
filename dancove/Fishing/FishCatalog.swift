import Foundation

/// How hard a fish is to catch. Colors follow the familiar loot ladder, ending in a prismatic mythic.
nonisolated enum FishRarity: Int, Codable, CaseIterable, Comparable, Identifiable, Sendable {
    case normal, magic, rare, unique, legendary, mythic

    var id: Int { rawValue }

    static func < (lhs: FishRarity, rhs: FishRarity) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .normal: String(localized: "Normal")
        case .magic: String(localized: "Magic")
        case .rare: String(localized: "Rare")
        case .unique: String(localized: "Unique")
        case .legendary: String(localized: "Legendary")
        case .mythic: String(localized: "Mythic")
        }
    }

    /// 0xRRGGBB.
    var hex: UInt32 {
        switch self {
        case .normal: 0xC9CED6
        case .magic: 0x5B8DFF
        case .rare: 0xFFD23F
        case .unique: 0xB46CFF
        case .legendary: 0xFF8A2B
        case .mythic: 0xFF4D7A
        }
    }

    /// Out of 100 before luck is applied.
    var baseWeight: Double {
        switch self {
        case .normal: 55
        case .magic: 25
        case .rare: 12
        case .unique: 5.5
        case .legendary: 2
        case .mythic: 0.5
        }
    }
}

nonisolated struct FishSpecies: Identifiable, Sendable {
    let id: String
    let name: String
    let rarity: FishRarity
    /// Centimeters.
    let sizeRange: ClosedRange<Double>
    let blurb: String
    let sprite: PixelSprite
}

/// Every creature in the fishing collection, in collection order.
nonisolated enum FishCatalog {
    static func species(id: String) -> FishSpecies? { byID[id] }

    static func species(of rarity: FishRarity) -> [FishSpecies] { all.filter { $0.rarity == rarity } }

    private static let byID: [String: FishSpecies] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let all: [FishSpecies] = normal + magic + rare + unique + legendary + mythic

    // MARK: Normal

    private static let normal: [FishSpecies] = [
        FishSpecies(
            id: "crucian", name: String(localized: "Crucian Carp"), rarity: .normal, sizeRange: 12...38,
            blurb: String(localized: "Found in every stream. Honest, like a first commit."),
            sprite: PixelSprite(rows: [
                "......fff.............",
                ".....fffff............",
                "....#######.......ff..",
                "..###########....fff..",
                ".#############..ffff..",
                "#ep############fffff..",
                "####g###########fff...",
                "#####g##########fff...",
                ".###g##########.ffff..",
                "..############...fff..",
                "....#f####f#......ff..",
                ".....f....ff..........",
            ], palette: ["M": 0x9C8C3E, "B": 0x5F5B2A, "L": 0xE2D086, "f": 0x87713A])
        ),
        FishSpecies(
            id: "anchovy", name: String(localized: "Anchovy"), rarity: .normal, sizeRange: 4...15,
            blurb: String(localized: "Tiny, but a whole school of them could refactor a codebase."),
            sprite: PixelSprite(rows: [
                "........ff..........",
                "..###########....ff.",
                ".ep###########..fff.",
                "#aaaaaaaaaaaaaa#ff..",
                ".#############..fff.",
                "..###########....ff.",
                "......f...f.........",
            ], palette: ["M": 0x8FB3C6, "B": 0x3E6A8A, "L": 0xE6F0F4, "f": 0x7FA3B8, "a": 0xE2EEF6])
        ),
        FishSpecies(
            id: "mackerel", name: String(localized: "Mackerel"), rarity: .normal, sizeRange: 20...50,
            blurb: String(localized: "Tastes best grilled at midnight after a deploy."),
            sprite: PixelSprite(rows: [
                "........fff...........",
                "....###########..f..ff",
                "..##a##a##a##a###..fff",
                ".ep#a##a##a##a#####ff.",
                "###################f..",
                ".##################ff.",
                "..###############..fff",
                "....###########..f..ff",
                ".......f....f.........",
            ], palette: ["M": 0x5E9E9C, "B": 0x1F5667, "L": 0xE2ECE8, "f": 0x3C6E78, "a": 0x12303C])
        ),
        FishSpecies(
            id: "goby", name: String(localized: "Goby"), rarity: .normal, sizeRange: 8...25,
            blurb: String(localized: "Eyes on top of its head, always watching the logs."),
            sprite: PixelSprite(rows: [
                "..ep..................",
                ".######.....fff.......",
                "########..fffffff.....",
                "##a####a####a#####..ff",
                "######a####a####a##fff",
                ".#a##########a#####fff",
                "..################.fff",
                "...ff.......ff......f.",
            ], palette: ["M": 0x9E8458, "B": 0x604B32, "L": 0xDECAA0, "f": 0x7C6644, "a": 0x46341F])
        ),
        FishSpecies(
            id: "shrimp", name: String(localized: "Shrimp"), rarity: .normal, sizeRange: 5...20,
            blurb: String(localized: "Curls up whenever someone says \u{201C}quick fix.\u{201D}"),
            sprite: PixelSprite(rows: [
                "~~~~..........",
                "....~.........",
                "..~..######...",
                ".~..#a##a###..",
                "...ep##a###a#.",
                "....##a####a##",
                ".....~~~~.#a##",
                "....~~~~..##a#",
                "..........#a#.",
                "........ff##..",
                ".......ffff...",
                "........ff....",
            ], palette: ["M": 0xF08A68, "B": 0xC24E36, "L": 0xFFC6AE, "f": 0xE8765A, "a": 0xFFE4D2, "~": 0xF0A48C])
        ),
        FishSpecies(
            id: "scallop", name: String(localized: "Scallop"), rarity: .normal, sizeRange: 6...18,
            blurb: String(localized: "Keeps its secrets like a private repo."),
            sprite: PixelSprite(rows: [
                "....###.###.###....",
                "..#####a###a#####..",
                ".###a##a###a##a###.",
                ".####a##a#a##a####.",
                "..####a#a#a#a####..",
                "...####a#a#a####...",
                ".....####a####.....",
                "...cccc#####cccc...",
                "...ccccccccccccc...",
            ], palette: ["M": 0xF2A27C, "B": 0xBA684C, "L": 0xFFD6BA, "a": 0xC8704E, "c": 0xDA8C66], shading: .lit)
        ),
        FishSpecies(
            id: "boot", name: String(localized: "Old Boot"), rarity: .normal, sizeRange: 22...31,
            blurb: String(localized: "Not a fish. Someone's bug report from 2019."),
            sprite: PixelSprite(rows: [
                "........aaaaaa..",
                "........######..",
                "........######.~",
                "........######..",
                "........##c###.~",
                "........######..",
                "........######..",
                "...###########..",
                ".#############..",
                "##############..",
                "bbbbbbbbbbbbbb..",
            ], palette: ["M": 0x74633E, "B": 0x40362A, "L": 0x9A865A, "a": 0xC8B272, "b": 0x2E2618,
                         "c": 0xA6925E, "~": 0x7CC0E0], shading: .lit)
        ),
        FishSpecies(
            id: "can", name: String(localized: "Empty Can"), rarity: .normal, sizeRange: 10...16,
            blurb: String(localized: "Still fizzing with last night's energy drink."),
            sprite: PixelSprite(rows: [
                "...cc.....",
                ".cccccccc.",
                ".########.",
                ".ddaaaaab.",
                ".dwwwwwwb.",
                ".ddaaaaab.",
                ".ddaaaaab.",
                ".########.",
                ".cccccccc.",
            ], palette: ["M": 0xB8BEC8, "B": 0x6E7684, "L": 0xE2E6EC, "a": 0xD8403A, "b": 0xA02A2A,
                         "d": 0xF07060, "c": 0x8E96A2], shading: .lit)
        ),
    ]

    // MARK: Magic

    private static let magic: [FishSpecies] = [
        FishSpecies(
            id: "goldfish", name: String(localized: "Goldfish"), rarity: .magic, sizeRange: 5...30,
            blurb: String(localized: "Forgets everything after three seconds. Unlike Claude's context."),
            sprite: PixelSprite(rows: [
                ".......ff.............",
                ".....ffff.............",
                "....######......fff...",
                "..#########....fffff..",
                ".##########...ffFffff.",
                "#ep#########ffFfFfff..",
                "#############fFfFff...",
                "############fFfFfff...",
                ".##########..fFfFfff..",
                "..########....fFffffff",
                "....#f##f.....ffffff..",
                ".....f..f......fff....",
            ], palette: ["M": 0xF26A2A, "B": 0xC8421C, "L": 0xFFB27A, "f": 0xFF9A5C, "F": 0xE0602E])
        ),
        FishSpecies(
            id: "puffer", name: String(localized: "Pufferfish"), rarity: .magic, sizeRange: 15...60,
            blurb: String(localized: "Inflates when the test suite goes red."),
            sprite: PixelSprite(rows: [
                "......o..o..o.......",
                "...o.#########.o....",
                "....###########.....",
                ".o#############o....",
                "..#a###a###a####ff..",
                "o#ep#############fff",
                ".##a###a###a#####ff.",
                "..###############o..",
                ".o##############....",
                "...o###########o....",
                ".....o#######.......",
                "......o..o..o.......",
            ], palette: ["M": 0xF2CC48, "B": 0xB88E22, "L": 0xFFF2B8, "a": 0x6E4E14, "f": 0xE8A838, "o": 0x5A3E10])
        ),
        FishSpecies(
            id: "clownfish", name: String(localized: "Clownfish"), rarity: .magic, sizeRange: 6...12,
            blurb: String(localized: "Lives in an anemone. Rent-free, like tech debt."),
            sprite: PixelSprite(rows: [
                ".......bfffb..........",
                ".....b#baf#b#b........",
                "...###bab###bab#..Ff..",
                "..####bab###bab##fff..",
                ".e####bab###bab##ffF..",
                ".p####bab###babFffff..",
                "######bab###bab##ffF..",
                ".#####bab###bab##fff..",
                "..####bab###bab#..Ff..",
                "....##bab###ba#.......",
                ".....fbb....bf........",
            ], palette: ["M": 0xF47A22, "B": 0xD45A12, "L": 0xFFA456, "a": 0xF8F6EE, "b": 0x1C1410,
                         "f": 0xF47A22, "F": 0x1C1410])
        ),
        FishSpecies(
            id: "squid", name: String(localized: "Squid"), rarity: .magic, sizeRange: 20...70,
            blurb: String(localized: "Eight arms, two tentacles, ten parallel tool calls."),
            sprite: PixelSprite(rows: [
                "......##......",
                ".....####.....",
                "...ff####ff...",
                "..fff####fff..",
                "....######....",
                "....#a####....",
                "....###a##....",
                "....##a###....",
                "....######....",
                "...e######e...",
                "...p######p...",
                "...########...",
                "..M.M.MM.M.M..",
                ".M..M.M..M..M.",
            ], palette: ["M": 0xF2C4BC, "B": 0xD08C86, "L": 0xFFF0EA, "a": 0xC85A5A, "f": 0xE8A6A0], shading: .lit)
        ),
        FishSpecies(
            id: "crab", name: String(localized: "Blue Crab"), rarity: .magic, sizeRange: 10...25,
            blurb: String(localized: "Walks sideways, like a merge that shouldn't have happened."),
            sprite: PixelSprite(rows: [
                ".##............##.",
                "###.#........#.###",
                "##.##..o..o..##.##",
                ".####..e..e..####.",
                "..###..p..p..###..",
                "....##########....",
                "...############...",
                ".#####a####a#####.",
                "...############...",
                "..#.##########.#..",
                ".#..#.#....#.#..#.",
                "#...#..#..#..#...#",
            ], palette: ["M": 0xE24E2E, "B": 0xA82C1C, "L": 0xFF8A62, "a": 0xFFD2B8], shading: .lit)
        ),
        FishSpecies(
            id: "jellyfish", name: String(localized: "Moon Jelly"), rarity: .magic, sizeRange: 10...40,
            blurb: String(localized: "Drifts along with no plan. Somehow ships anyway."),
            sprite: PixelSprite(rows: [
                ".....######.....",
                "...##########...",
                "..############..",
                ".####a####a####.",
                ".###aaa##aaa###.",
                ".##############.",
                ".#.##.##.##.##..",
                "..~..+~..+..~...",
                ".~...+.~.+...~..",
                "..~..+..~+..~...",
                ".~..+...~.+..~..",
                "..~.+..~...+.~..",
                "...~...~....~...",
            ], palette: ["M": 0x8EB6F2, "B": 0x5A74CE, "L": 0xD6EAFF, "H": 0xF4FAFF, "a": 0xF2A2D6,
                         "~": 0x9CC2F6, "+": 0xF2A2D6], shading: .lit)
        ),
        FishSpecies(
            id: "bugfish", name: String(localized: "Bugfish"), rarity: .magic, sizeRange: 4...40,
            blurb: String(localized: "Fix it once and it comes back in the next release."),
            sprite: PixelSprite(rows: [
                "~..~..................",
                ".~.~...#######........",
                "..~~.###b#########.ff.",
                "..e#####b##a#######ff.",
                "..p##########a####fff.",
                ".#############a###.ff.",
                "..############a##..ff.",
                "...##############.....",
                "....~.~.~..~.~.~......",
                "...~.~.~..~.~.~.......",
            ], palette: ["M": 0x4CA852, "B": 0x2A6636, "L": 0xA8E274, "a": 0x173A1E, "b": 0xB8F4A8,
                         "f": 0x3C8A44, "~": 0x6E9A5A])
        ),
    ]

    // MARK: Rare

    private static let rare: [FishSpecies] = [
        FishSpecies(
            id: "salmon", name: String(localized: "Salmon"), rarity: .rare, sizeRange: 50...120,
            blurb: String(localized: "Swims upstream against every code review."),
            sprite: PixelSprite(rows: [
                "........fff...........",
                ".....##########.f.....",
                "...##a##a###a###a#..ff",
                ".ep###a##a###a######ff",
                "####################f.",
                "o###################ff",
                ".o################..ff",
                "...#############......",
                "......f.....ff........",
            ], palette: ["M": 0xD8706A, "B": 0x5C4A64, "L": 0xF4C8B8, "a": 0x2C2234, "f": 0x9A5A5E])
        ),
        FishSpecies(
            id: "tuna", name: String(localized: "Bluefin Tuna"), rarity: .rare, sizeRange: 100...300,
            blurb: String(localized: "Built for speed. Never waits for CI."),
            sprite: PixelSprite(rows: [
                "........ff.........f..",
                ".....#########.....ff.",
                "...#############a.fff.",
                ".ep##############aff..",
                "###################f..",
                "###################f..",
                ".################a.ff.",
                "...#############a..fff",
                ".....##########.....ff",
                ".......ff.............",
            ], palette: ["M": 0x3E5CA4, "B": 0x1A2A5C, "L": 0xD8E2EE, "a": 0xF2C838, "f": 0x2A3E78])
        ),
        FishSpecies(
            id: "octopus", name: String(localized: "Octopus"), rarity: .rare, sizeRange: 30...150,
            blurb: String(localized: "Can hold eight pull requests at once."),
            sprite: PixelSprite(rows: [
                "......########......",
                "....############....",
                "...##############...",
                "...###a######a###...",
                "...##############...",
                "...##e########e##...",
                "....#p########p#....",
                ".....##########.....",
                "...##.##.##.##.##...",
                "..##..##.##.##..##..",
                ".##..##..##..##..##.",
                ".#a..#a..a#..a#..a#.",
                "..#...#..#...#...#..",
            ], palette: ["M": 0xD0504E, "B": 0x8E2C38, "L": 0xF09080, "a": 0xF8C8B8], shading: .lit)
        ),
        FishSpecies(
            id: "seahorse", name: String(localized: "Seahorse"), rarity: .rare, sizeRange: 5...35,
            blurb: String(localized: "The father carries the eggs. And the on-call pager."),
            sprite: PixelSprite(rows: [
                "......##......",
                ".....####.....",
                "####e###......",
                ".###p####.....",
                "......####....",
                "......#a###...",
                ".....#####ff..",
                ".....##a##ff..",
                ".....#####f...",
                "......#a##....",
                ".......###....",
                "....##..##....",
                "...#..###.....",
                "....###.......",
            ], palette: ["M": 0xF2B63C, "B": 0xC07C22, "L": 0xFFE08A, "a": 0xB05A1A, "f": 0xFFD070], shading: .lit)
        ),
        FishSpecies(
            id: "anglerfish", name: String(localized: "Anglerfish"), rarity: .rare, sizeRange: 10...100,
            blurb: String(localized: "Lures juniors to the deep with a single glowing TODO."),
            sprite: PixelSprite(rows: [
                "...~~~~~..............",
                "..~.....~.............",
                ".*~......##########...",
                "***....##############.",
                ".*....###e##########ff",
                ".....####p###########f",
                ".....#aa.a.a.a######ff",
                "....#..........#####ff",
                ".....#a.a.a.aa######f.",
                "......##############..",
                "........###########...",
                "..........ff...ff.....",
            ], palette: ["M": 0x4A4462, "B": 0x2A2640, "L": 0x6A6484, "a": 0xF2F2E6, "e": 0xE8F8F0,
                         "*": 0xB8FFF0, "~": 0x7A74A0, "f": 0x3A3452])
        ),
        FishSpecies(
            id: "koi", name: String(localized: "Koi"), rarity: .rare, sizeRange: 30...110,
            blurb: String(localized: "Each pattern is unique. So are its merge conflicts."),
            sprite: PixelSprite(rows: [
                ".......ffff...........",
                ".....aaaa###..........",
                "...##aaaaa####.....ff.",
                "..#####aa###aaa#..fff.",
                ".e######b##aaaa##ffff.",
                "#p###########aa##fFff.",
                "##########b######ffF..",
                ".####aa##########fFff.",
                "~.##aaaa#######..ffff.",
                ".~..######b##.....fff.",
                ".......f.....f.....ff.",
            ], palette: ["M": 0xF2EEE6, "B": 0xC8C0B8, "L": 0xFFFFFF, "H": 0xFFFFFF, "a": 0xE8402E,
                         "b": 0x1C1C24, "f": 0xF0E8E0, "F": 0xE8A090, "~": 0xE8C8B0, "o": 0x6A625E])
        ),
    ]

    // MARK: Unique

    private static let unique: [FishSpecies] = [
        FishSpecies(
            id: "swordfish", name: String(localized: "Swordfish"), rarity: .unique, sizeRange: 150...455,
            blurb: String(localized: "Cuts through spaghetti code in one strike."),
            sprite: PixelSprite(rows: [
                ".........fff..........",
                "........fffff.........",
                ".......fffffff........",
                "......##########....ff",
                "....#############..ff.",
                "cccep##############ff.",
                "...##################f",
                "....###############.ff",
                "......###########....f",
                ".........ff......ff...",
            ], palette: ["M": 0x3E6CB8, "B": 0x1E3470, "L": 0xC8D8EE, "f": 0x2A4C94, "c": 0x8AA6D0])
        ),
        FishSpecies(
            id: "manta", name: String(localized: "Manta Ray"), rarity: .unique, sizeRange: 300...700,
            blurb: String(localized: "Glides over the reef like a clean abstraction."),
            sprite: PixelSprite(rows: [
                ".........#..#.........",
                "........##..##........",
                "........######........",
                "......##########......",
                "....##############....",
                "..######aa##aa######..",
                "#######aa####aa#######",
                ".######a######a######.",
                "...######....######...",
                "......##......##......",
                ".........####.........",
                "..........##..........",
                "..........~...........",
                "...........~..........",
            ], palette: ["M": 0x34426A, "B": 0x1C2440, "L": 0x52628E, "a": 0xE8EEF6, "~": 0x52628E], shading: .lit)
        ),
        FishSpecies(
            id: "shark", name: String(localized: "Shark"), rarity: .unique, sizeRange: 150...600,
            blurb: String(localized: "Must keep moving or the sprint dies."),
            sprite: PixelSprite(rows: [
                "..........f...........",
                ".........ff.........f.",
                "........fff........ff.",
                ".....###########..fff.",
                "...##############fff..",
                ".ep##a#a##########ff..",
                "###################f..",
                ".ooooo#############ff.",
                "..LLLLLLLLLLLLLL##..ff",
                "....LLLLLLL##.......ff",
                "......ff....f.........",
            ], palette: ["M": 0x7A8898, "B": 0x4A5666, "L": 0xE4E8EC, "f": 0x5A6676, "a": 0x2A323E])
        ),
        FishSpecies(
            id: "turtle", name: String(localized: "Sea Turtle"), rarity: .unique, sizeRange: 60...180,
            blurb: String(localized: "Slow and steady. Its builds take 45 minutes."),
            sprite: PixelSprite(rows: [
                "........########......",
                "......##a##a##a###....",
                ".....#a##a##a##a###...",
                ".bbb##############....",
                "bebb################..",
                "bpbbffLLLLLLLLLLLff...",
                ".bb.fffff......fffff..",
                ".....ffffff.....fff...",
                ".......ffff...........",
            ], palette: ["M": 0x5A9A48, "B": 0x2E5A2A, "L": 0xD8CC80, "a": 0x9A7A30, "b": 0xC8B870,
                         "f": 0xB8A860, "F": 0x8A7A40])
        ),
        FishSpecies(
            id: "semicolon", name: String(localized: "Semicolon Eel"), rarity: .unique, sizeRange: 30...120,
            blurb: String(localized: "Always shows up where you forgot it;"),
            sprite: PixelSprite(rows: [
                ".......aaa......",
                "......aaaaa.....",
                "......aaaaa.....",
                ".......aaa......",
                "................",
                "......####......",
                ".....######.....",
                ".....#ep####....",
                "......######....",
                "........####....",
                "........###.....",
                ".......###......",
                ".....####.......",
                "...####.........",
            ], palette: ["M": 0x8A58C8, "B": 0x5A3494, "L": 0xC8A8F0, "a": 0xE6D8FF, "f": 0x7048B0], shading: .lit)
        ),
        FishSpecies(
            id: "coelacanth", name: String(localized: "Coelacanth"), rarity: .unique, sizeRange: 100...200,
            blurb: String(localized: "Thought extinct, like that legacy service still in production."),
            sprite: PixelSprite(rows: [
                ".......ff.....ff......",
                "......fff....fff......",
                "...#############......",
                ".##a####a####a###.ff..",
                "ep####a####a#####fff..",
                "###a#####a####a###ffff",
                "##################fff.",
                ".##a####a####a####ffff",
                "..##############..fff.",
                "....#ff###ff###....ff.",
                ".....ff...ff..........",
            ], palette: ["M": 0x3A5C9A, "B": 0x223868, "L": 0x6A8AC0, "a": 0xE8F0FA, "f": 0x2E4A84])
        ),
    ]

    // MARK: Legendary

    private static let legendary: [FishSpecies] = [
        FishSpecies(
            id: "goldencarp", name: String(localized: "Golden Carp"), rarity: .legendary, sizeRange: 60...130,
            blurb: String(localized: "Said to grant one wish: a green build on the first try."),
            sprite: PixelSprite(rows: [
                "*......fff.........*..",
                ".....fffff............",
                "....#######.......ff..",
                "..###a#a#a###....fff..",
                ".##a#a#a#a#a##..ffff..",
                "#ep#a#a#a#a#a##fffff..",
                "#####a#a#a#a####fff...",
                "#####a#a#a#a####fff.*.",
                "~###a#a#a#a####.ffff..",
                ".~############...fff..",
                "....#f####f#......ff..",
                "..*..f....ff..........",
            ], palette: ["M": 0xF2B82C, "B": 0xB47A10, "L": 0xFFE27A, "H": 0xFFF8D0, "a": 0xFFF0A0,
                         "f": 0xE89A22, "F": 0xB86E10, "*": 0xFFFBE0, "~": 0xE8B040])
        ),
        FishSpecies(
            id: "whale", name: String(localized: "Blue Whale"), rarity: .legendary, sizeRange: 2000...3300,
            blurb: String(localized: "The largest creature ever. About the size of node_modules."),
            sprite: PixelSprite(rows: [
                "..~.~.................",
                "...~..................",
                "..~.~.................",
                "...~..................",
                "....###########.......",
                "..################..ff",
                ".ep################fff",
                "####################f.",
                "#aaaaaaaa##########ff.",
                ".LaLaLaLa#########..ff",
                "...LLLLLLL######......",
                "........ff............",
            ], palette: ["M": 0x3E6AA8, "B": 0x1E3C74, "L": 0xB8D0EC, "a": 0x8AAED8, "~": 0x9AD8FF, "f": 0x2C5090])
        ),
        FishSpecies(
            id: "kraken", name: String(localized: "Kraken"), rarity: .legendary, sizeRange: 1000...5000,
            blurb: String(localized: "Drags whole monoliths down to the deep."),
            sprite: PixelSprite(rows: [
                "........######........",
                "......##########......",
                ".....############.....",
                "....##############....",
                "....####aa###aa###....",
                "....####ap###pa###....",
                ".....############.....",
                "..##..##########..##..",
                ".##..##.##..##.##..##.",
                "##..##..##..##..##..##",
                "#b.##..#b....b#..##.b#",
                ".#.#b..#......#..b#.#.",
                "...##...#....#...##...",
            ], palette: ["M": 0x8E3A7A, "B": 0x5A1E54, "L": 0xC86AA8, "a": 0xFFE070, "p": 0x2A0A20,
                         "b": 0xF0B8DC], shading: .lit)
        ),
        FishSpecies(
            id: "sunfish", name: String(localized: "Ocean Sunfish"), rarity: .legendary, sizeRange: 180...330,
            blurb: String(localized: "Faints if a single test fails. Extremely rare to land alive."),
            sprite: PixelSprite(rows: [
                "...........ff......",
                "..........fff......",
                ".........ffff......",
                "....########f......",
                "..############.....",
                ".##############....",
                "#ep#a####a######f..",
                "###############ff..",
                "##a####a########f..",
                ".##############ff..",
                "..############.....",
                "....########f......",
                ".........ffff......",
                "..........fff......",
            ], palette: ["M": 0xA8B4C0, "B": 0x6A7888, "L": 0xE2E8EE, "a": 0xCCD6E0, "f": 0x7A8898])
        ),
    ]

    // MARK: Mythic

    private static let mythic: [FishSpecies] = [
        FishSpecies(
            id: "leviathan", name: String(localized: "Leviathan"), rarity: .mythic, sizeRange: 3000...9000,
            blurb: String(localized: "Older than the first line of code. Sleeps beneath every legacy system."),
            sprite: PixelSprite(rows: [
                "..ff..................",
                ".fff###...............",
                "..######..........*...",
                ".#c######.............",
                "##########............",
                ".aaaa.####............",
                "......####.......ff...",
                ".......####....#####..",
                "........####..###..##.",
                ".........#######....##",
                "..........#####.....ff",
            ], palette: ["M": 0x1E8A8A, "B": 0x0E4A56, "L": 0x6AD8C8, "a": 0xE8FFF8, "c": 0xFF5A5A,
                         "*": 0xB8FFF6, "f": 0x2AB0A0])
        ),
        FishSpecies(
            id: "dragonking", name: String(localized: "Dragon King"), rarity: .mythic, sizeRange: 888...8888,
            blurb: String(localized: "Holds the pearl of perfect uptime. Nines without end."),
            sprite: PixelSprite(rows: [
                "...b..b...............",
                "....bbb...............",
                "..######a.............",
                ".#e######aa...........",
                "##p#######a...........",
                "ww######a####.........",
                ".~..~.#######a......a.",
                "~..~...#######a...a##a",
                ".*.......######a.a####",
                "*c*.......##########..",
                ".*.........########...",
                ".............####.....",
            ], palette: ["M": 0xD8382A, "B": 0x8E1C1C, "L": 0xFFC04A, "a": 0xFFD84A, "b": 0xF8F0E0, "w": 0xFFF8F0,
                         "~": 0xFFD84A, "c": 0x9AE8FF, "*": 0xE0FAFF])
        ),
        FishSpecies(
            id: "sparkfish", name: String(localized: "Sparkfish"), rarity: .mythic, sizeRange: 30...77,
            blurb: String(localized: "A spark of inspiration that learned to swim. It only appears when you build something great."),
            sprite: PixelSprite(rows: [
                ".*.......f.........*..",
                "........fff...........",
                ".....########.....ff..",
                "...######a#####..fff..",
                ".#####a##a##a###ffff..",
                "#ep####aaaaa####fff*..",
                "########aaa#####ffff..",
                "#####aaaaaaaaa##fff...",
                ".#######aaa####..fff..",
                "..#####aaaaa##....ff..",
                "....###a##a##a#.......",
                ".*.....f..a..f....*...",
            ], palette: ["M": 0xE07A52, "B": 0xB04E30, "L": 0xFFB894, "H": 0xFFE6D6, "a": 0xFFF2E0,
                         "*": 0xFFD8B8, "f": 0xF09A6A, "F": 0xC0603E])
        ),
    ]
}
