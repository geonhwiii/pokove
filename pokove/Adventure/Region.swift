import Foundation

/// The regions a journey can take place in. Each has its own box, party, stardust and progress;
/// the Pokédex is shared. Johto opens once Kanto has a Champion.
nonisolated enum Region: String, Codable, CaseIterable, Sendable {
    case kanto, johto

    var name: String {
        switch self {
        case .kanto: PokeLanguage.isKorean ? "관동" : "Kanto"
        case .johto: PokeLanguage.isKorean ? "성도" : "Johto"
        }
    }

    /// The national dex numbers its gacha and hints draw from.
    var dexRange: ClosedRange<Int> {
        switch self {
        case .kanto: 1...151
        case .johto: 1...251
        }
    }

    /// The three a journey here starts with.
    var starters: [Int] {
        switch self {
        case .kanto: [1, 4, 7]
        case .johto: [152, 155, 158]
        }
    }

    /// Shows up in the gacha once this region's Champion is crowned.
    var mythical: Int {
        switch self {
        case .kanto: Kanto.mew
        case .johto: Johto.celebi
        }
    }

    var legends: [LegendSpot] {
        switch self {
        case .kanto: Kanto.legends
        case .johto: Johto.legends
        }
    }

    var stretches: [Stretch] {
        switch self {
        case .kanto: Kanto.stretches
        case .johto: Johto.stretches
        }
    }

    /// PokéAPI game versions whose wild encounters stock it: FireRed/LeafGreen, HeartGold/SoulSilver.
    var encounterVersions: [Int] {
        switch self {
        case .kanto: [10, 11]
        case .johto: [15, 16]
        }
    }

    /// The journey. Kanto's Champion depends on the starter.
    func chapters(starter: Int) -> [Chapter] {
        switch self {
        case .kanto: Kanto.chapters(starter: starter)
        case .johto: Johto.chapters()
        }
    }

    /// The highest level a Pokémon reaches here with this many badges; experience past it is banked.
    func levelCap(badges: Int, champion: Bool) -> Int {
        if champion { return PokeMath.maxLevel }
        let caps = switch self {
        case .kanto: Kanto.levelCaps
        case .johto: Johto.levelCaps
        }
        return caps[min(max(0, badges), caps.count - 1)]
    }

    /// Badges count 1–8 in each region.
    func badgeName(_ badge: Int) -> String {
        let names = switch self {
        case .kanto: Kanto.badgeNames
        case .johto: Johto.badgeNames
        }
        guard (1...names.count).contains(badge) else { return "" }
        return PokeLanguage.isKorean ? names[badge - 1].ko : names[badge - 1].en
    }

    /// PokéAPI numbers its badge images across regions: Johto's are 9–16.
    func badgeImage(_ badge: Int) -> Int {
        switch self {
        case .kanto: badge
        case .johto: badge + 8
        }
    }

    /// Legendaries and ★ spots from every region, which the gachas never hold.
    static var allLegendSpecies: Set<Int> { Set(allCases.flatMap { $0.legends.map(\.species) }) }
}
