// Simulates the Kanto journey over many hours of agent work, to tune its pacing.
// Run from the repo root:
//   swiftc -O -parse-as-library -o /tmp/adventure-sim scripts/adventure-sim.swift \
//     dancove/Adventure/BattleEngine.swift dancove/Adventure/AdventureRules.swift \
//     dancove/Adventure/Kanto.swift dancove/Adventure/PokeMoves.swift dancove/Adventure/PokeDex.swift
//   /tmp/adventure-sim [hours] [xpScale] [starter] [seed]
//   /tmp/adventure-sim duel <node-id> <stage> <level> <species>...
// Data comes from the app's cache (~/Library/Application Support/dancove/pokemon) or PokéAPI.
import Foundation

@main
struct AdventureSim {
    struct Member {
        var speciesID: Int
        var xp: Int
        var banked = 0
        var level: Int { PokeMath.level(forXP: xp) }
    }

    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = PokeDexStore.defaultDirectory.appendingPathComponent(name)
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let hours = Double(args.first ?? "") ?? 70
        if args.count > 1, args[0] != "duel", let scale = Double(args[1]) { PokeMath.xpScale = scale }
        let starter = args.count > 2 ? Int(args[2]) ?? 4 : 4
        let seed = args.count > 3 ? UInt64(args[3]) ?? 42 : 42

        var species = load("dex-v1.json", as: [PokeSpecies].self)
        if species == nil { species = try await PokeAPI.fetchSpecies(maxID: PokeDexStore.maxID) }
        var moveDex = load("moves-v1.json", as: MoveDex.self)
        if moveDex == nil { moveDex = try await PokeAPI.fetchMoves(maxID: PokeDexStore.maxID) }
        var encounters = load("encounters-v1.json", as: EncounterDex.self)
        if encounters == nil { encounters = try await PokeAPI.fetchEncounters(areas: Array(Set(Kanto.main(starter: 4).flatMap(\.areas)))) }
        let moves = moveDex!
        let data = GameData(species: species!, moves: moves, encounters: encounters!, starter: starter)
        let dex = data.dex
        var rng = SeededRNG(seed: seed)

        // duel <node-id> <stage> <level> <species>...: win rate of a fixed party against one stage.
        if args.first == "duel", args.count >= 5 {
            let node = data.node(args[1])!
            let stage = Int(args[2])!, level = Int(args[3])!
            let team = args.dropFirst(4).compactMap { Int($0) }
            var wins = 0, actions = 0
            var log: [String] = []
            for round in 0..<200 {
                let plan = StagePlan.make(node: node, stage: stage, data: data, partyLevel: level, rng: &rng)
                let members = team.map { Combatant(species: dex[$0]!, level: level, moves: moves, ownedID: UUID()) }
                var battle = BattleState(plan: plan, party: members, data: data, seed: rng.next())
                while !battle.isOver {
                    let event = battle.step()
                    actions += 1
                    if round == 0, case .action(let action) = event {
                        let who = dex[battle.combatant(action.attackerID)!.speciesID]!.nameEn
                        log.append("\(who) \(action.move.nameEn) \(action.missed ? "miss" : "\(action.damage)") x\(action.effectiveness)\(action.targetFainted ? " KO" : "")")
                    }
                    if event == .cleared { wins += 1 }
                }
            }
            print(log.prefix(60).joined(separator: "\n"))
            print("wins \(wins)/200, \(Double(actions) / 200) ticks per battle")
            for member in team { print(dex[member]!.nameEn, moves.moveset(species: member, types: dex[member]!.types, level: level).map { "\($0.nameEn) \($0.power ?? 0)" }) }
            return
        }

