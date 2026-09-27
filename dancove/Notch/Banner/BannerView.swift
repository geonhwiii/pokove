import SwiftUI

/// A notification that drops out of the notch. Claude permission requests get inline actions.
struct BannerView: View {
    let banner: NotchBanner
    let layout: NotchLayout

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: layout.notch.height)
            if let permission = app.claude.permission(id: banner.permissionID) {
                PermissionBannerBody(banner: banner, request: permission)
            } else if banner.celebratesCatch, let encounter = banner.encounter, let species = app.adventure.dex.species(encounter.speciesID) {
                CatchCelebrationBody(banner: banner, encounter: encounter, species: species)
            } else {
                standardBody
            }
        }
    }

    // MARK: Header (the row beside the camera)

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                BannerIcon(style: banner.style, agent: banner.agent, size: 14)
                Text(banner.style.source(for: banner.agent))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: layout.notch.width)

            Text("now")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: Standard body

    private var standardBody: some View {
        HStack(spacing: 12) {
            BannerIcon(style: banner.style, agent: banner.agent, size: 34, filled: true, pokemonID: banner.pokemonID,
                       badgeNumber: banner.badge)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(banner.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                if let detail = banner.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let encounter = banner.encounter, encounter.caught, let species = app.adventure.dex.species(encounter.speciesID) {
                CatchChip(encounter: encounter, species: species)
            } else if banner.sessionID != nil {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity)
    }
}

// MARK: Catches

/// Who joined at the end of the turn, beside the "finished" message.
private struct CatchChip: View {
    let encounter: PokeEncounter
    let species: PokeSpecies

    @State private var landed = false

    var body: some View {
        let tint = species.types.first?.color ?? .white
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.16))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint.opacity(0.45), lineWidth: 1)
                    PokeIconView(id: species.id)
                        .offset(y: landed ? -2 : 10)
                        .opacity(landed ? 1 : 0)
                }
                .frame(width: 52, height: 36)
                if encounter.isNew {
                    NewBadge().offset(x: 6, y: -5)
                }
            }
            Text(species.name)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: 70)
        }
        .onAppear {
            // The newcomer hops into the chip just after the banner lands.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.35)) { landed = true }
        }
        .help("\(species.number) \(species.name) · Lv \(encounter.level)")
    }
}

private struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 7.5, weight: .black))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(Color(hex: 0xFFE14D), in: Capsule())
            .overlay(Capsule().stroke(.black, lineWidth: 1.5))
    }
}

/// A legendary or mythical Pokémon takes over the banner.
private struct CatchCelebrationBody: View {
    let banner: NotchBanner
    let encounter: PokeEncounter
    let species: PokeSpecies

    @State private var appeared = false

    var body: some View {
        let tint = species.types.first?.color ?? .white
        HStack(spacing: 16) {
            ZStack {
                RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.15), .clear], center: .center, startRadius: 2, endRadius: 46)
                PixelSparkles(color: tint, count: 12, prismatic: species.isMythical)
                PokeSpriteView(id: species.id, pixelSize: 1)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(width: 110, height: 92)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(species.isMythical ? "Mythical" : "Legendary")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(tint)
                    if encounter.isNew { NewBadge() }
                }
                Text(species.name)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    Text("\(species.number) · Lv \(encounter.level)")
                        .monospacedDigit()
                    ForEach(species.types, id: \.self) { PokeTypeBadge(type: $0, compact: true) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                Text([banner.title, banner.subtitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5).delay(0.3)) { appeared = true }
        }
    }
}

// MARK: Permission body

private struct PermissionBannerBody: View {
    let banner: NotchBanner
    let request: ClaudePermissionRequest

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                BannerIcon(style: .claudeNeedsPermission, agent: banner.agent, size: 30, filled: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(banner.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer(minLength: 8)
                CountdownRing(start: request.receivedAt, end: request.expiresAt)
                    .frame(width: 16, height: 16)
            }

            Text(banner.detail ?? request.summary)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 8) {
                Button("Open") {
                    app.claude.focus(sessionID: request.sessionID)
                }
                .buttonStyle(NotchPillButtonStyle(kind: .quiet))
                Spacer()
                Button("Deny") { app.claude.answer(request.id, with: .deny) }
                    .buttonStyle(NotchPillButtonStyle(kind: .secondary))
                if request.hasSuggestions {
                    Button("Always") { app.claude.answer(request.id, with: .allowAlways) }
                        .buttonStyle(NotchPillButtonStyle(kind: .secondary))
                }
                Button("Allow") { app.claude.answer(request.id, with: .allow) }
                    .buttonStyle(NotchPillButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 2)
    }
}

