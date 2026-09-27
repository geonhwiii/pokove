import SwiftUI

extension Color {
    /// Mint for the clipboard, beside the to-do yellow and the calendar red.
    static let clipboard = Color(red: 0.36, green: 0.86, blue: 0.72)
}

/// Clipboard history: how much is kept on the left, what was copied on the right.
/// Clicking an item copies it again (or pastes it, per Settings); hovering shows the rest.
struct ClipboardPageView: View {
    let viewModel: NotchViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            ClipboardSummary()
                .frame(width: 104, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
            ClipboardList(viewModel: viewModel)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

// MARK: Summary

private struct ClipboardSummary: View {
    @Environment(AppModel.self) private var app
    @State private var confirmingClear = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        let clipboard = app.clipboard
        VStack(alignment: .leading, spacing: 0) {
            Text("Clipboard")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.clipboard)
            Text("\(clipboard.items.count)")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.bottom, 2)
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .contentTransition(.opacity)
            Spacer(minLength: 0)
            if clipboard.unpinnedCount > 0 {
                clearButton(count: clipboard.unpinnedCount)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: clipboard.items.count)
        .onDisappear {
            resetTask?.cancel()
            confirmingClear = false
        }
    }

    private var caption: String {
        let clipboard = app.clipboard
        if clipboard.items.isEmpty { return String(localized: "Nothing yet") }
        if clipboard.pinnedCount > 0 { return String(localized: "\(clipboard.pinnedCount) pinned") }
        return String(localized: "items")
    }

    /// Clearing takes a second click, so a stray one never wipes the history.
    private func clearButton(count: Int) -> some View {
        Button {
            if confirmingClear {
                resetTask?.cancel()
                confirmingClear = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { app.clipboard.clearHistory() }
            } else {
                confirmingClear = true
                resetTask?.cancel()
                resetTask = Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.2)) { confirmingClear = false }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: confirmingClear ? "trash.fill" : "trash")
                    .font(.system(size: 10, weight: .semibold))
                Text(confirmingClear ? String(localized: "Clear \(count)?") : String(localized: "Clear"))
                    .font(.system(size: 11.5, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(confirmingClear ? Color(red: 1, green: 0.42, blue: 0.4) : .white.opacity(0.45))
            .padding(.horizontal, 8)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 7))
        .padding(.leading, -8)
        .animation(.smooth(duration: 0.2), value: confirmingClear)
        .help(confirmingClear ? "Click again to clear. Pinned items stay." : "Clear history")
    }
}

// MARK: List

private struct ClipboardList: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app
    /// The row that just got copied, for a moment of "Copied".
    @State private var copiedID: ClipboardItem.ID?
    @State private var copiedTask: Task<Void, Never>?

    var body: some View {
        let clipboard = app.clipboard
        let clickPastes = app.preferences.clipboardClickPastes
        Group {
            if clipboard.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copy something and it shows up here.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Passwords are never saved.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.32))
                }
                .padding(.leading, 6)
                .padding(.top, 6)
                .transition(.opacity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(clipboard.items) { item in
                            ClipboardRow(
                                item: item,
                                isCurrent: clipboard.currentID == item.id,
                                didCopy: copiedID == item.id,
                                clickPastes: clickPastes,
                                copy: { copy(item) },
                                paste: { paste(item) },
                                togglePin: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { clipboard.togglePin(item.id) } },
                                delete: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { clipboard.delete(item.id) } }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .leading))
                            ))
                        }
                    }
                    .padding(.bottom, 8)
                }
                .mask {
                    LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.85),
                        .init(color: .clear, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: clipboard.items.map(\.id))
        .onDisappear { copiedTask?.cancel() }
    }

    private func copy(_ item: ClipboardItem) {
        guard withAnimation(.spring(response: 0.35, dampingFraction: 0.85), { app.clipboard.copy(item.id) }) else { return }
        if app.preferences.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        copiedID = item.id
        copiedTask?.cancel()
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.2)) { copiedID = nil }
        }
    }

    private func paste(_ item: ClipboardItem) {
        viewModel.close()
        app.clipboard.paste(item.id)
    }
}

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isCurrent: Bool
    let didCopy: Bool
    let clickPastes: Bool
    let copy: () -> Void
    let paste: () -> Void
    let togglePin: () -> Void
    let delete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: clickPastes ? paste : copy) {
                HStack(spacing: 9) {
                    ClipboardThumb(item: item)
                        .frame(width: 20, height: 20)
                    ClipboardTitle(item: item)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(clickPastes ? "Paste" : "Copy")

            trailing
        }
        .frame(height: 28)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.05 : 0))
        )
        .overlay(alignment: .leading) {
            if isCurrent {
                // What's on the clipboard right now.
                Capsule()
                    .fill(Color.clipboard)
                    .frame(width: 2.5, height: 12)
                    .offset(x: -1)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.smooth(duration: 0.2), value: isCurrent)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy", action: copy)
            Button("Paste", action: paste)
            Button(item.isPinned ? "Unpin" : "Pin", action: togglePin)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    @ViewBuilder private var trailing: some View {
        if didCopy {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                Text("Copied")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.clipboard)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if isHovering {
            HStack(spacing: 0) {
                if clickPastes {
                    RowAction(symbol: "doc.on.doc", help: "Copy", action: copy)
                } else {
                    RowAction(symbol: "doc.on.clipboard", help: "Paste", action: paste)
                }
                RowAction(symbol: item.isPinned ? "pin.slash" : "pin", help: item.isPinned ? "Unpin" : "Pin", action: togglePin)
                RowAction(symbol: "xmark", help: "Delete", action: delete)
            }
            .transition(.opacity)
        } else {
            HStack(spacing: 4) {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .rotationEffect(.degrees(35))
                        .foregroundStyle(Color.clipboard.opacity(0.85))
                }
                TimelineView(.everyMinute) { context in
                    Text(ClipboardRow.age(of: item.copiedAt, now: context.date))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .transition(.opacity)
        }
    }

    /// "now", "5m", "3h", "2d".
    static func age(of date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return String(localized: "now") }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return String(localized: "\(minutes)m") }
        let hours = minutes / 60
        if hours < 24 { return String(localized: "\(hours)h") }
        return String(localized: "\(hours / 24)d")
    }
}

