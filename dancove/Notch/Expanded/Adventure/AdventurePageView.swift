import SwiftUI

extension Color {
    /// The adventure's warm red-orange, for tabs, badges and banners.
    static let adventure = Color(red: 1.0, green: 0.48, blue: 0.27)
}

extension Notification.Name {
    static let dancoveOpenAdventure = Notification.Name("com.geonhwiii.dancove.openAdventure")
    #if DEBUG
    static let dancoveDebugSelectPokemon = Notification.Name("dancoveDebugSelectPokemon")
    static let dancoveDebugAdventurePane = Notification.Name("dancoveDebugAdventurePane")
    static let dancoveDebugOpenBall = Notification.Name("dancoveDebugOpenBall")
    static let dancoveDebugChallengeMode = Notification.Name("dancoveDebugChallengeMode")
    #endif
}

/// Which view fills the right half of the adventure page.
enum AdventurePane: String, CaseIterable {
    case challenge, dex, gacha

    var title: String {
        switch self {
        case .challenge: String(localized: "Challenge")
        case .dex: String(localized: "Pokédex")
        case .gacha: String(localized: "Gacha")
        }
    }
}

/// The adventure page: the battle and party on the left; the challenges, Pokédex or gacha on the right.
struct AdventurePageView: View {
    @Environment(AppModel.self) private var app
    /// The species whose details replace the battle scene.
    @State private var selection: Int?
    @AppStorage("adventurePane") private var pane: AdventurePane = .challenge
    @State private var showsRecap = false

    var body: some View {
        let adventure = app.adventure
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    switch adventure.dex.state {
                    case .ready:
                        if let id = selection, let species = adventure.dex.species(id) {
                            PokeDetailCard(species: species) { selection = nil }
                                .id(id)
                                .transition(.blurReplace)
                        } else if !adventure.hasStarted {
                            StarterPicker()
                                .transition(.blurReplace)
                        } else {
                            BattleSceneView()
                                .transition(.blurReplace)
                        }
                    case .failed:
                        DexUnavailable()
                    case .idle, .loading:
                        DexLoading()
                    }
                }
                .frame(height: BattleSceneView.height)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    if showsRecap, selection == nil, !adventure.recap.isEmpty {
                        RecapCard { dismissRecap() }
                            .padding(6)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .animation(.smooth(duration: 0.28), value: selection)

                PartyBar(selection: $selection)
            }
            .frame(minWidth: 226, maxWidth: 262)

            VStack(alignment: .leading, spacing: 6) {
                PaneTabs(pane: $pane)
                switch pane {
                case .challenge: ChallengeView()
                case .dex: DexGrid(selection: $selection)
                case .gacha: GachaView()
                }
            }
            .frame(width: 216)
            .disabled(!adventure.hasStarted)
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            adventure.dex.load()
            adventure.isWatching = true
            showsRecap = !adventure.recap.isEmpty
        }
        .onDisappear { adventure.isWatching = false }
        .task(id: showsRecap) {
            // Only a full eight seconds on screen counts as seen; leaving early keeps it for next time.
            guard showsRecap, (try? await Task.sleep(for: .seconds(8))) != nil else { return }
            dismissRecap()
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .dancoveDebugSelectPokemon)) { note in
            selection = note.object as? Int
        }
        .onReceive(NotificationCenter.default.publisher(for: .dancoveDebugAdventurePane)) { note in
            if let raw = note.object as? String, let value = AdventurePane(rawValue: raw) { pane = value }
            if note.object as? String == "recap" { showsRecap = true }
        }
        #endif
    }
}