/// Shrinking ring that shows how long the notch will hold a permission request.
struct CountdownRing: View {
    let start: Date
    let end: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let total = end.timeIntervalSince(start)
            let remaining = max(0, end.timeIntervalSince(context.date))
            let fraction = total > 0 ? remaining / total : 0
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.claudeAttention, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: fraction)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Shared pieces

extension NotchBanner.Style {
    func source(for agent: AgentKind) -> String {
        switch self {
        case .claudeFinished, .claudeNeedsPermission, .claudeNeedsInput, .claudeError: agent.product
        case .adventure: String(localized: "Adventure")
        case .batteryLow: String(localized: "Battery")
        case .clipboard: String(localized: "Clipboard")
        case .info: "dancove"
        }
    }
}

struct BannerIcon: View {
    let style: NotchBanner.Style
    var agent: AgentKind = .claude
    var size: CGFloat
    var filled = false
    /// Adventure banners show the Pokémon they're about, or a badge.
    var pokemonID: Int?
    var badgeNumber: Int?

    var body: some View {
        Group {
            switch style {
            case .claudeFinished:
                badge(AgentMark(agent: agent), accessory: "checkmark", accessoryColor: .green)
            case .claudeNeedsPermission:
                badge(AgentMark(agent: agent, mode: .attention), accessory: "hand.raised.fill", accessoryColor: .claudeAttention)
            case .claudeNeedsInput:
                badge(AgentMark(agent: agent, mode: .attention), accessory: "ellipsis", accessoryColor: .claudeAttention)
            case .claudeError:
                badge(AgentMark(agent: agent, color: .red.opacity(0.9)), accessory: "exclamationmark", accessoryColor: .red)
            case .adventure:
                if let badgeNumber, size >= 24 {
                    ZStack {
                        Circle().fill(Color.adventure.opacity(0.16))
                        BadgeImageView(number: badgeNumber, size: size * 0.7)
                    }
                } else if let pokemonID, size >= 24 {
                    ZStack {
                        Circle().fill(Color.adventure.opacity(0.16))
                        PokeIconView(id: pokemonID)
                    }
                } else if filled {
                    PokeBallGlyph(size: size * 0.46)
                        .foregroundStyle(Color.adventure)
                        .frame(width: size, height: size)
                        .background(Color.adventure.opacity(0.16), in: Circle())
                } else {
                    PokeBallGlyph(size: size * 0.8).foregroundStyle(Color.adventure)
                }
            case .batteryLow:
                symbol("battery.25percent", color: .red)
            case .clipboard:
                symbol("list.clipboard.fill", color: .clipboard)
            case .info:
                symbol("sparkles", color: .white)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func badge(_ mark: AgentMark, accessory: String, accessoryColor: Color) -> some View {
        if filled {
            ZStack {
                Circle().fill(agent.color.opacity(0.16))
                mark.padding(size * (agent == .codex ? 0.24 : 0.2))
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: accessory)
                    .font(.system(size: size * 0.24, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(width: size * 0.4, height: size * 0.4)
                    .background(accessoryColor, in: Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        } else {
            mark
        }
    }

    @ViewBuilder
    private func symbol(_ name: String, color: Color) -> some View {
        if filled {
            Image(systemName: name)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(color.opacity(0.16), in: Circle())
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.8, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

/// Capsule buttons used inside the notch.
struct NotchPillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .quiet ? 6 : 13)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .primary: .black
        case .secondary: .white
        case .quiet: .white.opacity(0.55)
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .claudeAttention
        case .secondary: .white.opacity(0.14)
        case .quiet: .clear
        }
    }
}
