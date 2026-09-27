import SwiftUI

/// The VS splash that opens a challenge in the battle scene: the party slides in from the left,
/// the opponent from the right, and "VS" lands between them.
struct ChallengeIntroView: View {
    let plan: StagePlan

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var flash = 1.0

    var body: some View {
        let adventure = app.adventure
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                VSBackground(color: color)

                HStack(spacing: -4) {
                    ForEach(adventure.party) { member in PokeIconView(id: member.speciesID, pixelSize: 0.5) }
                }
                .padding(.leading, 4)
                .padding(.top, 4)
                .offset(x: arrived ? 0 : -60)

                if let leader = adventure.leader {
                    PokeSpriteView(id: leader.speciesID, pixelSize: 1, back: true, shiny: leader.shiny, fitHeight: 56)
                        .frame(width: 84, height: 60, alignment: .bottom)
                        .position(x: 46, y: size.height - 34)
                        .offset(x: arrived ? 0 : -110)
                }

                opponent
                    .position(x: size.width - 58, y: 48)
                    .offset(x: arrived ? 0 : 120)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(name)
                        .font(.system(size: 15, weight: .black).italic())
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 1.2, y: 1.2)
                    Text(subtitle)
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.9), radius: 0, x: 0.8, y: 0.8)
                }
                .lineLimit(1)
                .frame(width: size.width - 10, alignment: .trailing)
                .position(x: size.width / 2, y: size.height - 18)
                .offset(x: arrived ? 0 : 60)
                .opacity(arrived ? 1 : 0)

                Text("VS")
                    .font(.system(size: 30, weight: .black, design: .rounded).italic())
                    .foregroundStyle(Color(hex: 0xFFD35A))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .scaleEffect(arrived ? 1 : 2.6)
                    .opacity(arrived ? 1 : 0)
                    .position(x: size.width / 2 + 1, y: size.height / 2 - 6)

                Color.white.opacity(flash).allowsHitTesting(false)
            }
        }
        .onAppear {
            if reduceMotion {
                arrived = true
                flash = 0
                return
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { arrived = true }
            withAnimation(.easeOut(duration: 0.35)) { flash = 0 }
        }
    }

    private var foeSpecies: Int? {
        switch plan.kind {
        case .legend: plan.foes.first?.species
        default: plan.foes.last?.species
        }
    }

    private var color: Color {
        if let trainer = plan.trainer { return trainer.specialty?.color ?? Color(hex: 0xC8A040) }
        return foeSpecies.flatMap { app.adventure.dex.species($0)?.types.first?.color } ?? Color(hex: 0xC8A040)
    }

    @ViewBuilder private var opponent: some View {
        if let trainer = plan.trainer {
            TrainerSpriteView(slug: trainer.sprite, pixelSize: 1)
        } else if let species = foeSpecies {
            PokeSpriteView(id: species, pixelSize: 1, back: false, fitHeight: 60)
                .frame(width: 96, height: 64, alignment: .bottom)
        }
    }

    private var name: String {
        switch plan.kind {
        case .trainer(let trainer): trainer.name
        case .legend: foeSpecies.flatMap { app.adventure.dex.species($0)?.name } ?? ""
        case .dungeon(let tier): ChallengeText.dungeon(tier.title)
        case .wild: ""
        }
    }

    private var subtitle: String {
        switch plan.kind {
        case .trainer(let trainer): trainer.title
        case .legend: ChallengeText.legendary
        case .dungeon:
            ChallengeText.floors(DailyDungeon.floors, types: app.adventure.dungeonTypes.map(\.title).joined(separator: "·"))
        case .wild: ""
        }
    }
}

extension ChallengeResultView {
    /// Who the challenge was against.
    fileprivate var opponent: String? {
        switch result.kind {
        case .boss(let trainer): trainer.name
        case .legend(let species): app.adventure.dex.species(species)?.name
        case .dungeon(let tier): ChallengeText.dungeon(tier.title)
        }
    }
}

