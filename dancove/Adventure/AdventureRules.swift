import Foundation

// Progress along the journey, discoveries, the gacha and rewards. Pure rules, shared with the
// simulation script.

/// A stage on the main journey: the node's index and the stage within it.
nonisolated struct StagePoint: Codable, Hashable, Comparable, Sendable {
    var node: Int
    var stage: Int

    static let start = StagePoint(node: 0, stage: 0)

    static func < (lhs: StagePoint, rhs: StagePoint) -> Bool {
        (lhs.node, lhs.stage) < (rhs.node, rhs.stage)
    }
}

/// What the party takes on next.
nonisolated enum BattleTarget: Equatable, Sendable {
    case stage(StagePoint)
    case legend(String)
}

/// How far the journey has come, and where the party is fighting.
nonisolated struct JourneyProgress: Codable, Equatable, Sendable {
    /// The first stage not yet cleared. Past the last node once everything is done.
    var frontier = StagePoint.start
    /// Clears of an earlier stage still to go after a loss, before trying the frontier again.
    var training = 0
    /// A stretch already reached that the user chose to stay on.
    var stay: Int?
    /// Counts clears while staying (or after the journey is done), to cycle through the stages.
    var cursor = 0
    var badges = 0
    var isChampion = false
    var beatenLegends: [String] = []
    /// A legendary the user is taking on right now.
    var legend: String?
    /// The user asked to take on the trainer at the frontier while AUTO is off.
    var challenge = false
    /// Clears spent waiting in front of a trainer, for AUTO's patience.
    var waited = 0

    static let trainingClears = 3

    func isComplete(_ nodes: [JourneyNode]) -> Bool { frontier.node >= nodes.count }

    /// Whether the party has reached this node, so the map shows it and it can be revisited.
    func hasReached(_ index: Int) -> Bool { index <= frontier.node }

    /// Stages cleared on a node.
    func clearedStages(of index: Int, in nodes: [JourneyNode]) -> Int {
        guard nodes.indices.contains(index) else { return 0 }
        if index < frontier.node { return nodes[index].stageCount }
        return index == frontier.node ? frontier.stage : 0
    }

    func isReached(legend node: JourneyNode, in nodes: [JourneyNode]) -> Bool {
        guard case .legend(_, _, let after) = node.kind, let index = nodes.firstIndex(where: { $0.id == after }) else { return false }
        return hasReached(index)
    }

    /// The party waits on the stage before a trainer until it's likely to win (AUTO) or the user
    /// taps Challenge, so the same loss doesn't replay over and over.
    /// `readiness` is the forecast chance of beating the trainer at the frontier.
    func isHolding(_ nodes: [JourneyNode], auto: Bool, readiness: Double) -> Bool {
        guard legend == nil, stay == nil, !challenge, !isComplete(nodes), !nodes[frontier.node].isRoute,
              previousWild(before: frontier, in: nodes) != nil else { return false }
        guard auto else { return true }
        return !AutoChallenge.shouldTry(readiness: readiness, waited: waited)
    }

    func target(_ nodes: [JourneyNode], auto: Bool, readiness: Double = 1) -> BattleTarget {
        if let legend { return .legend(legend) }
        if let stay, nodes.indices.contains(stay) {
            let cleared = max(1, clearedStages(of: stay, in: nodes))
            return .stage(StagePoint(node: stay, stage: cursor % cleared))
        }
        if isComplete(nodes) {
            let last = nodes.count - 1
            return .stage(StagePoint(node: last, stage: cursor % nodes[last].stageCount))
        }
        if training > 0 || isHolding(nodes, auto: auto, readiness: readiness), let previous = previousWild(before: frontier, in: nodes) {
            return .stage(previous)
        }
        return .stage(frontier)
    }

    /// The closest wild stage before `point`, for training and holding.
    func previousWild(before point: StagePoint, in nodes: [JourneyNode]) -> StagePoint? {
        var node = point.node, stage = point.stage - 1
        while node >= 0 {
            if stage >= 0, nodes.indices.contains(node), nodes[node].isRoute { return StagePoint(node: node, stage: stage) }
            node -= 1
            stage = nodes.indices.contains(node) ? nodes[node].stageCount - 1 : -1
        }
        return nil
    }

    func point(after point: StagePoint, in nodes: [JourneyNode]) -> StagePoint {
        if point.stage + 1 < nodes[point.node].stageCount { return StagePoint(node: point.node, stage: point.stage + 1) }
        return StagePoint(node: point.node + 1, stage: 0)
    }

    enum Outcome: Equatable, Sendable {
        case none
        /// A new stage opened.
        case advanced
        case badge(Int)
        case champion
        case legend(String)
    }

    @discardableResult
    mutating func record(_ target: BattleTarget, cleared: Bool, nodes: [JourneyNode]) -> Outcome {
        switch target {
        case .legend(let id):
            legend = nil
            guard cleared else { return .none }
            if !beatenLegends.contains(id) { beatenLegends.append(id) }
            return .legend(id)
        case .stage(let point):
            if point == frontier, !isComplete(nodes), stay == nil {
                challenge = false
                waited = 0
                guard cleared else {
                    // Trainers are held back by the forecast; a rare loss on a route trains first.
                    let isRoute = nodes[point.node].isRoute
                    training = isRoute && previousWild(before: frontier, in: nodes) != nil ? Self.trainingClears : 0
                    return .none
                }
                let node = nodes[point.node]
                frontier = self.point(after: point, in: nodes)
                if let badge = node.trainers.first?.badge, node.isGym {
                    badges = max(badges, badge)
                    return .badge(badge)
                }
                if node.trainers.count > 1, point.stage == node.stageCount - 1 {
                    isChampion = true
                    return .champion
                }
                return .advanced
            }
            guard cleared else { return .none }
            if stay != nil || isComplete(nodes) { cursor += 1 } else if training > 0 { training -= 1 } else { waited += 1 }
            return .none
        }
    }
}

