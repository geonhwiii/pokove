import Foundation

/// Pixel art for the fishing spot: the angler cat, its bobber, and the sky.
nonisolated enum FishingArt {
    static let bobber = PixelSprite(rows: [
        "..~..",
        ".aaa.",
        "aaaad",
        "wwwwL",
        ".wwL.",
    ], palette: ["a": 0xFF4B3E, "d": 0xC8322A, "w": 0xF6F4EE, "L": 0xC4CAD4, "~": 0xB8C0CC, "o": 0x3A1418], padsToCanvas: false)

    /// A ginger cat sitting on the dock, facing the water.
    static let cat = PixelSprite(rows: catRows(eyes: "p"), palette: catPalette, shading: .lit, padsToCanvas: false)

    /// The same cat dozing between Claude turns.
    static let sleepingCat = PixelSprite(rows: catRows(eyes: "B"), palette: catPalette, shading: .lit, padsToCanvas: false)

    private static func catRows(eyes: Character) -> [String] {
        [
            "......#...#",
            "......##.##",
            "......#####",
            "......##\(eyes)#\(eyes)",
            "......####k",
            ".#...#####.",
            "#...######.",
            "#..#######.",
            ".#.#######.",
            "..##ff##ff.",
        ]
    }

    private static let catPalette: [Character: UInt32] = [
        "M": 0xF0A040, "B": 0xB86A24, "L": 0xFFD08E, "f": 0xFFEACC, "k": 0xFF8A9A, "o": 0x3A2010,
    ]

    static let moon = PixelSprite(rows: [
        ".***.",
        "*****",
        "***+*",
        "*+***",
        ".***.",
    ], palette: ["*": 0xFFF4C8, "+": 0xE8D8A0], padsToCanvas: false)

    static let sun = PixelSprite(rows: [
        "..**..",
        ".****.",
        "******",
        "******",
        ".****.",
        "..**..",
    ], palette: ["*": 0xFFE27A], padsToCanvas: false)

    static let cloud = PixelSprite(rows: [
        "...**....",
        ".******..",
        "*********",
    ], palette: ["*": 0xF4F8FF], padsToCanvas: false)
}