/// A challenge's outcome over the battle scene: gold rays and what was won, or a quiet loss card
/// with the odds for the next try.
struct ChallengeResultView: View {
    let result: ChallengeResult

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            if result.cleared {
                Color(hex: 0x14102A).opacity(0.96)
                LightRays().opacity(shown ? 1 : 0)
            } else {
                Color(hex: 0x0E0F14).opacity(0.96)
            }

            VStack(spacing: 5) {
                Text(result.cleared ? ChallengeText.victory : ChallengeText.defeat)
                    .font(.system(size: result.cleared ? 28 : 24, weight: .black, design: .rounded).italic())
                    .foregroundStyle(result.cleared ? Color(hex: 0xFFD35A) : .white.opacity(0.85))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                    .scaleEffect(shown ? 1 : (result.cleared ? 1.8 : 0.8))

                VStack(spacing: 3) {
                    if result.cleared { prize } else { loss }
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 6)
            }
            .padding(.horizontal, 12)
        }
        .onAppear {
            if reduceMotion { shown = true; return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { shown = true }
        }
    }

    @ViewBuilder private var prize: some View {
        let dex = app.adventure.dex
        switch result.kind {
        case .boss:
            if let badge = result.badge {
                HStack(spacing: 6) {
                    BadgeImageView(number: badge, size: 22)
                    Text(ChallengeText.gotBadge(Kanto.badgeName(badge))).modifier(ResultLine())
                }
            }
            if let cap = result.cap {
                Text(ChallengeText.cap(cap.lowerBound, cap.upperBound)).modifier(ResultDetail(color: Color(hex: 0x7FE08A)))
            }
        case .legend(let species):
            HStack(spacing: 4) {
                PokeIconView(id: species, pixelSize: 1)
                Text(ChallengeText.joined(dex.species(species)?.name ?? "")).modifier(ResultLine())
            }
        case .dungeon(let tier):
            Text(ChallengeText.cleared(ChallengeText.dungeon(tier.title))).modifier(ResultLine())
            if result.ultraBall {
                HStack(spacing: 3) {
                    ItemSpriteView(slug: "ultra-ball", pixelSize: 0.5)
                    Text(ChallengeText.ultraBall)
                }
                .modifier(ResultDetail(color: Color(hex: 0xFFD35A)))
            }
        }
        if result.stardust > 0 {
            HStack(spacing: 3) {
                StardustIcon(size: 11)
                Text("+\(result.stardust)")
            }
            .modifier(ResultDetail(color: Color(hex: 0xFFD35A)))
        }
    }

    @ViewBuilder private var loss: some View {
        if let opponent {
            Text(ChallengeText.lost(to: opponent)).modifier(ResultLine())
        }
        Text(ChallengeText.nothingLost)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        if let chance = result.chance {
            let percent = Int((chance * 100).rounded())
            Text(ChallengeText.chance(percent))
                .modifier(ResultDetail(color: chance >= 0.6 ? Color(hex: 0x7EE08F) : chance >= 0.3 ? Color(hex: 0xFFD35A) : Color(hex: 0xFF8A70)))
        }
    }
}

private struct ResultLine: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

private struct ResultDetail: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.system(size: 10, weight: .heavy).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Slowly turning gold rays behind a win.
private struct LightRays: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate * 12
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2 - 4)
                let reach = max(size.width, size.height)
                for ray in 0..<12 {
                    let angle = (Double(ray) / 12 * 360 + turn) * .pi / 180
                    var wedge = Path()
                    wedge.move(to: center)
                    wedge.addLine(to: CGPoint(x: center.x + reach * cos(angle - 0.09), y: center.y + reach * sin(angle - 0.09)))
                    wedge.addLine(to: CGPoint(x: center.x + reach * cos(angle + 0.09), y: center.y + reach * sin(angle + 0.09)))
                    wedge.closeSubpath()
                    canvas.fill(wedge, with: .color(Color(hex: 0xFFD35A).opacity(0.13)))
                }
                canvas.fill(Path(ellipseIn: CGRect(x: center.x - 50, y: center.y - 28, width: 100, height: 56)),
                            with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD35A).opacity(0.35), .clear]),
                                                  center: center, startRadius: 0, endRadius: 56))
            }
        }
    }
}
