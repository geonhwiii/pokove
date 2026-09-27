import SwiftUI

/// Three Poké Balls for the price of a pull; open one to see who's inside. The kind of ball hints
/// at how rare it is, and every ball holds something: a new Pokémon, or experience for one you have.
struct GachaView: View {
    @Environment(AppModel.self) private var app
    /// The ball being opened.
    @State private var chosen: UUID?
    @State private var wiggle: Double = 0
    /// What came out, shown until dismissed.
    @State private var result: GachaResult?

    var body: some View {
        let adventure = app.adventure
        VStack(spacing: 6) {
            if let result {
                GachaResultView(result: result) { withAnimation(.smooth(duration: 0.3)) { self.result = nil } }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if let offer = adventure.offer {
                HStack(spacing: 14) {
                    ForEach(Array(offer.enumerated()), id: \.element.id) { index, card in
                        GachaBall(card: card, index: index, isChosen: chosen == card.id, isFaded: chosen != nil && chosen != card.id,
                                  wiggle: chosen == card.id ? wiggle : 0) {
                            open(card)
                        }
                    }
                }
                .frame(height: 96)
                .padding(.top, 8)
                Text("Pick a ball to open")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .opacity(chosen == nil ? 1 : 0)
            } else {
                PullPanel()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task(id: result?.id) {
            guard result != nil, (try? await Task.sleep(for: .seconds(6))) != nil else { return }
            withAnimation(.smooth(duration: 0.3)) { result = nil }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .dancoveDebugOpenBall)) { note in
            if let index = note.object as? Int, let card = adventure.offer?[safe: index] { open(card) }
        }
        #endif
    }

    /// The chosen ball shakes three times, then pops open.
    private func open(_ card: GachaCard) {
        guard chosen == nil else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { chosen = card.id }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 0.1)) { wiggle = -16 }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeInOut(duration: 0.1)) { wiggle = 16 }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeInOut(duration: 0.1)) { wiggle = 0 }
                try? await Task.sleep(for: .milliseconds(260))
            }
            let adventure = app.adventure
            let existing = adventure.owned(family: card.species)
            let outcome = GachaResult(card: card, existingSpecies: existing?.speciesID,
                                      xp: existing.map { Gacha.duplicateXP(level: $0.level) })
            adventure.pick(card.id)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                result = outcome
                chosen = nil
            }
        }
    }
}

/// What a ball held.
struct GachaResult: Identifiable, Equatable {
    var id: UUID { card.id }
    let card: GachaCard
    /// The Pokémon that got the experience, when it was one you already had.
    let existingSpecies: Int?
    let xp: Int?
}

extension GachaCard.Rarity {
    /// Poké, Great, Ultra and Master Balls.
    var ball: String {
        switch self {
        case .common: "poke-ball"
        case .uncommon: "great-ball"
        case .rare: "ultra-ball"
        case .mythical: "master-ball"
        }
    }

    var glow: Color {
        switch self {
        case .common: Color(hex: 0xFF8A70)
        case .uncommon: Color(hex: 0x5CC8FF)
        case .rare: Color(hex: 0xFFD35A)
        case .mythical: Color(hex: 0xD88AFF)
        }
    }
}

private struct GachaBall: View {
    let card: GachaCard
    let index: Int
    let isChosen: Bool
    let isFaded: Bool
    let wiggle: Double
    let action: () -> Void

    @State private var bob = false
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.35))
                    .frame(width: 30, height: 6)
                    .offset(y: 26)
                Circle()
                    .fill(RadialGradient(colors: [card.rarity.glow.opacity(isHovering || isChosen ? 0.45 : 0.22), .clear],
                                         center: .center, startRadius: 2, endRadius: 34))
                    .frame(width: 68, height: 68)
                ItemSpriteView(slug: card.rarity.ball, pixelSize: 2)
                    .rotationEffect(.degrees(wiggle), anchor: .bottom)
                    .offset(y: isChosen ? 0 : (bob ? -3 : 1))
            }
            .frame(width: 60, height: 80)
            .scaleEffect(isChosen ? 1.18 : (isHovering && !isFaded ? 1.06 : 1))
            .opacity(isFaded ? 0 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFaded)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(Double(index) * 0.25)) { bob = true }
        }
    }
}

