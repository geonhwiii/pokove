import Foundation

// Battle messages in the games' style. Korean particles (이/가, 을/를, 은/는) depend on the name
// before them, so these lines are built here instead of in the string catalog.

nonisolated enum BattleText {
    private static var korean: Bool { PokeLanguage.isKorean }

    static func wildAppeared(_ name: String) -> String {
        korean ? "야생 \(name.subjectParticle) 나타났다!" : "A wild \(name) appeared!"
    }

    static func challenged(_ trainer: Trainer) -> String {
        korean ? "\(trainer.title) \(trainer.name.subjectParticle) 승부를 걸어왔다!" : "\(trainer.title) \(trainer.name) wants to battle!"
    }

    static func legendAppeared(_ name: String) -> String {
        korean ? "\(name.subjectParticle) 앞을 가로막았다!" : "\(name) blocks the way!"
    }

    static func goPartner(_ name: String) -> String { korean ? "가라! \(name)!" : "Go! \(name)!" }

    static func sentOut(_ trainer: Trainer, _ name: String) -> String {
        korean ? "\(trainer.name.topicParticle) \(name.objectParticle) 내보냈다!" : "\(trainer.name) sent out \(name)!"
    }

    static func used(_ attacker: String, _ move: String) -> String {
        korean ? "\(attacker)의 \(move)!" : "\(attacker) used \(move)!"
    }

    static func missed(_ attacker: String) -> String {
        korean ? "\(attacker)의 공격은 빗나갔다!" : "\(attacker)'s attack missed!"
    }

    static var miss: String { korean ? "빗나갔다!" : "Missed!" }

    static func fainted(_ name: String) -> String { korean ? "\(name.subjectParticle) 쓰러졌다!" : "\(name) fainted!" }

    static var superEffective: String { korean ? "효과가 굉장했다!" : "It's super effective!" }
    static var notVeryEffective: String { korean ? "효과가 별로인 듯하다…" : "It's not very effective…" }
    static var noEffect: String { korean ? "효과가 없는 것 같다…" : "It had no effect…" }
    static var critical: String { korean ? "급소에 맞았다!" : "A critical hit!" }
    static func hits(_ count: Int) -> String { korean ? "\(count)번 맞았다!" : "Hit \(count) times!" }
    static var victory: String { korean ? "승리!" : "Victory!" }
    static var defeat: String { korean ? "눈앞이 캄캄해졌다…" : "The party is out of usable Pokémon…" }
}

nonisolated extension String {
    /// Whether the last Hangul syllable ends in a consonant (받침).
    private var endsInConsonant: Bool? {
        guard let scalar = unicodeScalars.last(where: { !$0.properties.isWhitespace }) else { return nil }
        let value = scalar.value
        if (0xAC00...0xD7A3).contains(value) { return (value - 0xAC00) % 28 != 0 }
        // Digits and Latin letters as Koreans read them.
        if let digit = Int(String(scalar)) { return [0, 1, 3, 6, 7, 8].contains(digit) }
        return nil
    }

    var subjectParticle: String { self + (endsInConsonant == false ? "가" : "이") }
    var objectParticle: String { self + (endsInConsonant == false ? "를" : "을") }
    var topicParticle: String { self + (endsInConsonant == false ? "는" : "은") }
}