extension AdventurePageView {
    private func dismissRecap() {
        withAnimation(.smooth(duration: 0.3)) { showsRecap = false }
        app.adventure.markRecapSeen()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Challenge, Pokédex and Gacha tabs, with the stardust purse.
private struct PaneTabs: View {
    @Binding var pane: AdventurePane
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        HStack(spacing: 3) {
            ForEach(AdventurePane.allCases, id: \.self) { item in
                Button {
                    withAnimation(.smooth(duration: 0.2)) { pane = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(pane == item ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .frame(height: 19)
                        .background(pane == item ? .white.opacity(0.14) : .clear, in: Capsule())
                        .overlay(alignment: .topTrailing) {
                            if item == .gacha, adventure.hasGachaWaiting {
                                Circle().fill(Color(hex: 0xFFD35A)).frame(width: 5, height: 5).offset(x: -1, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 2)
            BannerToggle()
            HStack(spacing: 3) {
                StardustIcon(size: 11)
                Text("\(adventure.stardust)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
            }
            .help("Stardust, from stations, bosses and the dungeon. \(Gacha.price) buy three Poké Balls.")
        }
    }
}

/// Mutes the adventure's banners and sounds in one click, say before sharing a screen.
private struct BannerToggle: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let preferences = app.preferences
        let on = preferences.adventureAnnounceCatches
        Button {
            preferences.adventureAnnounceCatches.toggle()
        } label: {
            Image(systemName: on ? "bell.fill" : "bell.slash.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(on ? .white.opacity(0.55) : Color(hex: 0xFF8A70))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(on ? "Adventure banners are on. Click to mute them, say before sharing your screen." : "Adventure banners are muted. Click to turn them back on.")
    }
}

/// "While you were away": what the agents' work and the challenges earned since the page was last open.
private struct RecapCard: View {
    let close: () -> Void
    @Environment(AppModel.self) private var app

    var body: some View {
        let recap = app.adventure.recap
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("While you were away")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 7.5, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 5) {
                if recap.clears > 0 { chip(symbol: "flag.fill", text: "\(recap.clears)") }
                if recap.stardust > 0 {
                    HStack(spacing: 3) { StardustIcon(size: 9); Text("+\(recap.stardust)") }.modifier(RecapChip())
                }
                if recap.levels > 0 { chip(symbol: "arrow.up", text: "Lv +\(recap.levels)") }
                if !recap.learned.isEmpty { chip(symbol: "bolt.fill", text: String(localized: "\(recap.learned.count) moves")) }
                ForEach(recap.badges, id: \.self) { BadgeImageView(number: $0, size: 13) }
                ForEach(recap.dungeon, id: \.self) { tier in chip(symbol: "door.left.hand.open", text: tier.title) }
            }
            if let stuck = recap.stuck, let trainer = trainer(stuck) {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(Color(hex: 0xFFB070))
                    Text("\(trainer.name) keeps winning. Try the best team.")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { app.adventure.recommendParty() }
                    } label: {
                        Image(systemName: "wand.and.stars").font(.system(size: 8, weight: .bold)).foregroundStyle(.black)
                            .frame(width: 20, height: 14)
                            .background(Color(hex: 0xFFD35A), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            if !recap.discovered.isEmpty || !recap.evolved.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array((recap.discovered + recap.evolved).suffix(8).enumerated()), id: \.offset) { _, id in
                        PokeIconView(id: id, pixelSize: 0.5)
                    }
                    Text(summary(recap))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.leading, 3)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: 0x101218).opacity(0.94), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .onTapGesture(perform: close)
    }

    private func trainer(_ id: String) -> Trainer? {
        app.adventure.chapters.flatMap(\.bosses).first { $0.id == id }
    }

    private func summary(_ recap: AdventureRecap) -> String {
        var parts: [String] = []
        if !recap.discovered.isEmpty { parts.append(String(localized: "\(recap.discovered.count) new")) }
        if !recap.evolved.isEmpty { parts.append(String(localized: "\(recap.evolved.count) evolved")) }
        return parts.joined(separator: " · ")
    }

    private func chip(symbol: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 7, weight: .bold))
            Text(text)
        }
        .modifier(RecapChip())
    }
}

private struct RecapChip: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 9, weight: .bold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 5)
            .frame(height: 15)
            .background(.white.opacity(0.1), in: Capsule())
    }
}

// MARK: Starter, loading

