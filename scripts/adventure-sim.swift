// Simulates the adventure over many hours of agent work, to tune its pacing.
// Run from the repo root:
//   swiftc -O -parse-as-library -o /tmp/adventure-sim scripts/adventure-sim.swift \
//     dancove/Adventure/BattleEngine.swift dancove/Adventure/PokeDex.swift
//   /tmp/adventure-sim [hours] [xpScale] [secondsPerTick] [turnMinutes]
import Foundation

@main
struct AdventureSim {
    struct Member { var speciesID: Int; var xp: Int; var level: Int { PokeMath.level(forXP: xp) } }

    static func main() async throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let hours = Double(args.first ?? "") ?? 60
        if args.count > 1, let scale = Double(args[1]) { PokeMath.xpScale = scale }
        let secondsPerTick = args.count > 2 ? Double(args[2]) ?? 1.5 : 1.5
        let turnMinutes = args.count > 3 ? Double(args[3]) ?? 4 : 4
        let dex = DexView(try await PokeAPI.fetchSpecies(maxID: PokeDexStore.maxID))
        var rng = SeededRNG(seed: 42)

        var box: [UUID: Member] = [UUID(): Member(speciesID: 4, xp: PokeMath.xp(forLevel: 5))]
        var progress = StageProgress()
        var wipes = 0
        let ticksPerTurn = Int(turnMinutes * 60 / secondsPerTick)
        let totalTicks = Int(hours * 3600 / secondsPerTick)
        var battle: BattleState?
        var marks: [Double] = [0.5, 1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 200, 300].filter { $0 <= hours }

        func party() -> [UUID] {
            box.sorted { ($0.value.level, dex[$0.value.speciesID]!.stats.total) > ($1.value.level, dex[$1.value.speciesID]!.stats.total) }
                .prefix(3).map(\.key)
        }
        func evolve(_ id: UUID) {
            guard var member = box[id] else { return }
            while let next = dex.evolutions(member.speciesID).compactMap({ dex[$0] }).first(where: { ($0.evolveLevel ?? 999) <= member.level }) {
                member.speciesID = next.id
            }
            box[id] = member
        }

        for tick in 0..<totalTicks {
            if battle == nil {
                let members = party().map { Combatant(species: dex[box[$0]!.speciesID]!, level: box[$0]!.level, ownedID: $0) }
                battle = BattleState(plan: StagePlan.make(for: progress.current, dex: dex), party: members, dex: dex, seed: rng.next())
            }
            let event = battle!.step(dex: dex)
            if case .attack(let hit) = event, hit.byParty, hit.fainted, let enemy = battle!.combatant(hit.targetID), let species = dex[enemy.speciesID] {
                let xp = PokeMath.defeatXP(baseExperience: species.baseExperience, level: enemy.level, boss: enemy.isBoss)
                for member in battle!.party { if let id = member.ownedID { box[id]?.xp += xp; evolve(id) } }
            }
            if case .stageCleared = event { progress.record(cleared: true); battle = nil }
            if case .wiped = event { wipes += 1; progress.record(cleared: false); battle = nil }
            if tick % ticksPerTurn == ticksPerTurn - 1, rng.unit() < WildEncounter.encounterChance,
               let wild = WildEncounter.roll(dex: dex, partyLevel: party().map { box[$0]!.level }.reduce(0, +) / max(1, party().count), rng: &rng), let species = dex[wild.speciesID],
               rng.unit() < WildEncounter.captureChance(of: species) {
                if let owned = box.first(where: { $0.value.speciesID == wild.speciesID })?.key {
                    box[owned]!.xp += WildEncounter.duplicateXP(level: wild.level)
                    evolve(owned)
                } else {
                    box[UUID()] = Member(speciesID: wild.speciesID, xp: PokeMath.xp(forLevel: wild.level))
                }
            }
            let hour = Double(tick) * secondsPerTick / 3600
            if let mark = marks.first, hour >= mark {
                marks.removeFirst()
                let names = party().map { "\(dex[box[$0]!.speciesID]!.nameEn) \(box[$0]!.level)" }.joined(separator: ", ")
                let species = Set(box.values.map(\.speciesID)).count
                print(String(format: "%6.1fh  stage %-6@ wipes %5d  species %3d  party: %@", mark, progress.frontier.label, wipes, species, names))
            }
        }
    }
}
