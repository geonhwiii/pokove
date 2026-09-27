import SwiftUI

extension Color {
    /// The adventure's warm red-orange, for tabs, badges and banners.
    static let adventure = Color(red: 1.0, green: 0.48, blue: 0.27)
}

extension Notification.Name {
    static let dancoveOpenAdventure = Notification.Name("com.geonhwiii.dancove.openAdventure")
    #if DEBUG
    static let dancoveDebugSelectPokemon = Notification.Name("dancoveDebugSelectPokemon")
    #endif
}

/// The adventure page: the party's battle on the left, the Pokédex on the right.
struct AdventurePageView: View {
    @Environment(AppModel.self) private var app
    /// The species whose details replace the battle scene.
    @State private var selection: Int?

    var body: some View {
        let adventure = app.adventure
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .animation(.smooth(duration: 0.28), value: selection)

                PartyBar(selection: $selection)
            }
            .frame(minWidth: 214, maxWidth: 262)

            DexGrid(selection: $selection)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { adventure.dex.load() }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .dancoveDebugSelectPokemon)) { note in
            selection = note.object as? Int
        }
        #endif
    }
}

// MARK: Battle scene

/// The party (left, facing right) against the stage's wild Pokémon, one action per tick.
struct BattleSceneView: View {
    static let height: CGFloat = 118

    @Environment(AppModel.self) private var app
    @State private var lunging: UUID?
    @State private var struck: UUID?
    @State private var popups: [DamagePopup] = []

    var body: some View {
        let adventure = app.adventure
        let battle = adventure.battle
        let stage = battle?.stage ?? adventure.progress.current
        ZStack {
            StageBackdrop(world: stage.world)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .topLeading) {
                    if let battle {
                        // Back row first, so the front row overlaps it.
                        ForEach(Array(battle.party.enumerated()).sorted { Self.partySlot($0.offset, width: width).y < Self.partySlot($1.offset, width: width).y }, id: \.element.id) { index, member in
                            combatantView(member, facingRight: true)
                                .position(Self.figureCenter(Self.partySlot(index, width: width)))
                        }
                        ForEach(Array(battle.enemies.enumerated()), id: \.element.id) { index, enemy in
                            combatantView(enemy, facingRight: false)
                                .position(Self.figureCenter(Self.enemySlot(index, count: battle.enemies.count, boss: enemy.isBoss, width: width)))
                                .zIndex(index == 0 ? 1 : 0)
                        }
                    }
                    ForEach(popups) { popup in
                        DamagePopupView(popup: popup)
                            .position(point(for: popup.targetID, in: battle, width: width))
                    }
                }
            }

            SceneOverlay(stage: stage, battle: battle)
        }
        .onChange(of: adventure.attackSerial) { handle(adventure.lastAttack) }
    }

    /// Where a combatant's feet go. The leader stands in front, the other two a step behind.
    static func partySlot(_ index: Int, width: CGFloat) -> CGPoint {
        let spots: [CGPoint] = [CGPoint(x: 0.34, y: 104), CGPoint(x: 0.2, y: 92), CGPoint(x: 0.09, y: 110)]
        let spot = spots[min(index, spots.count - 1)]
        return CGPoint(x: spot.x * width, y: spot.y)
    }

    static func enemySlot(_ index: Int, count: Int, boss: Bool, width: CGFloat) -> CGPoint {
        if boss { return CGPoint(x: 0.75 * width, y: 106) }
        let spots: [CGPoint] = count == 1 ? [CGPoint(x: 0.74, y: 100)] : [CGPoint(x: 0.66, y: 106), CGPoint(x: 0.85, y: 92)]
        let spot = spots[min(index, spots.count - 1)]
        return CGPoint(x: spot.x * width, y: spot.y)
    }

    /// Combatants are drawn in a box this tall, feet on its bottom edge.
    static let figureHeight: CGFloat = 96

    static func figureCenter(_ feet: CGPoint) -> CGPoint {
        CGPoint(x: feet.x, y: feet.y - figureHeight / 2)
    }

    /// Just above where a combatant stands, for its damage number.
    private func point(for id: UUID, in battle: BattleState?, width: CGFloat) -> CGPoint {
        var point = CGPoint(x: 0.7 * width, y: 50)
        if let battle {
            if let index = battle.party.firstIndex(where: { $0.id == id }) {
                point = Self.partySlot(index, width: width)
            } else if let index = battle.enemies.firstIndex(where: { $0.id == id }) {
                point = Self.enemySlot(index, count: battle.enemies.count, boss: battle.enemies[index].isBoss, width: width)
            }
        }
        point.y -= 44
        return point
    }

    private func combatantView(_ combatant: Combatant, facingRight: Bool) -> some View {
        let lunge: CGFloat = lunging == combatant.id ? (facingRight ? 7 : -7) : 0
        return VStack(spacing: 2) {
            HPBar(fraction: combatant.hpFraction, level: combatant.level, isBoss: combatant.isBoss)
            PokeSpriteView(id: combatant.speciesID, pixelSize: combatant.isBoss ? 1 : 0.5, flipped: facingRight)
                .opacity(struck == combatant.id ? 0.35 : 1)
                .saturation(combatant.isFainted ? 0 : 1)
        }
        .frame(width: 90, height: Self.figureHeight, alignment: .bottom)
        .opacity(combatant.isFainted ? 0.28 : 1)
        .offset(x: lunge, y: combatant.isFainted ? 5 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: lunging)
        .animation(.easeOut(duration: 0.12), value: struck)
        .animation(.smooth(duration: 0.4), value: combatant.isFainted)
        .animation(.smooth(duration: 0.35), value: combatant.hp)
    }

    private func handle(_ attack: BattleAttack?) {
        guard let attack, let battle = app.adventure.battle else { return }
        lunging = attack.attackerID
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            lunging = nil
            struck = attack.targetID
            try? await Task.sleep(for: .milliseconds(140))
            struck = nil
        }
        _ = battle
        let popup = DamagePopup(id: UUID(), text: "\(attack.damage)", targetID: attack.targetID,
                                note: DamagePopup.note(for: attack), byParty: attack.byParty, critical: attack.critical)
        popups.append(popup)
        if popups.count > 4 { popups.removeFirst(popups.count - 4) }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            popups.removeAll { $0.id == popup.id }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