private struct StarterPicker: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            StageBackdrop(scenery: .meadow)
            VStack(spacing: 4) {
                Text("Choose your partner")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                HStack(spacing: 6) {
                    ForEach(AdventureService.starters, id: \.self) { id in
                        StarterButton(id: id)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct StarterButton: View {
    let id: Int
    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let species = app.adventure.dex.species(id)
        Button {
            withAnimation(.smooth(duration: 0.3)) { app.adventure.chooseStarter(id) }
        } label: {
            VStack(spacing: 3) {
                PokeSpriteView(id: id, pixelSize: 1)
                    .frame(height: 50, alignment: .bottom)
                Text(species?.name ?? "")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white)
                if let type = species?.types.first { PokeTypeBadge(type: type, compact: true) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(width: 70)
            .background(.black.opacity(isHovering ? 0.4 : 0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(isHovering ? 1.05 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct DexLoading: View {
    var body: some View {
        ZStack {
            StageBackdrop(scenery: .meadow)
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Getting Pokédex data…")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.4), in: Capsule())
        }
    }
}

private struct DexUnavailable: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            StageBackdrop(scenery: .cave)
            VStack(spacing: 6) {
                Text("Couldn't reach PokéAPI")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text("The adventure starts once the Pokédex downloads.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.7))
                Button("Try Again") { app.adventure.dex.retry() }
                    .controlSize(.small)
            }
        }
    }
}

// MARK: Party

private struct PartyBar: View {
    @Binding var selection: Int?
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let party = adventure.party
        HStack(spacing: 4) {
            ForEach(0..<AdventureService.maxParty, id: \.self) { slot in
                if let member = party[safe: slot] {
                    PartySlot(member: member, order: slot + 1, isSelected: selection == member.speciesID) {
                        selection = selection == member.speciesID ? nil : member.speciesID
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(height: Self.height)
                        .overlay(
                            Text("Empty")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.25))
                        )
                        .help("Pick a Pokémon in the Pokédex to add it.")
                }
            }
            Button {
                withAnimation(.smooth(duration: 0.25)) { adventure.recommendParty() }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 22, height: Self.height)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(adventure.owned.count < 2)
            .help("Best team for what's next")
        }
        .frame(height: Self.height)
    }

    static let height: CGFloat = 28
}

private struct PartySlot: View {
    let member: OwnedPokemon
    /// Place in the relay: 1 battles first.
    let order: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let species = app.adventure.dex.species(member.speciesID)
        let tint = species?.types.first?.color ?? .white
        Button(action: action) {
            HStack(spacing: 2) {
                PokeIconView(id: member.speciesID, pixelSize: 1)
                    .padding(.leading, -3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv \(member.level)")
                        .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(Color(hex: 0x7FC8FF)).frame(width: 30 * member.levelProgress)
                    }
                    .frame(width: 30, height: 2.5)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, minHeight: PartyBar.height, maxHeight: PartyBar.height)
            .background(tint.opacity(isHovering ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.7) : tint.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topLeading) {
                Text("\(order)")
                    .font(.system(size: 7, weight: .black, design: .rounded))
                    .foregroundStyle(order == 1 ? Color(hex: 0xFFE14D) : .white.opacity(0.5))
                    .offset(x: 4, y: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(species.map { "\($0.name) · Lv \(member.level)" } ?? "")
    }
}

// MARK: Pokédex

private struct DexGrid: View {
    @Binding var selection: Int?
    @Environment(AppModel.self) private var app

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 5)
    /// A hovered cell scales up; this leaves it room so the scroll view doesn't clip it.
    private static let growRoom: CGFloat = 4

    var body: some View {
        let adventure = app.adventure
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule().fill(Color.adventure)
                            .frame(width: proxy.size.width * CGFloat(adventure.caught.count) / CGFloat(PokeDexStore.maxID))
                    }
                }
                .frame(height: 4)
                Text("\(adventure.caught.count)/\(PokeDexStore.maxID)")
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(1...PokeDexStore.maxID, id: \.self) { id in
                        DexCell(id: id, isSelected: selection == id) {
                            selection = selection == id ? nil : id
                        }
                    }
                }
                .padding(.horizontal, Self.growRoom)
                .padding(.top, Self.growRoom + 2)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, -Self.growRoom)
            .padding(.top, -Self.growRoom)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: Self.growRoom)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 22)
                }
            }
        }
        .frame(width: 5 * 40 + 4 * 4)
        .onAppear {
            if adventure.dex.isReady { PokeSpriteCache.shared.prefetchIcons(upTo: PokeDexStore.maxID) }
        }
        .onChange(of: adventure.dex.isReady) { _, ready in
            if ready { PokeSpriteCache.shared.prefetchIcons(upTo: PokeDexStore.maxID) }
        }
    }
}

