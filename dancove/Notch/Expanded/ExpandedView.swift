import SwiftUI

/// The open notch: a header row beside the camera, and one activity page below it.
struct ExpandedView: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app

    var body: some View {
        let layout = viewModel.layout
        VStack(spacing: 0) {
            ExpandedHeader(viewModel: viewModel)
                .frame(height: layout.notch.height)

            ZStack {
                switch viewModel.page {
                case .media:
                    MediaPlayerView(viewModel: viewModel)
                        .transition(.pageSwap)
                case .calendar:
                    CalendarPageView()
                        .transition(.pageSwap)
                case .todos:
                    TodoPageView(viewModel: viewModel)
                        .transition(.pageSwap)
                case .clipboard:
                    ClipboardPageView(viewModel: viewModel)
                        .transition(.pageSwap)
                case .claude:
                    ClaudePageView()
                        .transition(.pageSwap)
                case .adventure:
                    AdventurePageView()
                        .transition(.pageSwap)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: viewModel.page)
        }
        .onChange(of: app.claude.permissions.count) { old, new in
            // A permission request blocks Claude, so surface it even mid-song — but never yank the
            // page away while someone is typing; the Claude tab's badge shows it instead.
            if new > old, !viewModel.isEditingText { viewModel.page = .claude }
        }
    }
}

extension AnyTransition {
    /// Pages trade places with a short blur, like Alcove cycling activities.
    static var pageSwap: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: NotchBloom(blur: 8, scaleX: 0.96, scaleY: 0.96, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            ),
            removal: .modifier(
                active: NotchBloom(blur: 6, scaleX: 1.02, scaleY: 1.02, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            )
        )
    }
}

private struct ExpandedHeader: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app

    var body: some View {
        let layout = viewModel.layout
        HStack(spacing: 0) {
            HStack(spacing: NotchLayout.tabSpacing) {
                ForEach(viewModel.availablePages) { page in
                    PageButton(page: page, isSelected: viewModel.page == page, badge: badge(for: page)) {
                        viewModel.select(page)
                    }
                }
            }
            .padding(.leading, NotchLayout.tabsLeading)
            .frame(width: layout.openSideWidth, alignment: .leading)

            // The camera housing.
            Color.clear.frame(width: layout.notch.width)

            HStack(spacing: 10) {
                if app.battery.hasBattery {
                    HStack(spacing: 4) {
                        Text("\(app.battery.level)%")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                        BatteryGlyph(
                            level: app.battery.level,
                            isCharging: app.battery.isCharging,
                            isLowPower: app.battery.isLowPowerMode
                        )
                        .frame(width: 22, height: 11)
                    }
                }
                Button {
                    viewModel.close()
                    SettingsWindowController.shared.show(app: app, pane: settingsPane)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 24, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HoverHighlightButtonStyle())
                .help("Settings")
            }
            .padding(.trailing, 16)
            .frame(width: layout.openSideWidth, alignment: .trailing)
        }
    }

    /// The settings pane that goes with the page on screen.
    private var settingsPane: SettingsPane? {
        switch viewModel.page {
        case .media: .nowPlaying
        case .calendar, .todos: .calendar
        case .clipboard: .clipboard
        case .claude: .claude
        case .adventure: .adventure
        }
    }

    private func badge(for page: NotchPage) -> Bool {
        switch page {
        case .claude: app.claude.needsAttention
        case .adventure: app.adventure.isBattling || app.adventure.canPull || app.adventure.offer != nil
        default: false
        }
    }
}

private struct PageButton: View {
    let page: NotchPage
    let isSelected: Bool
    let badge: Bool
    let action: () -> Void

    @Environment(AppModel.self) private var app

    /// Gold when a gacha pull is waiting, orange while battling.
    private var badgeColor: Color {
        app.adventure.canPull || app.adventure.offer != nil ? Color(hex: 0xFFD35A) : .adventure
    }

    var body: some View {
        Button(action: action) {
            Group {
                if page == .claude {
                    ClaudeMark(color: isSelected ? .claude : .white.opacity(0.4))
                        .frame(width: 12, height: 12)
                } else if page == .adventure {
                    PokeBallGlyph(size: 12)
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                } else {
                    Image(systemName: page.symbol)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                }
            }
            .frame(width: NotchLayout.tabSize.width, height: NotchLayout.tabSize.height)
            .background(isSelected ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if badge {
                    Circle()
                        .fill(page == .adventure ? badgeColor : Color.claudeAttention)
                        .frame(width: 6, height: 6)
                        .offset(x: -3, y: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverHighlightButtonStyle())
        .help(page.title)
        .accessibilityLabel(page.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Subtle rounded highlight on hover, like Alcove's control buttons.
struct HoverHighlightButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        HoverHighlight(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct HoverHighlight: View {
        let configuration: ButtonStyleConfiguration
        let cornerRadius: CGFloat
        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(isHovering && isEnabled ? 0.1 : 0))
                )
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .opacity(isEnabled ? 1 : 0.35)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isHovering)
                .onHover { isHovering = $0 }
        }
    }
}