private struct DamagePopup: Identifiable, Equatable {
    let id: UUID
    let text: String
    let targetID: UUID
    let note: String?
    let byParty: Bool
    let critical: Bool

    static func note(for attack: BattleAttack) -> String? {
        if attack.effectiveness >= 2 { return String(localized: "Super effective!") }
        if attack.effectiveness < 1 { return String(localized: "Not very effective") }
        if attack.critical { return String(localized: "Critical hit!") }
        return nil
    }
}

private struct DamagePopupView: View {
    let popup: DamagePopup
    @State private var risen = false

    var body: some View {
        VStack(spacing: 0) {
            Text(popup.text)
                .font(.system(size: popup.critical ? 12 : 10.5, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(popup.byParty ? .white : Color(hex: 0xFF8A80))
            if let note = popup.note {
                Text(note)
                    .font(.system(size: 7.5, weight: .heavy))
                    .foregroundStyle(Color(hex: 0xFFE14D))
            }
        }
        .shadow(color: .black.opacity(0.8), radius: 1, y: 1)
        .fixedSize()
        .offset(y: risen ? -12 : 0)
        .opacity(risen ? 0 : 1)
        .onAppear { withAnimation(.easeOut(duration: 0.85)) { risen = true } }
    }
}

private struct HPBar: View {
    let fraction: Double
    let level: Int
    var isBoss = false

    var body: some View {
        VStack(spacing: 1) {
            Text(isBoss ? "BOSS · Lv\(level)" : "Lv\(level)")
                .font(.system(size: 6.5, weight: .heavy).monospacedDigit())
                .foregroundStyle(isBoss ? Color(hex: 0xFFB0A0) : .white.opacity(0.9))
                .shadow(color: .black.opacity(0.7), radius: 0.5, y: 0.5)
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.55))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, (isBoss ? 40 : 24) * fraction))
            }
            .frame(width: isBoss ? 40 : 24, height: 3)
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
        }
        .fixedSize()
    }

    private var color: Color {
        fraction > 0.5 ? Color(hex: 0x5CE07A) : (fraction > 0.2 ? Color(hex: 0xF7D02C) : Color(hex: 0xFF5A4A))
    }
}

/// Stage number, waves, and whether the party is fighting or waiting on an agent.
private struct SceneOverlay: View {
    let stage: Stage
    let battle: BattleState?

    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        VStack {
            HStack(alignment: .top) {
                HStack(spacing: 5) {
                    Text(stage.label)
                        .font(.system(size: 10, weight: .heavy, design: .rounded).monospacedDigit())
                    if stage.isBoss {
                        Text("BOSS")
                            .font(.system(size: 7.5, weight: .black))
                            .foregroundStyle(Color(hex: 0xFF8A70))
                    } else if let battle {
                        HStack(spacing: 2.5) {
                            ForEach(0..<battle.waveCount, id: \.self) { wave in
                                Circle()
                                    .fill(.white.opacity(wave <= battle.waveIndex ? 0.95 : 0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.4), in: Capsule())

                Spacer()

                if adventure.progress.isTraining {
                    Text("Training")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.4), in: Capsule())
                        .help("Beaten at \(adventure.progress.frontier.label), so training here first.")
                }
            }
            Spacer()
            if !adventure.isBattling {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                    Text("Battles go on while an agent works")
                }
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .transition(.opacity)
            }
        }
        .padding(7)
        .animation(.smooth(duration: 0.25), value: adventure.isBattling)
    }
}