/// The Pokémon bursting out of its ball, with its name and what it brought.
private struct GachaResultView: View {
    let result: GachaResult
    let close: () -> Void

    @Environment(AppModel.self) private var app
    @State private var popped = false

    var body: some View {
        let dex = app.adventure.dex
        let species = dex.species(result.card.species)
        let glow = result.card.rarity.glow
        Button(action: close) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [glow.opacity(0.55), glow.opacity(0.12), .clear], center: .center,
                                             startRadius: 2, endRadius: popped ? 56 : 8))
                        .frame(width: 112, height: 112)
                    PixelSparkles(color: glow, count: result.card.rarity >= .rare ? 14 : 9, prismatic: result.card.rarity == .mythical)
                        .frame(width: 120, height: 84)
                        .opacity(popped ? 1 : 0)
                    PokeSpriteView(id: result.card.species, pixelSize: 1, fitHeight: 64)
                        .scaleEffect(popped ? 1 : 0.1, anchor: .bottom)
                        .offset(y: popped ? 0 : 20)
                }
                .frame(height: 84)
                Text(species?.name ?? "")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                if let xp = result.xp {
                    let name = result.existingSpecies.flatMap { dex.species($0)?.name } ?? ""
                    Text("\(name) EXP +\(xp)")
                        .font(.system(size: 9.5, weight: .heavy).monospacedDigit())
                        .foregroundStyle(Color(hex: 0x7FC8FF))
                } else {
                    HStack(spacing: 3) {
                        Text("NEW").font(.system(size: 8, weight: .black)).foregroundStyle(.black)
                            .padding(.horizontal, 4).background(Color(hex: 0xFFE14D), in: Capsule())
                        Text("Lv \(result.card.level)").font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.75))
                        ForEach(species?.types ?? [], id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.05)) { popped = true }
        }
    }
}

/// Coins, the price and the button, before the balls are handed out.
private struct PullPanel: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let adventure = app.adventure
        let fraction = min(1, Double(adventure.coins) / Double(Gacha.price))
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                ForEach(["poke-ball", "great-ball", "ultra-ball"], id: \.self) { slug in
                    ItemSpriteView(slug: slug, pixelSize: 1.5)
                        .opacity(adventure.canPull ? 1 : 0.45)
                }
            }
            .frame(height: 52)
            .padding(.top, 6)

            VStack(spacing: 3) {
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(Color(hex: 0xFFD35A)).frame(width: 150 * fraction)
                }
                .frame(width: 150, height: 4)
                HStack(spacing: 3) {
                    CoinIcon()
                    Text("\(adventure.coins) / \(Gacha.price)")
                        .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { adventure.pull() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Get 3 Poké Balls")
                }
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(adventure.canPull ? .black : .white.opacity(0.35))
                .padding(.horizontal, 14)
                .frame(height: 22)
                .background(adventure.canPull ? Color(hex: 0xFFD35A) : .white.opacity(0.08), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!adventure.canPull)
            .help(adventure.canPull ? "" : "Clear stages to earn coins.")
        }
        .frame(maxWidth: .infinity)
    }
}

/// A little gold coin.
struct CoinIcon: View {
    var size: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0xF2B83A))
            Circle().strokeBorder(Color(hex: 0xB07A18), lineWidth: 1)
            Circle().fill(Color(hex: 0xFFE38A)).frame(width: size * 0.36, height: size * 0.36).offset(x: -size * 0.12, y: -size * 0.12)
        }
        .frame(width: size, height: size)
    }
}