// MARK: Challenging trainers

nonisolated enum AutoChallenge {
    /// AUTO takes on a trainer once it's likely to win, or after a long wait if it at least has a shot.
    static let confident = 0.5
    static let hopeful = 0.2
    static let patience = 30

    static func shouldTry(readiness: Double, waited: Int) -> Bool {
        readiness >= confident || (readiness >= hopeful && waited >= patience)
    }
}

/// Plays a stage out many times ahead of time to estimate the chance of winning it.
nonisolated enum Forecast {
    static func winChance(party: [Combatant], plan: StagePlan, data: GameData, trials: Int = 24) -> Double {
        guard !party.isEmpty else { return 0 }
        var rng = SeededRNG(seed: 0x5EED)
        var wins = 0
        for _ in 0..<trials {
            var battle = BattleState(plan: plan, party: party, data: data, seed: rng.next())
            var steps = 0
            while !battle.isOver, steps < 2000 {
                if battle.step() == .cleared { wins += 1 }
                steps += 1
            }
        }
        return Double(wins) / Double(trials)
    }
}

// MARK: Discovery

/// A wild Pokémon that turns up while an agent works and joins at once.
nonisolated enum Discovery {
    /// On average one every this much agent work; quicker until the party is three, so the
    /// first hour isn't lonely.
    static func meanInterval(boxCount: Int) -> TimeInterval {
        boxCount < 3 ? 6 * 60 : 20 * 60
    }

    /// Where discoveries come from: the stretch being fought, or the last one before a trainer.
    static func pool(for target: BattleTarget, progress: JourneyProgress, data: GameData) -> [(species: Int, share: Double)] {
        var node: JourneyNode?
        switch target {
        case .stage(let point):
            if data.nodes[point.node].isRoute {
                node = data.nodes[point.node]
            } else if let previous = progress.previousWild(before: point, in: data.nodes) {
                node = data.nodes[previous.node]
            }
        case .legend:
            if let previous = progress.previousWild(before: progress.frontier, in: data.nodes) { node = data.nodes[previous.node] }
        }
        return node.map { data.encounters.pool(for: $0, dex: data.dex) } ?? []
    }

    static func roll(pool: [(species: Int, share: Double)], rng: inout SeededRNG) -> Int? {
        rng.weighted(pool.map(\.share)).map { pool[$0].species }
    }

    /// A newcomer arrives a little behind the party, so it's worth raising without jumping ahead.
    static func level(of species: PokeSpecies, partyLevel: Int, cap: Int, rng: inout SeededRNG) -> Int {
        var level = max(3, Int(Double(partyLevel) * 0.85) - 1 + rng.pick(-2...2))
        // Evolved forms are never below the level they evolve at: a lucky find.
        if let evolveLevel = species.evolveLevel { level = max(level, evolveLevel) }
        return min(level, cap, PokeMath.maxLevel)
    }

    /// Meeting one you already have is worth about a third of a level to it.
    static func duplicateXP(level: Int) -> Int { max(20, level * level) }
}

// MARK: Gacha

nonisolated struct GachaCard: Codable, Identifiable, Equatable, Sendable {
    enum Rarity: Int, Codable, Comparable, Sendable {
        case common, uncommon, rare, mythical

        static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }

        var weight: Double {
            switch self {
            case .common: 10
            case .uncommon: 5
            case .rare: 2.2
            case .mythical: 0.2
            }
        }
    }

    let id: UUID
    let species: Int
    let level: Int
    let rarity: Rarity
}