/// A pixel landscape per world: sky bands with a dithered seam, and ground tiles.
private struct StageBackdrop: View {
    let world: Int

    private struct Theme {
        var skyTop: UInt32, skyBottom: UInt32, ground: UInt32, groundDark: UInt32
    }

    private static let themes: [Theme] = [
        Theme(skyTop: 0x3A86E0, skyBottom: 0xB8E4FF, ground: 0x6CC05A, groundDark: 0x4E9A44),   // meadow
        Theme(skyTop: 0x1E4A3A, skyBottom: 0x5E9A6A, ground: 0x3E7A3A, groundDark: 0x2C5A2A),   // forest
        Theme(skyTop: 0x2A2430, skyBottom: 0x5A4C58, ground: 0x7A6A5A, groundDark: 0x5A4C40),   // cave
        Theme(skyTop: 0x2A6AD0, skyBottom: 0x9AD8F8, ground: 0xE8D8A0, groundDark: 0xC8B880),   // beach
        Theme(skyTop: 0x4A1A1A, skyBottom: 0xC85A2A, ground: 0x5A3A30, groundDark: 0x3A2420),   // volcano
        Theme(skyTop: 0x7A9AC8, skyBottom: 0xE8F2FF, ground: 0xF4F8FF, groundDark: 0xC8D8EC),   // snow
        Theme(skyTop: 0x0E1230, skyBottom: 0x3A3A7A, ground: 0x4A4A6A, groundDark: 0x34344E),   // night
    ]

    var body: some View {
        let theme = Self.themes[(max(1, world) - 1) % Self.themes.count]
        Canvas { canvas, size in
            let pixel: CGFloat = 2
            let horizon = size.height * 0.62
            let bands = 5
            for band in 0..<bands {
                let t = Double(band) / Double(bands - 1)
                let top = CGFloat(band) * horizon / CGFloat(bands)
                let bottom = CGFloat(band + 1) * horizon / CGFloat(bands)
                canvas.fill(Path(CGRect(x: 0, y: top, width: size.width, height: bottom - top + 0.5)),
                            with: .color(Color(hex: Self.mix(theme.skyTop, theme.skyBottom, t))))
                if band + 1 < bands {
                    let next = Color(hex: Self.mix(theme.skyTop, theme.skyBottom, Double(band + 1) / Double(bands - 1)))
                    for x in stride(from: 0, to: size.width, by: pixel * 2) {
                        canvas.fill(Path(CGRect(x: x, y: bottom - pixel, width: pixel, height: pixel)), with: .color(next))
                    }
                }
            }
            canvas.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: size.height - horizon)), with: .color(Color(hex: theme.ground)))
            // A checker of darker tiles so the ground reads as pixel art.
            var row = 0
            for y in stride(from: horizon + pixel * 3, to: size.height, by: pixel * 4) {
                for x in stride(from: CGFloat(row % 2) * pixel * 6, to: size.width, by: pixel * 12) {
                    canvas.fill(Path(CGRect(x: x, y: y, width: pixel * 3, height: pixel)), with: .color(Color(hex: theme.groundDark)))
                }
                row += 1
            }
            canvas.fill(Path(CGRect(x: 0, y: horizon, width: size.width, height: pixel)), with: .color(Color(hex: theme.groundDark)))
        }
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32((x + (y - x) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}

// MARK: Starter, loading

private struct StarterPicker: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            StageBackdrop(world: 1)
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
            StageBackdrop(world: 1)
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
            StageBackdrop(world: 7)
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
        let party = app.adventure.party
        HStack(spacing: 5) {
            ForEach(0..<AdventureService.maxParty, id: \.self) { slot in
                if let member = party[safe: slot] {
                    PartySlot(member: member, isLeader: slot == 0, isSelected: selection == member.speciesID) {
                        selection = selection == member.speciesID ? nil : member.speciesID
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(height: 30)
                        .overlay(
                            Text("Empty")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.25))
                        )
                        .help("Pick a Pokémon in the Pokédex to add it.")
                }
            }
        }
        .frame(height: 30)
    }
}

private struct PartySlot: View {
    let member: OwnedPokemon
    let isLeader: Bool
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
            .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
            .background(tint.opacity(isHovering ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? .white.opacity(0.7) : tint.opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topLeading) {
                if isLeader {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(Color(hex: 0xFFE14D))
                        .offset(x: 3, y: 2)
                }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Pokédex")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(adventure.caught.count)/\(PokeDexStore.maxID)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(Color.adventure)
                        .frame(width: proxy.size.width * CGFloat(adventure.caught.count) / CGFloat(PokeDexStore.maxID))
                }
            }
            .frame(height: 4)

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
            HStack(spacing: 5) {
                if inParty {
                    if !isLeader {
                        smallButton(String(localized: "Lead"), symbol: "crown.fill") { adventure.makeLeader(member.id) }
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