        var box: [UUID: Member] = [UUID(): Member(speciesID: starter, xp: PokeMath.xp(forLevel: 5))]
        var progress = JourneyProgress()
        var coins = Gacha.startingCoins, pulls = 0, discoveries = 0, wipes = 0, clears = 0
        let secondsPerTick = 1.5
        let totalTicks = Int(hours * 3600 / secondsPerTick)
        var battle: BattleState?
        var target = BattleTarget.stage(.start)
        var marks: [Double] = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 20, 24, 30, 36, 42, 48, 56, 64, 72, 84, 96].filter { $0 <= hours }
        var events: [String] = []
        var tried: Set<String> = []

        func cap() -> Int { Kanto.levelCap(badges: progress.badges, champion: progress.isChampion) }
        func grant(_ xp: Int, to id: UUID) {
            guard var member = box[id] else { return }
            let limit = PokeMath.xpLimit(cap: cap())
            let total = member.xp + xp
            member.xp = min(total, limit)
            member.banked += max(0, total - limit)
            while let next = dex.evolutions(member.speciesID).compactMap({ dex[$0] }).first(where: { ($0.evolveLevel ?? 999) <= member.level }) {
                member.speciesID = next.id
            }
            box[id] = member
        }
        func releaseBank() {
            for id in box.keys { let banked = box[id]!.banked; box[id]!.banked = 0; grant(banked, to: id) }
        }
        /// A sensible player: the suggested party for whatever comes next.
        func party() -> [UUID] {
            let candidates = box.map { Recommend.Candidate(id: $0.key, species: dex[$0.value.speciesID]!, level: $0.value.level) }
            var foes: [StagePlan.Foe] = []
            var scratch = SeededRNG(seed: 1)
            if let legend = progress.legend {
                foes = StagePlan.make(node: data.node(legend)!, stage: 0, data: data, partyLevel: 100, rng: &scratch).foes
            } else if !progress.isComplete(data.nodes), !data.nodes[progress.frontier.node].isRoute {
                foes = StagePlan.make(node: data.nodes[progress.frontier.node], stage: progress.frontier.stage, data: data, partyLevel: 100, rng: &scratch).foes
            }
            return Recommend.party(from: candidates, against: foes, data: data)
        }
        func signature() -> String { party().map { "\(box[$0]!.speciesID):\(box[$0]!.level)" }.joined(separator: ",") }
        var forecasts: [String: Double] = [:]
        /// The forecast against the trainer at the frontier, for AUTO.
        func readiness() -> Double {
            guard !progress.isComplete(data.nodes), !data.nodes[progress.frontier.node].isRoute else { return 1 }
            let key = signature() + "@\(progress.frontier.node).\(progress.frontier.stage)"
            if let known = forecasts[key] { return known }
            var scratch = SeededRNG(seed: 1)
            let plan = StagePlan.make(node: data.nodes[progress.frontier.node], stage: progress.frontier.stage, data: data, partyLevel: 100, rng: &scratch)
            let members = party().map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, moves: moves, ownedID: $0) }
            let chance = Forecast.winChance(party: members, plan: plan, data: data)
            forecasts[key] = chance
            return chance
        }
        func partyLevel() -> Int { let ids = party(); return ids.map { box[$0]!.level }.reduce(0, +) / max(1, ids.count) }
        func receive(_ speciesID: Int, level: Int, duplicateXP: Int) -> Bool {
            if let owned = box.first(where: { $0.value.speciesID == speciesID || dex.evolutions(speciesID).contains($0.value.speciesID) })?.key {
                grant(duplicateXP, to: owned)
                return false
            }
            box[UUID()] = Member(speciesID: speciesID, xp: PokeMath.xp(forLevel: level))
            return true
        }

        for tick in 0..<totalTicks {
            if battle == nil {
                target = progress.target(data.nodes, auto: true, readiness: readiness())
                let plan: StagePlan
                switch target {
                case .stage(let point): plan = StagePlan.make(node: data.nodes[point.node], stage: point.stage, data: data, partyLevel: partyLevel(), rng: &rng)
                case .legend(let id): plan = StagePlan.make(node: data.node(id)!, stage: 0, data: data, partyLevel: partyLevel(), rng: &rng)
                }
                let members = party().map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, moves: moves, ownedID: $0) }
                battle = BattleState(plan: plan, party: members, data: data, seed: rng.next())
            }
            let event = battle!.step()
            switch event {
            case .action(let action) where action.byParty && action.targetFainted:
                if let foe = battle!.combatant(action.targetID), let species = dex[foe.speciesID] {
                    let xp = PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: partyLevel(), kind: battle!.plan.kind)
                    for member in battle!.party { if let id = member.ownedID { grant(xp, to: id) } }
                }
            case .cleared:
                clears += 1
                coins += Rewards.coins(for: battle!.plan.kind)
                let outcome = progress.record(target, cleared: true, nodes: data.nodes)
                let hour = Double(tick) * secondsPerTick / 3600
                switch outcome {
                case .badge(let badge):
                    releaseBank()
                    events.append(String(format: "%5.1fh badge %d (%@)", hour, badge, battle!.plan.node.nameEn))
                case .champion:
                    releaseBank()
                    events.append(String(format: "%5.1fh CHAMPION", hour))
                case .legend(let id):
                    if case .legend(let speciesID, let level, _) = data.node(id)!.kind {
                        _ = receive(speciesID, level: min(level, cap()), duplicateXP: 0)
                        events.append(String(format: "%5.1fh legend %@", hour, dex[speciesID]!.nameEn))
                    }
                default: break
                }
                battle = nil
            case .wiped:
                if ProcessInfo.processInfo.environment["SIM_TRACE"] != nil, Double(tick) * secondsPerTick / 3600 < (Double(ProcessInfo.processInfo.environment["SIM_TRACE"] ?? "") ?? 0) {
                    print("wipe at", target, battle!.plan.node.nameEn, battle!.plan.stage, battle!.party.map { "\(dex[$0.speciesID]!.nameEn) \($0.level)" })
                }
                wipes += 1
                progress.record(target, cleared: false, nodes: data.nodes)
                battle = nil
            default: break
            }
            // Legendaries: a player takes them on once the party looks ready.
            if battle == nil, progress.legend == nil {
                for legend in Kanto.legends where !progress.beatenLegends.contains(legend.id) && progress.isReached(legend: legend, in: data.nodes) {
                    if case .legend(_, let level, _) = legend.kind, partyLevel() >= level - 2, !tried.contains(legend.id) || tick % 20000 == 0 {
                        progress.legend = legend.id
                        tried.insert(legend.id)
                        break
                    }
                }
            }
            // Discovery.
            if rng.unit() < secondsPerTick / Discovery.meanInterval(boxCount: box.count) {
                let pool = Discovery.pool(for: target, progress: progress, data: data)
                if let speciesID = Discovery.roll(pool: pool, rng: &rng), let species = dex[speciesID] {
                    let level = Discovery.level(of: species, partyLevel: partyLevel(), cap: cap(), rng: &rng)
                    if receive(speciesID, level: level, duplicateXP: Discovery.duplicateXP(level: level)) { discoveries += 1 }
                }
            }
            // Gacha: pull whenever affordable, keep the strongest new card.
            if coins >= Gacha.price {
                coins -= Gacha.price
                pulls += 1
                let pool = Gacha.pool(progress: progress, data: data)
                let level = partyLevel()
                var levelRNG = SeededRNG(seed: rng.next())
                let lines = Set(box.values.map { dex.base(of: $0.speciesID) })
                let cards = Gacha.draw(pool: pool, level: { id in Discovery.level(of: dex[id]!, partyLevel: level, cap: cap(), rng: &levelRNG) },
                                       isOwned: { lines.contains(dex.base(of: $0)) }, duplicateWeight: pulls == 1 ? 0 : 0.3, rng: &rng)
                let owned = Set(box.values.map(\.speciesID))
                let pick = cards.filter { !owned.contains($0.species) }.max { dex[$0.species]!.stats.total < dex[$1.species]!.stats.total } ?? cards.first
                if let pick { _ = receive(pick.species, level: pick.level, duplicateXP: Gacha.duplicateXP(level: pick.level)) }
            }

            let hour = Double(tick) * secondsPerTick / 3600
            if let mark = marks.first, hour >= mark {
                marks.removeFirst()
                let names = party().map { "\(dex[box[$0]!.speciesID]!.nameEn) \(box[$0]!.level)" }.joined(separator: ", ")
                let place = progress.isComplete(data.nodes) ? "done" : "\(data.nodes[progress.frontier.node].nameEn) \(progress.frontier.stage + 1)"
                print(String(format: "%5.1fh  %-22@ badges %d cap %2d  wipes %4d  clears %5d  box %3d  pulls %3d  disc %3d  | %@",
                             mark, place as NSString, progress.badges, cap(), wipes, clears, Set(box.values.map(\.speciesID)).count,
                             pulls, discoveries, names))
            }
        }
        print(events.joined(separator: "\n"))
    }
}
