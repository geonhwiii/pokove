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

    /// "~로" after a vowel or ㄹ, "~으로" after any other consonant.
    var directionParticle: String {
        let endsInRieul = unicodeScalars.last.map { (0xAC00...0xD7A3).contains($0.value) && ($0.value - 0xAC00) % 28 == 8 } ?? false
        return self + (endsInConsonant == true && !endsInRieul ? "으로" : "로")
    }
}

/// "While you were away" lines, with Korean particles for the names in them.
nonisolated enum RecapText {
    private static var korean: Bool { PokeLanguage.isKorean }

    static var title: String { korean ? "자리 비운 동안" : "While you were away" }
    static func beat(_ trainer: String, badge: String) -> String {
        korean ? "\(trainer.objectParticle) 이기고 \(badge.objectParticle) 받았어요" : "Beat \(trainer) and got the \(badge)"
    }
    static func evolved(_ from: String?, into to: String) -> String {
        guard let from else { return korean ? "\(to.directionParticle) 진화했어요" : "Evolved into \(to)" }
        return korean ? "\(from.subjectParticle) \(to.directionParticle) 진화했어요" : "\(from) evolved into \(to)"
    }
    /// "깨비참, 구구가 동료가 됐어요", with "외 N마리" past three names.
    static func joined(_ names: [String]) -> String {
        let shown = Array(names.prefix(3))
        let more = names.count - shown.count
        if korean {
            let list = shown.joined(separator: ", ")
            return more > 0 ? "\(list) 외 \(more)마리가 동료가 됐어요" : "\(list.subjectParticle) 동료가 됐어요"
        }
        let list = more > 0 ? shown.joined(separator: ", ") + " and \(more) more"
            : shown.count > 1 ? shown.dropLast().joined(separator: ", ") + " and " + shown.last! : shown.joined()
        return "\(list) joined the team"
    }
    static func lost(to trainer: String, times: Int) -> String {
        if korean { return "\(trainer)에게 \(times)번 졌어요" }
        return times == 1 ? "Lost to \(trainer)" : "Lost to \(trainer) \(times) times"
    }
    static var training: String { korean ? "수련하고 다시 도전해요" : "Training, then trying again" }
    static var bestTeam: String { korean ? "추천 팀" : "Best team" }
    static func dungeon(_ tier: String) -> String { korean ? "던전 \(tier) 클리어" : "Cleared the \(tier) dungeon" }
    static var ultraBall: String { korean ? "울트라볼" : "Ultra Ball" }
    static func learned(_ name: String, _ move: String) -> String {
        korean ? "\(name.subjectParticle) \(move.objectParticle) 배웠어요" : "\(name) learned \(move)"
    }
    static func learnedMore(_ count: Int) -> String { korean ? "기술 \(count)개를 더 배웠어요" : "\(count) more moves learned" }
    /// "4-3에서 4-10까지 갔어요", "4-3을 지났어요", or, for recaps from before `start`, "4-10까지 갔어요".
    static func moved(from start: String?, to end: String) -> String {
        guard let start else { return korean ? "\(end)까지 갔어요" : "Made it to \(end)" }
        if start == end { return korean ? "\(end.objectParticle) 지났어요" : "Passed \(end)" }
        return korean ? "\(start)에서 \(end)까지 갔어요" : "Went from \(start) to \(end)"
    }
    static func stayed(at station: String) -> String { korean ? "\(station)에 머물렀어요" : "Stayed at \(station)" }
    static var stardust: String { korean ? "별의모래" : "Stardust" }
    static var shinyLabel: String { korean ? "이로치" : "Shiny" }
    static func shiny(_ name: String) -> String { korean ? "이로치 \(name.objectParticle) 만났어요" : "Found a shiny \(name)" }
    static func shinyNow(_ name: String) -> String { korean ? "✦ \(name.subjectParticle) 이로치가 됐어요!" : "✦ \(name) is shiny now!" }
    static func shinyJoined(_ name: String) -> String { korean ? "✦ 이로치 \(name) 합류!" : "✦ A shiny \(name) joined your team!" }
    /// How long the recap covers, in whole minutes.
    static func span(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(seconds / 60))
        if minutes < 60 { return korean ? "\(minutes)분" : "\(minutes)m" }
        let hours = minutes / 60, rest = minutes % 60
        if korean { return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분" }
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}

/// Lines for a challenge's VS intro and its win or loss card.
nonisolated enum ChallengeText {
    private static var korean: Bool { PokeLanguage.isKorean }

    static var legendary: String { korean ? "전설의 포켓몬" : "Legendary Pokémon" }
    static func dungeon(_ tier: String) -> String { korean ? "\(tier) 던전" : "\(tier) dungeon" }
    static func floors(_ count: Int, types: String) -> String { korean ? "\(count)층 · \(types)" : "\(count) floors · \(types)" }
    static var victory: String { korean ? "승리!" : "Victory!" }
    static var defeat: String { korean ? "패배" : "Defeated" }
    static func gotBadge(_ badge: String) -> String { korean ? "\(badge.objectParticle) 받았어요" : "Got the \(badge)" }
    static func cap(_ from: Int, _ to: Int) -> String { korean ? "레벨 상한 \(from) → \(to)" : "Level cap \(from) → \(to)" }
    static func joined(_ name: String) -> String { korean ? "\(name.subjectParticle) 동료가 됐어요" : "\(name) joined your team" }
    static func cleared(_ dungeon: String) -> String { korean ? "\(dungeon) 클리어" : "\(dungeon) cleared" }
    static var ultraBall: String { korean ? "울트라볼 1개" : "1 Ultra Ball" }
    static func lost(to name: String) -> String { korean ? "\(name)에게 졌어요" : "\(name) won this time" }
    static var nothingLost: String { korean ? "잃은 건 없어요. 수련하고 다시 도전해요." : "Nothing lost. The party trains and tries again." }
    static func chance(_ percent: Int) -> String { korean ? "다음 도전 이길 확률 \(percent)%" : "\(percent)% to win next time" }
}

/// Hints for what to do next and why a boss wins, the history page, and the Pokédex card's extras.
nonisolated enum GuideText {
    private static var korean: Bool { PokeLanguage.isKorean }

    // Next step and VS.
    static func stationsTo(_ boss: String, _ count: Int) -> String {
        korean ? "\(boss)까지 역 \(count)개" : count == 1 ? "1 station to \(boss)" : "\(count) stations to \(boss)"
    }
    static var resting: String { korean ? "에이전트가 일하면 다시 출발해요" : "Moves on when an agent works" }
    /// "Lv 18이면", "Lv 25면".
    private static func at(_ level: Int) -> String { "Lv \(level)" + ("\(level)".objectParticle.hasSuffix("을") ? "이면" : "면") }
    static func needLevel(_ level: Int, _ chance: Double) -> String {
        korean ? "\(at(level)) 이길 확률 \(percent(chance))" : "\(percent(chance)) to win at Lv \(level)"
    }
    static func needLevelShort(_ level: Int, _ chance: Double) -> String {
        korean ? "\(at(level)) \(percent(chance))" : "\(percent(chance)) at Lv \(level)"
    }
    static func evenAtCap(_ level: Int, _ chance: Double) -> String {
        let even = "\(level)".objectParticle.hasSuffix("을") ? "이어도" : "여도"
        return korean ? "상한 Lv \(level)\(even) \(percent(chance))" : "\(percent(chance)) even at the Lv \(level) cap"
    }
    static func chance(_ boss: String, _ chance: Double) -> String {
        korean ? "\(boss) · 이길 확률 \(percent(chance))" : "\(boss) · \(percent(chance)) to win"
    }
    static var bestTeam: String { korean ? "추천 팀" : "Best team" }
    /// The party bar's short label for the same button.
    static var recommend: String { korean ? "추천" : "Best" }
    static var gacha: String { korean ? "뽑기" : "Gacha" }
    static func dungeon(_ tier: String) -> String { korean ? "\(tier) 던전" : "\(tier) dungeon" }
    static func percent(_ chance: Double) -> String { "\(Int((chance * 100).rounded()))%" }

    // The history page.
    static var history: String { korean ? "기록" : "History" }
    static var historyHelp: String { korean ? "자리 비운 동안 있었던 일, 오늘과 어제" : "What happened while you were away, today and yesterday" }
    static var noHistory: String { korean ? "아직 기록이 없어요" : "Nothing yet" }
    static var noHistoryDetail: String {
        korean ? "노치를 닫아 둔 동안 있었던 일이 여기 쌓여요." : "What happens while the page is closed shows up here."
    }
    static var justNow: String { korean ? "방금" : "Just now" }
    static var yesterday: String { korean ? "어제" : "Yesterday" }
    /// The toast's count of what happened: "배지 1 · 진화 2 · 새 동료 3".
    static func summary(badges: Int, evolved: Int, joined: Int, losses: Int, dungeons: Int, shinies: Int) -> String {
        var parts: [String] = []
        if shinies > 0 { parts.append(korean ? "이로치 \(shinies)" : "\(shinies) shiny") }
        if badges > 0 { parts.append(korean ? "배지 \(badges)" : badges == 1 ? "1 badge" : "\(badges) badges") }
        if evolved > 0 { parts.append(korean ? "진화 \(evolved)" : "\(evolved) evolved") }
        if joined > 0 { parts.append(korean ? "새 동료 \(joined)" : "\(joined) joined") }
        if dungeons > 0 { parts.append(korean ? "던전 \(dungeons)" : dungeons == 1 ? "1 dungeon" : "\(dungeons) dungeons") }
        if losses > 0 { parts.append(korean ? "패배 \(losses)" : losses == 1 ? "1 loss" : "\(losses) losses") }
        return parts.joined(separator: " · ")
    }

    // The Pokédex.
    static var ownedOnly: String { korean ? "보유만" : "Owned" }
    static func cap(_ level: Int) -> String { korean ? "상한 \(level)" : "Cap \(level)" }
    static func learns(_ move: String, at level: Int) -> String {
        korean ? "Lv \(level)에 \(move.objectParticle) 배워요" : "Learns \(move) at Lv \(level)"
    }
    static func afterBadge(_ levels: Int) -> String {
        korean ? "배지를 받으면 \(levels)레벨 올라요" : levels == 1 ? "Up 1 level with the next badge" : "Up \(levels) levels with the next badge"
    }
    static var atCap: String { korean ? "레벨 상한이에요. 배지를 받으면 더 커요." : "At the level cap. The next badge lets it grow." }
    static func strong(against boss: String) -> String { korean ? "\(boss)에게 유리" : "Strong vs \(boss)" }
    static func weak(against boss: String) -> String { korean ? "\(boss)에게 불리" : "Weak vs \(boss)" }
    static var nextEvolution: String { korean ? "다음 진화" : "Evolves" }
    static func oneOf(_ count: Int) -> String { korean ? "\(count)가지 중 하나" : "One of \(count)" }

    static func habitat(_ habitat: Habitat, name: (Int) -> String) -> String {
        switch habitat {
        case .wild(let chapter): return korean ? "\(chapter + 1)장 역에서 만나요" : "Found at the stations of chapter \(chapter + 1)"
        case .gacha(let chapter):
            if chapter == 0 { return korean ? "뽑기에서 나와요" : "Comes from the gacha" }
            return korean ? "\(chapter + 1)장부터 뽑기에서 나와요" : "Comes from the gacha from chapter \(chapter + 1)"
        case .legend(let chapter): return korean ? "\(chapter + 1)장 ★ 전설에게 이기면 동료가 돼요" : "Beat chapter \(chapter + 1)'s ★ legendary to add it"
        case .mythical: return korean ? "챔피언이 된 뒤 뽑기에서 아주 드물게 나와요" : "Very rarely from the gacha, once you're Champion"
        case .evolves(let from, let level):
            let before = name(from)
            guard let level else { return korean ? "\(before.subjectParticle) 진화하면 돼요" : "Evolves from \(before)" }
            return korean ? "\(before.subjectParticle) Lv \(level)에 진화하면 돼요" : "\(before) evolves into it at Lv \(level)"
        case .unknown: return korean ? "에이전트가 일하는 동안 만날 수 있어요" : "Keep your agents busy to meet this one."
        }
    }
}
