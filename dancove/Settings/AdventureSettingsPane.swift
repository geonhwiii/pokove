import SwiftUI

struct AdventureSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences
    @State private var confirmsReset = false

    var body: some View {
        @Bindable var preferences = preferences
        let adventure = app.adventure
        Form {
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.adventure.gradient)
                        if let leader = adventure.leader {
                            PokeIconView(id: leader.speciesID)
                        } else {
                            PokeBallGlyph(size: 18).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pokémon adventure")
                            .font(.headline)
                        Text("While Claude or Codex works, your party of up to three rides Kanto's stage lines, battling wild Pokémon. Gym leaders, legendaries and a daily dungeon are challenges you (or AUTO) start. New Pokémon turn up along the way, and stardust buys gacha pulls. Badges raise the level cap.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Toggle("Go on an adventure", isOn: $preferences.adventureEnabled)
                    .onChange(of: preferences.adventureEnabled) { _, enabled in
                        if !enabled { adventure.endAllTurns() }
                    }
                Toggle("Banners for new Pokémon, evolutions and badges", isOn: $preferences.adventureAnnounceCatches)
                    .disabled(!preferences.adventureEnabled)
                Toggle("Challenge bosses automatically (AUTO)", isOn: Bindable(adventure).autoChallenge)
                    .disabled(!preferences.adventureEnabled)
                Toggle("Play a sound for new Pokémon", isOn: $preferences.adventureSound)
                    .disabled(!preferences.adventureEnabled)
            }

            Section("Progress") {
                LabeledContent("Pokédex") {
                    Text("\(adventure.caught.count) caught · \(adventure.seen.count) seen / \(PokeDexStore.maxID)").monospacedDigit()
                }
                LabeledContent("Journey") {
                    Text(journey(adventure))
                }
                LabeledContent("Badges") {
                    HStack(spacing: 3) {
                        ForEach(1...8, id: \.self) { BadgeImageView(number: $0, size: 16, earned: adventure.progress.badges >= $0) }
                    }
                }
                LabeledContent("Stages cleared") {
                    Text("\(adventure.clears)").monospacedDigit()
                }
                LabeledContent("Stardust") {
                    Text("\(adventure.stardust)").monospacedDigit()
                }
                LabeledContent("Party") {
                    Text(adventure.party.compactMap { member in
                        adventure.dex.species(member.speciesID).map { "\($0.name) Lv \(member.level)" }
                    }.joined(separator: ", "))
                }
                HStack {
                    Spacer()
                    Button("Start Over…", role: .destructive) { confirmsReset = true }
                        .disabled(!adventure.hasStarted)
                }
            }

            Section("About the data") {
                Text("Pokémon data and sprites are downloaded from PokéAPI (pokeapi.co) while dancove runs and are cached on this Mac. None are bundled with dancove.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("An unofficial, non-commercial fan feature, not affiliated with or endorsed by Nintendo, Game Freak, Creatures Inc. or The Pokémon Company. Pokémon and all related names are their trademarks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("Start the adventure over?", isPresented: $confirmsReset) {
            Button("Start Over", role: .destructive) { adventure.resetAdventure() }
        } message: {
            Text("Your Pokémon, Pokédex and journey will be cleared. This can't be undone.")
        }
    }

    private func journey(_ adventure: AdventureService) -> String {
        let progress = adventure.progress
        if progress.isChampion { return String(localized: "Champion") }
        if progress.isBossOpen(adventure.chapters), let boss = adventure.nextBoss {
            return String(localized: "Chapter \(progress.chapter + 1) · \(boss.trainer.name) next")
        }
        return String(localized: "Chapter \(progress.chapter + 1) · station \(progress.station + 1)/\(Chapter.stationCount)")
    }
}
