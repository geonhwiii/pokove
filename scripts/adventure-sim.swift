// Simulates the Kanto journey over many hours of agent work, to tune its pacing.
// Run from the repo root:
//   swiftc -O -parse-as-library -o /tmp/adventure-sim scripts/adventure-sim.swift \
//     pokove/Adventure/BattleEngine.swift pokove/Adventure/AdventureRules.swift \
//     pokove/Adventure/Kanto.swift pokove/Adventure/PokeMoves.swift pokove/Adventure/PokeDex.swift
//   /tmp/adventure-sim [hours] [xpScale] [starter] [seed] [agentHoursPerDay]
//   /tmp/adventure-sim duel <chapter> <station 1-10 | b1-b5> <level> <species>...
// Stations run on agent time (1.5 s per action). Gyms, legendaries and the daily dungeons don't need
// an agent, so they cost no agent time here. The player takes a gym on once the forecast says 60%
// (SIM_TRY=0.4 for a bolder one), or every hour or so once the party is stuck at the level cap; the
// League's five run back to back.
// Data comes from the app's cache (~/Library/Application Support/pokove/pokemon) or PokéAPI.
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
        let isDuel = args.first == "duel"
        let hours = isDuel ? 0 : Double(args.first ?? "") ?? 70
        if !isDuel, args.count > 1, let scale = Double(args[1]) { PokeMath.xpScale = scale }
        // SIM_WINS sets the wild wins a station takes per level of it.
        if let wins = Double(ProcessInfo.processInfo.environment["SIM_WINS"] ?? "") { Chapter.winsPerLevel = wins }
        let starter = !isDuel && args.count > 2 ? Int(args[2]) ?? 4 : 4
        let seed = !isDuel && args.count > 3 ? UInt64(args[3]) ?? 42 : 42
        let hoursPerDay = !isDuel && args.count > 4 ? Double(args[4]) ?? 2.9 : 2.9

        var species = load("dex-v1.json", as: [PokeSpecies].self)
        if species == nil { species = try await PokeAPI.fetchSpecies(maxID: PokeDexStore.maxID) }
        var moveDex = load("moves-v2.json", as: MoveDex.self)
        if moveDex == nil { moveDex = try await PokeAPI.fetchMoves(maxID: PokeDexStore.maxID) }
        var encounters = load("encounters-v1.json", as: EncounterDex.self)
        if encounters == nil { encounters = try await PokeAPI.fetchEncounters(areas: PokeDexStore.journeyAreas) }
        let moves = moveDex!
        let data = GameData(species: species!, moves: moves, encounters: encounters!, starter: starter)
        let chapters = data.chapters
        let dex = data.dex
        var rng = SeededRNG(seed: seed)

        // duel <chapter> <station | bN> <level> <species>...: win rate of a fixed party.
        if isDuel, args.count >= 5 {
            let chapter = chapters[Int(args[1])! - 1]
            let level = Int(args[3])!
            let team = args.dropFirst(4).compactMap { Int($0) }
            var wins = 0, actions = 0
            var log: [String] = []
            for round in 0..<200 {
                let plan: StagePlan
                if args[2].hasPrefix("b") {
                    plan = StagePlan.boss(chapter.bosses[Int(args[2].dropFirst())! - 1], scenery: chapter.bossScenery)
                } else {
                    let index = Int(args[2])! - 1
                    plan = StagePlan.station(chapter.stations[index], isLast: index == Chapter.stationCount - 1, data: data,
                                             partyLevel: level, rng: &rng)
                }
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
        var stardust = Gacha.startingStardust, ultraBalls = 0, pulls = 0, discoveries = 0, wipes = 0, clears = 0
        var bossTries = 0, dungeonDays = 0, dungeonRuns = 0, dungeonStardust = 0, dungeonXP = 0, dungeonUltraBalls = 0
        var dungeons = DungeonState(day: "")
        let secondsPerTick = 1.5
        let totalTicks = Int(hours * 3600 / secondsPerTick)
        let ticksPerDay = Int(hoursPerDay * 3600 / secondsPerTick)
        var battle: BattleState?
        var target = BattleTarget.station(StationPoint(chapter: 0, station: 0))
        var marks: [Double] = [0.25, 0.5, 1, 2, 3, 4, 6, 8, 12, 16, 20, 24, 30, 36, 42, 48, 56, 64, 72, 84, 96].filter { $0 <= hours }
        var events: [String] = []
        // A calendar day starting on a Monday, advanced once per `hoursPerDay` of agent work.
        var day = Date(timeIntervalSince1970: 1_790_000_000)

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
        func bossPlan() -> StagePlan? {
            guard let next = progress.nextBoss(chapters) else { return nil }
            return StagePlan.boss(chapters[next.chapter].bosses[next.index], scenery: chapters[next.chapter].bossScenery)
        }
        /// A sensible player: the suggested party for whatever comes next.
        func party(against foes: [StagePlan.Foe]? = nil) -> [UUID] {
            let candidates = box.map { Recommend.Candidate(id: $0.key, species: dex[$0.value.speciesID]!, level: $0.value.level) }
            return Recommend.party(from: candidates, against: foes ?? bossPlan()?.foes ?? [], data: data)
        }
        func partyLevel(_ ids: [UUID]? = nil) -> Int { let ids = ids ?? party(); return ids.map { box[$0]!.level }.reduce(0, +) / max(1, ids.count) }
        func receive(_ speciesID: Int, level: Int, duplicateXP: Int) -> Bool {
            if let owned = box.first(where: { dex.base(of: $0.value.speciesID) == dex.base(of: speciesID) })?.key {
                grant(duplicateXP, to: owned)
                return false
            }
            box[UUID()] = Member(speciesID: speciesID, xp: PokeMath.xp(forLevel: level))
            return true
        }
        /// Plays a challenge out at once; experience only counts on a win.
        func challenge(_ plan: StagePlan, ids: [UUID]) -> Bool {
            let members = ids.map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, moves: moves, ownedID: $0) }
            var fight = BattleState(plan: plan, party: members, data: data, seed: rng.next())
            var xp = 0
            let level = partyLevel(ids)
            while !fight.isOver {
                switch fight.step() {
                case .action(let action) where action.byParty && action.targetFainted:
                    if let foe = fight.combatant(action.targetID), let species = dex[foe.speciesID] {
                        xp += PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: level, kind: plan.kind)
                    }
                case .cleared:
                    for id in ids { grant(xp, to: id) }
                    return true
                default: break
                }
            }
            return false
        }
        var forecasts: [String: Double] = [:]
        /// The forecast against the next boss with the suggested party.
        func readiness() -> Double {
            guard let plan = bossPlan() else { return 0 }
            let ids = party()
            let next = progress.nextBoss(chapters).map { "\($0.chapter).\($0.index)" } ?? "-"
            let key = ids.map { "\(box[$0]!.speciesID):\(box[$0]!.level)" }.joined(separator: ",") + "@" + next
            if let known = forecasts[key] { return known }
            let members = ids.map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, moves: moves, ownedID: $0) }
            let chance = Forecast.winChance(party: members, plan: plan, data: data)
            forecasts[key] = chance
            return chance
        }
        func hour(_ tick: Int) -> Double { Double(tick) * secondsPerTick / 3600 }
        var lastBossTry = -1_000_000
        let tryAt = Double(ProcessInfo.processInfo.environment["SIM_TRY"] ?? "") ?? Guidance.goodChance
        func fightBoss(_ tick: Int) {
            lastBossTry = tick
            bossTries += 1
            while let plan = bossPlan() {
                let won = challenge(plan, ids: party())
                if !won { wipes += 1 }
                stardust += won ? Rewards.stardust(for: plan.kind) : 0
                switch progress.recordBoss(cleared: won, chapters: chapters) {
                case .badge(let badge):
                    releaseBank()
                    events.append(String(format: "%5.1fh badge %d after %d tries (line at %d-%d)", hour(tick), badge, bossTries,
                                         progress.chapter + 1, min(progress.station + 1, Chapter.stationCount)))
                    bossTries = 0
                    return
                case .champion:
                    releaseBank()
                    events.append(String(format: "%5.1fh CHAMPION after %d tries", hour(tick), bossTries))
                    return
                case .advanced:
                    continue
                default:
                    return
                }
            }
        }
        /// Every party member at the cap: waiting won't make it stronger.
        func stuckAtCap() -> Bool { party().allSatisfy { box[$0]!.level >= cap() } }

        for tick in 0..<totalTicks {
            // A new day: each dungeon climbs until a new stage beats the party, then spends what's
            // left on its best stage.
            if tick % ticksPerDay == 0 {
                dungeons.refill(for: DailyDungeon.day(of: day))
                for kind in DungeonKind.allCases {
                    var stuck = false
                    while dungeons[kind].tries > 0 {
                        let climb = dungeons[kind]
                        guard let stage = stuck || climb.next == nil ? (climb.best > 0 ? climb.best : climb.next) : climb.next else { break }
                        let plan = DailyDungeon.plan(kind, stage: stage, on: day, data: data)
                        dungeonRuns += 1
                        let ids = party(against: plan.foes)
                        let won = challenge(plan, ids: ids)
                        if !won, ProcessInfo.processInfo.environment["SIM_DUNGEON"] != nil {
                            print("\(kind) stage \(stage) lost day \(dungeonDays):", plan.foes.map { "\(dex[$0.species]!.nameEn) \($0.level)" },
                                  "vs", ids.map { "\(dex[box[$0]!.speciesID]!.nameEn) \(box[$0]!.level)" })
                        }
                        let isNew = dungeons.record(kind, stage: stage, cleared: won)
                        if !won, stage == climb.next { stuck = true }
                        guard won else { continue }
                        switch kind {
                        case .stardust:
                            stardust += DailyDungeon.stardust(stage: stage)
                            dungeonStardust += DailyDungeon.stardust(stage: stage)
                            if isNew, DailyDungeon.paysUltraBall(stage: stage) { ultraBalls += 1; dungeonUltraBalls += 1 }
                        case .experience:
                            // SIM_DUNGEON_XP scales the experience dungeon's reward, to try others.
                            let share = Double(ProcessInfo.processInfo.environment["SIM_DUNGEON_XP"] ?? "") ?? 1
                            let xp = Int(Double(DailyDungeon.experience(stage: stage)) * share)
                            dungeonXP += xp
                            for id in ids { grant(xp, to: id) }
                        }
                    }
                }
                day = day.addingTimeInterval(86_400)
                dungeonDays += 1
            }
            if battle == nil {
                if progress.isBossOpen(chapters), tick - lastBossTry >= 400,
                   readiness() >= tryAt || (stuckAtCap() && tick - lastBossTry >= 2400) {
                    fightBoss(tick)
                }
                let point = progress.stationTarget(chapters)
                target = .station(point)
                let ids = party()
                let plan = StagePlan.station(chapters[point.chapter].stations[point.station], isLast: point.station == Chapter.stationCount - 1,
                                             data: data, partyLevel: partyLevel(ids), rng: &rng)
                let members = ids.map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, moves: moves, ownedID: $0) }
                battle = BattleState(plan: plan, party: members, data: data, seed: rng.next())
            }
            let event = battle!.step()
            switch event {
            case .action(let action) where action.byParty && action.targetFainted:
                if let foe = battle!.combatant(action.targetID), let species = dex[foe.speciesID] {
                    let xp = PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: partyLevel(), kind: battle!.plan.kind)
                    for member in battle!.party { if let id = member.ownedID { grant(xp, to: id) } }
                }
            case .status(let status) where !status.onParty && status.fainted:
                if let foe = battle!.combatant(status.targetID), let species = dex[foe.speciesID] {
                    let xp = PokeMath.defeatXP(baseExperience: species.baseExperience, level: foe.level, partyLevel: partyLevel(), kind: battle!.plan.kind)
                    for member in battle!.party { if let id = member.ownedID { grant(xp, to: id) } }
                }
            case .cleared:
                clears += 1
                stardust += Rewards.stardust(for: battle!.plan.kind)
                if case .station(let point) = target {
                    progress.recordStation(point, cleared: true, defeated: battle!.plan.foes.count, chapters: chapters)
                }
                battle = nil
            case .wiped:
                if ProcessInfo.processInfo.environment["SIM_TRACE"] != nil, hour(tick) < (Double(ProcessInfo.processInfo.environment["SIM_TRACE"] ?? "") ?? 0) {
                    print("wipe at", target, battle!.party.map { "\(dex[$0.speciesID]!.nameEn) \($0.level)" })
                }
                wipes += 1
                if case .station(let point) = target { progress.recordStation(point, cleared: false, chapters: chapters) }
                battle = nil
            default: break
            }
            // Legendaries: a player takes them on once the party looks ready.
            if battle == nil {
                for (index, chapter) in chapters.enumerated() where progress.hasReached(chapter: index) {
                    guard let legend = chapter.legend, !progress.beatenLegends.contains(legend.id), partyLevel() >= legend.level - 2,
                          tick % 2000 == 0 else { continue }
                    let plan = StagePlan.legend(legend)
                    if challenge(plan, ids: party(against: plan.foes)) {
                        progress.recordLegend(legend.id, cleared: true)
                        stardust += Rewards.stardust(for: .legend)
                        _ = receive(legend.species, level: min(legend.level, cap()), duplicateXP: 0)
                        events.append(String(format: "%5.1fh legend %@", hour(tick), dex[legend.species]!.nameEn))
                    }
                }
            }
            // Discovery.
            if rng.unit() < secondsPerTick / Discovery.meanInterval(boxCount: box.count) {
                let pool = Discovery.pool(at: progress.stationTarget(chapters), data: data)
                if let speciesID = Discovery.roll(pool: pool, rng: &rng), let species = dex[speciesID] {
                    let level = Discovery.level(of: species, partyLevel: partyLevel(), cap: cap(), rng: &rng)
                    if receive(speciesID, level: level, duplicateXP: Discovery.duplicateXP(level: level)) { discoveries += 1 }
                }
            }
            // Gacha: pull whenever affordable, keep the strongest new card.
            while stardust >= Gacha.price || ultraBalls > 0 {
                let ultra = ultraBalls > 0
                if ultra { ultraBalls -= 1 } else { stardust -= Gacha.price }
                pulls += 1
                let pool = Gacha.pool(progress: progress, data: data)
                let level = partyLevel()
                var levelRNG = SeededRNG(seed: rng.next())
                let lines = Set(box.values.map { dex.base(of: $0.speciesID) })
                let cards = Gacha.draw(pool: pool, level: { id in Discovery.level(of: dex[id]!, partyLevel: level, cap: cap(), rng: &levelRNG) },
                                       isOwned: { lines.contains(dex.base(of: $0)) }, duplicateWeight: pulls == 1 ? 0 : 0.3,
                                       floor: ultra ? .rare : .common, rng: &rng)
                let pick = cards.filter { !lines.contains(dex.base(of: $0.species)) }.max { dex[$0.species]!.stats.total < dex[$1.species]!.stats.total } ?? cards.first
                if let pick { _ = receive(pick.species, level: pick.level, duplicateXP: Gacha.duplicateXP(level: pick.level)) }
            }

            if let mark = marks.first, hour(tick) >= mark {
                marks.removeFirst()
                let names = party().map { "\(dex[box[$0]!.speciesID]!.nameEn) \(box[$0]!.level)" }.joined(separator: ", ")
                let place = "\(progress.chapter + 1)-\(min(progress.station + 1, Chapter.stationCount))\(progress.isLooping ? " loop" : "")"
                print(String(format: "%5.1fh  %-10@ badges %d cap %2d  wipes %4d  clears %5d  box %3d  pulls %3d  disc %3d  | %@",
                             mark, place as NSString, progress.badges, cap(), wipes, clears, Set(box.values.map(\.speciesID)).count,
                             pulls, discoveries, names))
            }
        }
        print(events.joined(separator: "\n"))
        print("dungeons over \(dungeonDays) days: stardust stage \(dungeons.stardust.best), experience stage \(dungeons.experience.best); "
              + "\(dungeonRuns) runs, \(dungeonStardust) stardust (\(dungeonStardust / max(1, dungeonDays))/day), "
              + "\(dungeonUltraBalls) Ultra Balls, \(dungeonXP) EXP each")
    }
}