/// Three face-up cards; the user keeps one. Nothing can go wrong.
nonisolated enum Gacha {
    static let price = 400
    static let cardCount = 3
    /// A new journey starts with one pull's worth.
    static let startingCoins = price

    /// Every species met so far on the journey, plus gacha-only ones unlocked along the way.
    static func pool(progress: JourneyProgress, data: GameData) -> [(species: Int, rarity: GachaCard.Rarity)] {
        var best: [Int: Double] = [:]
        for (index, node) in data.nodes.enumerated() where node.isRoute && progress.hasReached(index) {
            for entry in data.encounters.pool(for: node, dex: data.dex) { best[entry.species] = max(best[entry.species] ?? 0, entry.share) }
        }
        var pool: [(species: Int, rarity: GachaCard.Rarity)] = best.map { species, share in
            (species, share >= 15 ? .common : (share >= 5 ? .uncommon : .rare))
        }
        for (species, after) in Kanto.gachaOnly {
            guard let index = data.nodeIndex(after), progress.hasReached(index), best[species] == nil else { continue }
            pool.append((species, .rare))
        }
        if progress.isChampion { pool.append((Kanto.mew, .mythical)) }
        return pool.sorted { $0.species < $1.species }
    }

    /// Three different species, weighted by rarity. Lines you already have come up less often
    /// (`duplicateWeight`), and not at all when it's 0.
    static func draw(pool: [(species: Int, rarity: GachaCard.Rarity)], level: (Int) -> Int, isOwned: (Int) -> Bool,
                     duplicateWeight: Double = 0.3, rng: inout SeededRNG) -> [GachaCard] {
        var remaining = pool.filter { duplicateWeight > 0 || !isOwned($0.species) }
        var cards: [GachaCard] = []
        while cards.count < cardCount,
              let index = rng.weighted(remaining.map { $0.rarity.weight * (isOwned($0.species) ? duplicateWeight : 1) }) {
            let entry = remaining.remove(at: index)
            cards.append(GachaCard(id: UUID(), species: entry.species, level: level(entry.species), rarity: entry.rarity))
        }
        return cards
    }

    /// Picking one you already have: about half a level for it.
    static func duplicateXP(level: Int) -> Int { max(40, 2 * level * level) }
}

// MARK: Rewards

nonisolated enum Rewards {
    static func coins(for kind: StagePlan.Kind) -> Int {
        switch kind {
        case .wild: 2
        case .trainer: 30
        case .legend: 60
        }
    }
}

// MARK: Party suggestions

nonisolated enum Recommend {
    struct Candidate: Sendable {
        let id: UUID
        let species: PokeSpecies
        let level: Int
    }

    /// The three best for a stage: against a trainer or legendary, whoever wins its matchups
    /// fastest while taking the least; against wild Pokémon, simply the strongest.
    static func party(from candidates: [Candidate], against foes: [StagePlan.Foe], data: GameData, size: Int = 3) -> [UUID] {
        func fighter(_ candidate: Candidate) -> Combatant {
            Combatant(species: candidate.species, level: candidate.level, moves: data.moves)
        }
        let opponents = foes.compactMap { foe in data.dex[foe.species].map { Combatant(species: $0, level: foe.level, moves: data.moves) } }
        func score(_ candidate: Candidate) -> Double {
            let me = fighter(candidate)
            guard !opponents.isEmpty else { return Double(candidate.level) * 1000 + Double(candidate.species.stats.total) }
            // Each matchup as the chance of winning it: how many turns each side needs, with
            // Struggle when nothing else lands, and the faster one getting the first hit.
            return opponents.reduce(0) { total, foe in
                let offense = best(from: me, to: foe) / Double(max(1, foe.maxHP))
                let defense = best(from: foe, to: me) / Double(max(1, me.maxHP))
                let mine = (1 / max(offense, 0.005)).rounded(.up) - (me.stats.speed >= foe.stats.speed ? 0.5 : 0)
                let theirs = (1 / max(defense, 0.005)).rounded(.up)
                return total + theirs / (mine + theirs)
            }
        }
        func best(from attacker: Combatant, to defender: Combatant) -> Double {
            let damage = attacker.moves.map { BattleState.expectedDamage($0, from: attacker, to: defender) }.max() ?? 0
            return damage > 0 ? damage : BattleState.expectedDamage(PokeMove.struggle, from: attacker, to: defender)
        }
        let ranked = candidates.map { ($0.id, score($0)) }.sorted { $0.1 > $1.1 }
        return ranked.prefix(size).map(\.0)
    }
}