private struct RowAction: View {
    let symbol: String
    let help: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: symbol == "xmark" ? 8.5 : 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 5))
        .help(help)
    }
}

/// One line saying what was copied.
private struct ClipboardTitle: View {
    let item: ClipboardItem

    var body: some View {
        HStack(spacing: 5) {
            switch item.kind {
            case .text:
                primary(Self.singleLine(item.preview))
            case .link:
                primary(Self.trimScheme(item.preview))
            case .color:
                primary(item.preview.uppercased())
                    .monospaced()
            case .image:
                primary(String(localized: "Image"))
                if let size = item.pixelSize {
                    secondary("\(Int(size.width))×\(Int(size.height))")
                }
            case .files:
                primary(item.paths.first.map { ($0 as NSString).lastPathComponent } ?? item.preview)
                if item.paths.count > 1 {
                    secondary("+\(item.paths.count - 1)")
                }
            }
        }
    }

    private func primary(_ text: String) -> Text {
        Text(verbatim: text)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.92))
    }

    private func secondary(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 11.5, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.4))
            .fixedSize()
    }

    /// Line breaks and runs of spaces folded, so a paragraph reads on one line.
    static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func trimScheme(_ link: String) -> String {
        for scheme in ["https://", "http://"] where link.lowercased().hasPrefix(scheme) {
            return String(link.dropFirst(scheme.count))
        }
        return link
    }
}

/// A picture of what was copied: the image itself, a color swatch, a file icon, or the app it
/// came from.
private struct ClipboardThumb: View {
    let item: ClipboardItem

    @Environment(AppModel.self) private var app

    var body: some View {
        switch item.kind {
        case .image:
            if let image = app.clipboard.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(.white.opacity(0.14)))
            } else {
                symbol("photo")
            }
        case .color:
            Circle()
                .fill(Self.color(from: item.preview))
                .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .frame(width: 15, height: 15)
        case .files:
            if let path = item.paths.first {
                Image(nsImage: app.clipboard.fileIcon(for: path))
                    .resizable()
                    .frame(width: 19, height: 19)
            } else {
                symbol("doc")
            }
        case .link:
            symbol("link")
        case .text:
            if let icon = app.clipboard.appIcon(for: item.sourceBundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 19, height: 19)
            } else {
                symbol("text.alignleft")
            }
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 20, height: 20)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5.5, style: .continuous))
    }

    /// "#RGB" or "#RRGGBB".
    static func color(from hex: String) -> Color {
        var digits = String(hex.drop(while: { $0 == "#" }))
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        return Color(hex: UInt32(digits, radix: 16) ?? 0)
    }
}
