import AppKit
import SwiftUI

/// Drops out of the notch when headphones or a speaker take over the audio: the device inside a
/// ring that spins while connecting, then closes into a battery gauge with a check.
struct DeviceConnectionView: View {
    let connection: ConnectionFlash
    let layout: NotchLayout

    var body: some View {
        VStack(spacing: 0) {
            header
                .frame(height: layout.notch.height)
            HStack(spacing: 14) {
                ConnectionRing(
                    symbol: connection.symbols.device,
                    isConnected: connection.isConnected,
                    level: connection.battery?.headline
                )
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(connection.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    StatusLine(connection: connection)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if connection.isConnected, let battery = connection.battery {
                    BatteryCluster(battery: battery, symbols: connection.symbols)
                        .transition(.blurReplace)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 18)
            .padding(.bottom, 10)
            .frame(maxHeight: .infinity)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: connection.isConnected)
        .onChange(of: connection.isConnected) { _, connected in
            if connected { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now) }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: connection.isAirPlay ? "airplayaudio" : "wave.3.right")
                    .font(.system(size: 10, weight: .bold))
                Text(connection.isAirPlay ? "AirPlay" : "Bluetooth")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.5))
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: layout.notch.width)
            Color.clear.frame(maxWidth: .infinity)
        }
    }
}

private struct StatusLine: View {
    let connection: ConnectionFlash

    var body: some View {
        HStack(spacing: 5) {
            if connection.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                Text("Connected")
                    .transition(.blurReplace)
            } else {
                Text("Connecting")
                    .transition(.blurReplace)
                ThinkingDots(color: .white.opacity(0.6))
                    .scaleEffect(0.8)
            }
            if let model = connection.modelName, Self.isInformative(model: model, name: connection.name) {
                Text("· \(model)")
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
    }

    /// "휘나물4 · AirPods 4" helps; "AirPods Pro · AirPods Pro (2nd generation)" just repeats itself.
    static func isInformative(model: String, name: String) -> Bool {
        let model = model.lowercased(), name = name.lowercased()
        let family = model.components(separatedBy: " (").first ?? model
        return !name.contains(family) && !family.contains(name)
    }
}

/// The signature element: a comet arc orbits the device while it connects, then sweeps into a full
/// ring and settles as a gauge of the lowest battery.
private struct ConnectionRing: View {
    let symbol: String
    let isConnected: Bool
    let level: Int?

    @State private var start = Date()
    /// Where the comet was when the connection resolved; the sweep continues from there.
    @State private var frozenAngle: Double?
    @State private var settled = false
    @State private var showsGauge = false
    @State private var checkScale: CGFloat = 0

    private let lineWidth: CGFloat = 3.2

    private func angle(at elapsed: TimeInterval) -> Double {
        // Eases in over the first moments, then orbits at ~1.1 turns per second.
        elapsed * 400 - 180 * exp(-elapsed * 4)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: frozenAngle != nil)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let spin = frozenAngle ?? angle(at: elapsed)
            ZStack {
                Circle().fill(.white.opacity(0.07))
                Circle().stroke(.white.opacity(0.09), lineWidth: lineWidth)

                // The comet: bright head, fading tail.
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            colors: [.white.opacity(0), .white.opacity(0.35), .white],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(108)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .shadow(color: .white.opacity(0.55), radius: 3)
                    .rotationEffect(.degrees(spin))
                    .opacity(settled ? 0 : 1)

                // Connected: the arc sweeps closed in green.
                Circle()
                    .trim(from: 0, to: settled ? 1 : 0.3)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .shadow(color: .green.opacity(0.5), radius: 4)
                    .rotationEffect(.degrees(spin))
                    .opacity(settled && !showsGauge ? 1 : 0)

                // Then it becomes a gauge of the emptiest battery, from twelve o'clock.
                if let level {
                    Circle()
                        .trim(from: 0, to: showsGauge ? CGFloat(level) / 100 : 1)
                        .stroke(level <= 20 ? Color.red : Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .opacity(showsGauge ? 1 : 0)
                }

                DeviceSymbol(name: symbol, fallback: "headphones")
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.45))
                    .scaleEffect(settled ? 1 : 0.94 + 0.04 * sin(elapsed * 5))
                    .symbolEffect(.bounce, value: settled)
            }
            .padding(lineWidth / 2)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8.5, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 17, height: 17)
                    .background(.green, in: Circle())
                    .overlay(Circle().stroke(.black, lineWidth: 2))
                    .scaleEffect(checkScale)
                    .offset(x: 2, y: 2)
            }
        }
        .onChange(of: isConnected, initial: true) { _, connected in
            guard connected, frozenAngle == nil else { return }
            let current = angle(at: Date().timeIntervalSince(start))
            frozenAngle = current
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                settled = true
                frozenAngle = current + 110
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.2)) {
                checkScale = 1
            }
            if level != nil {
                // Hold the closed ring for a beat before it becomes the battery gauge. (An animation
                // delay would flip the state at once and skip the green ring entirely.)
                Task {
                    try? await Task.sleep(for: .milliseconds(850))
                    withAnimation(.spring(response: 0.75, dampingFraction: 0.86)) { showsGauge = true }
                }
            }
        }
    }
}

/// L/R/case levels like the iPhone's AirPods card; buds merge when they match.
private struct BatteryCluster: View {
    let battery: DeviceBattery
    let symbols: DeviceSymbols

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let level: Int
    }

    private var items: [Item] {
        var items: [Item] = []
        if let left = battery.left, let right = battery.right {
            if abs(left - right) <= 5 {
                items.append(Item(id: "buds", symbol: symbols.device, level: min(left, right)))
            } else {
                items.append(Item(id: "left", symbol: symbols.left ?? symbols.device, level: left))
                items.append(Item(id: "right", symbol: symbols.right ?? symbols.device, level: right))
            }
        } else if let bud = battery.left ?? battery.right {
            items.append(Item(id: "bud", symbol: symbols.device, level: bud))
        }
        if let chargingCase = battery.chargingCase {
            items.append(Item(id: "case", symbol: symbols.chargingCase ?? "airpods.chargingcase.fill", level: chargingCase))
        }
        if items.isEmpty, let main = battery.main {
            items.append(Item(id: "main", symbol: symbols.device, level: main))
        }
        return items
    }

    @State private var appeared = 0

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 4) {
                    DeviceSymbol(name: item.symbol, fallback: symbols.device)
                        .font(.system(size: 15))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white.opacity(0.9), .white.opacity(0.4))
                        .frame(height: 18)
                    Text("\(item.level)%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(item.level <= 20 ? .red : .white.opacity(0.8))
                    Capsule()
                        .fill(.white.opacity(0.14))
                        .frame(width: 22, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(item.level <= 20 ? Color.red : Color.green)
                                .frame(width: 22 * CGFloat(item.level) / 100)
                        }
                }
                .opacity(appeared > index ? 1 : 0)
                .blur(radius: appeared > index ? 0 : 6)
                .offset(y: appeared > index ? 0 : 4)
            }
        }
        .task {
            // Stagger each item in, left to right.
            for index in items.indices {
                try? await Task.sleep(for: .milliseconds(index == 0 ? 120 : 90))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { appeared = index + 1 }
            }
        }
    }
}

/// An SF Symbol that falls back gracefully when a newer device symbol is missing on this macOS.
private struct DeviceSymbol: View {
    let name: String
    let fallback: String

    var body: some View {
        Image(systemName: NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : fallback)
    }
}