private struct DexCell: View {
    let id: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        let adventure = app.adventure
        let caught = adventure.caught.contains(id)
        let seen = adventure.seen.contains(id)
        let species = adventure.dex.species(id)
        let tint = species?.types.first?.color ?? .white
        let inParty = adventure.party.contains { $0.speciesID == id }
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(caught ? tint.opacity(isHovering ? 0.24 : 0.13) : .white.opacity(isHovering ? 0.09 : 0.045))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.7) : (caught ? tint.opacity(0.35) : .clear), lineWidth: isSelected ? 1.5 : 1)
                PokeIconView(id: id, pixelSize: 1, silhouette: !caught, silhouetteOpacity: seen ? 0.34 : 0.12)
                if !caught && !seen {
                    Text("?")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 40, height: 30)
            .overlay(alignment: .topTrailing) {
                if inParty {
                    Circle().fill(Color.adventure).frame(width: 5, height: 5).offset(x: -3, y: 3)
                }
            }
            .scaleEffect(isHovering ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(Self.help(species: species, caught: caught, seen: seen, id: id))
    }

    static func help(species: PokeSpecies?, caught: Bool, seen: Bool, id: Int) -> String {
        let number = String(format: "#%03d", id)
        guard let species, caught || seen else { return number }
        return "\(number) \(species.name)"
    }
}

/// Details for the selected species, shown where the battle was.
private struct PokeDetailCard: View {
    let species: PokeSpecies
    let close: () -> Void

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let caught = adventure.caught.contains(species.id)
        let seen = caught || adventure.seen.contains(species.id)
        let owned = adventure.owned(species: species.id)
        let tint = species.types.first?.color ?? .white
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(Color(hex: 0x101218))
            if caught {
                RadialGradient(colors: [tint.opacity(0.35), tint.opacity(0.08), .clear], center: .init(x: 0.22, y: 0.55),
                               startRadius: 2, endRadius: 70)
            }
            HStack(alignment: .center, spacing: 10) {
                PokeSpriteView(id: species.id, pixelSize: 1, silhouette: !caught)
                    .frame(width: 76, height: 96)
                    .opacity(seen ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(species.number)
                            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))
                        Text(seen ? species.name : "???")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    if seen {
                        HStack(spacing: 3) {
                            ForEach(species.types, id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                            if !species.genus.isEmpty {
                                Text(species.genus)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                        }
                    }
                    if let owned {
                        OwnedSummary(member: owned)
                    } else {
                        Text(caught ? species.flavor : String(localized: "Keep your agents busy to meet this one."))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 8)
            .padding(.trailing, 22)
            .padding(.vertical, 8)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(7)
        }
    }
}

/// Level, experience and party actions for a Pokémon you have.
private struct OwnedSummary: View {
    let member: OwnedPokemon
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let inParty = adventure.isInParty(member.id)
        let isLeader = adventure.partyIDs.first == member.id
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text("Lv \(member.level)")
                    .font(.system(size: 11, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule().fill(Color(hex: 0x7FC8FF)).frame(width: 60 * member.levelProgress)
                }
                .frame(width: 60, height: 3)
            }
            MoveChips(moves: adventure.moves(of: member))
            HStack(spacing: 5) {
                if inParty {
                    if !isLeader {
                        smallButton(String(localized: "Go First"), symbol: "arrow.up.to.line") { adventure.makeLeader(member.id) }
                    }
                    if adventure.partyIDs.count > 1 {
                        smallButton(String(localized: "Remove"), symbol: "minus") { adventure.toggleParty(member.id) }
                    }
                } else if adventure.partyIDs.count < AdventureService.maxParty {
                    smallButton(String(localized: "Add to Party"), symbol: "plus") { adventure.toggleParty(member.id) }
                } else {
                    Text("Party is full")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func smallButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.smooth(duration: 0.25)) { action() } }) {
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 7.5, weight: .bold))
                Text(title).font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(.white.opacity(0.1), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A Pokémon's four moves as type-colored chips, two to a row.
private struct MoveChips: View {
    let moves: [PokeMove]

    var body: some View {
        let rows = stride(from: 0, to: moves.count, by: 2).map { Array(moves[$0..<min($0 + 2, moves.count)]) }
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 2) {
                    ForEach(row, id: \.id) { move in
                        Text(move.name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                            .frame(height: 13)
                            .background(move.type.color.opacity(0.55), in: Capsule())
                            .help(help(move))
                    }
                }
            }
        }
    }

    private func help(_ move: PokeMove) -> String {
        let power = move.power.map { " · \($0)" } ?? ""
        return "\(move.type.title)\(power)"
    }
}

// MARK: Compact notch

/// The party leader, hopping beside the timer while an agent works.
struct PartnerIcon: View {
    let speciesID: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let hop = reduceMotion ? 0 : -abs(sin(time * 3.2)) * 2.5
            PokeIconView(id: speciesID, pixelSize: 0.5)
                .offset(y: (hop * 2).rounded() / 2)
        }
        .frame(width: 20, height: 18)
        .accessibilityLabel(Text("Adventure partner"))
    }
}
