import SwiftUI

struct FishingSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences
    @State private var confirmsReset = false

    var body: some View {
        @Bindable var preferences = preferences
        let fishing = app.fishing
        Form {
            Section {
                HStack(spacing: 14) {
                    PixelImage(key: "bobber", sprite: FishingArt.bobber, pixelSize: 5)
                        .frame(width: 40, height: 40)
                        .background(Color(hex: 0x1E4E9A).gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fishing while Claude works")
                            .font(.headline)
                        Text("Every Claude turn casts a line. Tool calls are nibbles, and when Claude finishes you reel in a catch. Longer, busier turns bring rarer fish.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                Toggle("Go fishing", isOn: $preferences.fishingEnabled)
                    .onChange(of: preferences.fishingEnabled) { _, enabled in
                        if !enabled { app.fishing.reelInAll() }
                    }
                if !preferences.claudeEnabled {
                    Text("Turn on the Claude integration to fish.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Toggle("Show catches on Claude's banners", isOn: $preferences.fishingAnnounceCatches)
                    .disabled(!preferences.fishingEnabled)
                Toggle("Play a sound for Unique catches and up", isOn: $preferences.fishingSound)
                    .disabled(!preferences.fishingEnabled)
            }

            Section("Collection") {
                LabeledContent("Species found") {
                    Text("\(fishing.caughtSpeciesCount) / \(FishCatalog.all.count)").monospacedDigit()
                }
                LabeledContent("Fish landed") {
                    Text("\(fishing.totalCatches)").monospacedDigit()
                }
                ForEach(FishRarity.allCases) { rarity in
                    LabeledContent {
                        Text("\(fishing.caughtCount(of: rarity)) / \(FishCatalog.species(of: rarity).count)")
                            .monospacedDigit()
                    } label: {
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 2).fill(rarity.color).frame(width: 8, height: 8)
                            Text(rarity.title)
                            Text(Self.odds(for: rarity))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !fishing.recent.isEmpty {
                Section("Recent catches") {
                    ForEach(fishing.recent.prefix(8)) { fish in
                        if let species = fish.species {
                            HStack(spacing: 10) {
                                FishSpriteView(species: species, pixelSize: 1.5)
                                    .frame(width: 40, height: 26)
                                    .background(species.rarity.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 5) {
                                        Text(species.name).fontWeight(.medium)
                                        if fish.isNew {
                                            Text("NEW")
                                                .font(.system(size: 9, weight: .black))
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Text([species.rarity.title, fish.project].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(FishCatch.format(size: fish.size)).monospacedDigit()
                                    Text(fish.date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Open Collection in Notch") { NotificationCenter.default.post(name: .dancoveOpenFishing, object: nil) }
                        .disabled(!preferences.claudeEnabled || !preferences.fishingEnabled)
                    Spacer()
                    Button("Reset Collection…", role: .destructive) { confirmsReset = true }
                        .disabled(fishing.totalCatches == 0)
                }
            }
        }
        .confirmationDialog("Reset the fishing collection?", isPresented: $confirmsReset) {
            Button("Reset Collection", role: .destructive) { fishing.resetCollection() }
        } message: {
            Text("Every species and record will be forgotten. This can't be undone.")
        }
    }

    /// Base chance per catch, before a long turn's luck bonus.
    private static func odds(for rarity: FishRarity) -> String {
        let total = FishRarity.allCases.reduce(0) { $0 + $1.baseWeight }
        let percent = rarity.baseWeight / total * 100
        return percent >= 1 ? String(format: "%.0f%%", percent) : String(format: "%.1f%%", percent)
    }
}

extension Notification.Name {
    /// Asks the notch windows to open on the fishing page.
    static let dancoveOpenFishing = Notification.Name("com.geonhwiii.dancove.openFishing")
}
