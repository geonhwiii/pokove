import SwiftUI

/// Root of every notch window: the black morphing shape and whichever content it hosts.
struct NotchRootView: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app
    @State private var shown: NotchPresentation = .idle

    var body: some View {
        let layout = viewModel.layout
        let size = layout.size(for: shown)
        let radii = layout.cornerRadii(for: shown)
        let shape = NotchShape(topCornerRadius: radii.top, bottomCornerRadius: radii.bottom)
        let hovering = viewModel.isHovering && !shown.isOpen
        let interactive = shown != .idle || viewModel.isHovering

        VStack(spacing: 0) {
            NotchContentView(viewModel: viewModel, presentation: shown)
                .frame(width: size.width, height: size.height, alignment: .top)
                .padding(.horizontal, radii.top)
                .background(.black)
                .clipShape(shape)
                .overlay(alignment: .top) {
                    // Hides a hairline where the panel meets the top edge of the screen.
                    Rectangle().fill(.black).frame(height: 1).padding(.horizontal, radii.top)
                }
                .shadow(color: .black.opacity(shown.isElevated || hovering ? 0.45 : 0), radius: shown.isElevated ? 16 : 8, y: 3)
                .contentShape(shape)
                .scaleEffect(scale(hovering: hovering), anchor: .top)
                .onTapGesture(perform: handleTap)
                .simultaneousGesture(pressGesture)
                .allowsHitTesting(interactive)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.notchHover, value: hovering)
        .animation(.notchPress, value: viewModel.isPressed)
        .onChange(of: viewModel.presentation, initial: true) { old, new in
            withAnimation(.notchTransition(from: shown, to: new)) {
                shown = new
            }
        }
        .preferredColorScheme(.dark)
    }

    private func scale(hovering: Bool) -> CGFloat {
        if viewModel.isPressed && isPressable { return 0.94 }
        guard hovering else { return 1 }
        // Big shapes only need a hint; the bare notch gets Alcove's full 1.075× breath.
        switch shown {
        case .idle: return 1.075
        case .compact, .peek, .hud: return 1.04
        default: return 1.015
        }
    }

    /// Only the pill-like states squeeze when pressed; panels with buttons stay put.
    private var isPressable: Bool {
        switch shown {
        case .idle, .compact, .peek, .hud: true
        case .banner, .device, .open: false
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !viewModel.isPressed && isPressable { viewModel.isPressed = true } }
            .onEnded { _ in viewModel.isPressed = false }
    }

    private func handleTap() {
        switch shown {
        case .open:
            break
        case .banner:
            guard let banner = app.activity.banner else { return }
            if banner.permissionID != nil { return }
            if banner.style == .adventure {
                viewModel.open(page: .adventure)
            } else if let sessionID = banner.sessionID {
                app.claude.focus(sessionID: sessionID)
                app.activity.dismissBanner(id: banner.id)
            } else {
                viewModel.open()
            }
        default:
            viewModel.open()
        }
    }
}

/// Picks the content for a presentation and cross-fades between them.
private struct NotchContentView: View {
    let viewModel: NotchViewModel
    let presentation: NotchPresentation

    @Environment(AppModel.self) private var app

    var body: some View {
        let layout = viewModel.layout
        ZStack(alignment: .top) {
            switch presentation {
            case .idle:
                Color.clear
            case .compact(let activity):
                CompactActivityView(activity: activity, layout: layout, wingWidth: layout.wingWidth(for: activity))
                    .transition(.notchWing)
            case .peek:
                MediaPeekView(layout: layout)
                    .transition(.notchWing)
            case .hud:
                if let event = app.activity.hud {
                    HUDView(event: event, layout: layout)
                        .transition(.notchWing)
                }
            case .banner(let id, _):
                if let banner = app.activity.banner, banner.id == id {
                    BannerView(banner: banner, layout: layout)
                        .id(id)
                        .transition(.notchPanel)
                }
            case .device:
                if let connection = app.activity.connection {
                    DeviceConnectionView(connection: connection, layout: layout)
                        .id(connection.id)
                        .transition(.notchPanel)
                }
            case .open:
                ExpandedView(viewModel: viewModel)
                    .frame(width: layout.size(for: .open).width, height: layout.size(for: .open).height, alignment: .top)
                    .transition(.notchPanel)
            }
        }
    }
}
