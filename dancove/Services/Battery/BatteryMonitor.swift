import Foundation
import IOKit.ps
import Observation

/// Battery level and charging state, with live activities for plugging in and running low.
@Observable
final class BatteryMonitor {
    private(set) var hasBattery = false
    private(set) var level: Int = 100
    private(set) var isCharging = false
    private(set) var isPluggedIn = false
    private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// Minutes until full, when macOS has an estimate.
    private(set) var minutesToFull: Int?

    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var alertedLevels: Set<Int> = []
    @ObservationIgnored private var hasSnapshot = false

    init(activity: ActivityCenter, preferences: Preferences) {
        self.activity = activity
        self.preferences = preferences
    }

    func start() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(batteryChanged, context)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = source
        }
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }

    fileprivate func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            hasBattery = false
            return
        }
        let internalBattery = sources.lazy
            .compactMap { IOPSGetPowerSourceDescription(snapshot, $0)?.takeUnretainedValue() as? [String: Any] }
            .first { ($0[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType }
        guard let description = internalBattery else {
            hasBattery = false
            return
        }

        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = max(description[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
        let newLevel = Int((Double(current) / Double(maximum) * 100).rounded())
        let pluggedIn = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        let toFull = description[kIOPSTimeToFullChargeKey] as? Int

        let wasPluggedIn = isPluggedIn
        hasBattery = true
        level = newLevel
        isPluggedIn = pluggedIn
        isCharging = charging
        minutesToFull = (toFull ?? -1) > 0 ? toFull : nil

        defer { hasSnapshot = true }
        guard hasSnapshot else { return }

        if pluggedIn && !wasPluggedIn && preferences.batteryActivityEnabled {
            activity.flashCharging()
        }
        if pluggedIn { alertedLevels.removeAll() }
        checkLowBattery()
    }

    private func checkLowBattery() {
        guard preferences.lowBatteryAlerts, !isPluggedIn else { return }
        for threshold in [20, 10, 5] where level <= threshold && !alertedLevels.contains(threshold) {
            alertedLevels.formUnion([20, 10, 5].filter { $0 >= threshold })
            activity.post(NotchBanner(
                style: .batteryLow,
                title: String(localized: "Low Battery"),
                subtitle: String(localized: "\(level)% remaining"),
                detail: isLowPowerMode ? nil : String(localized: "Plug in soon or turn on Low Power Mode."),
                duration: 5
            ))
            break
        }
    }
}

nonisolated private func batteryChanged(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated { monitor.refresh() }
}
