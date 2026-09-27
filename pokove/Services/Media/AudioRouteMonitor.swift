import CoreAudio
import Foundation

/// Announces when audio output moves to headphones or speakers (AirPods connecting, etc.).
/// Uses the default-output change as the signal, so it needs no Bluetooth permission.
final class AudioRouteMonitor {
    private let activity: ActivityCenter
    private let preferences: Preferences
    private var listener: AudioObjectPropertyListenerBlock?
    private var lastDeviceID = AudioOutputDevices.defaultOutputID
    private let startedAt = Date()
    private var lookupTask: Task<Void, Never>?

    /// The ring spins at least this long, so "connecting" reads before it resolves.
    static let minimumSpin: Duration = .milliseconds(1150)

    init(activity: ActivityCenter, preferences: Preferences) {
        self.activity = activity
        self.preferences = preferences
    }

    func start() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.outputChanged() }
        }
        self.listener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }

    private func outputChanged() {
        let id = AudioOutputDevices.defaultOutputID
        defer { lastDeviceID = id }
        guard id != lastDeviceID, Date().timeIntervalSince(startedAt) > 3, preferences.connectivityEnabled,
              let device = AudioOutputDevices.current, device.isPersonal else { return }
        announce(
            name: device.name,
            transport: device.transport,
            address: AudioOutputDevices.bluetoothAddress(of: device.id)
        )
    }

    /// Plays the connection card with sample AirPods, for settings and screenshots.
    func previewConnection() {
        announce(
            name: "AirPods Pro",
            transport: kAudioDeviceTransportTypeBluetooth,
            address: nil,
            simulated: BluetoothDeviceInfo(
                modelName: BluetoothDeviceInfo.modelName(forProductID: 0x2024) ?? "AirPods Pro",
                symbols: DeviceSymbols.forProductID(0x2024),
                battery: DeviceBattery(left: 84, right: 81, chargingCase: 62)
            )
        )
    }

    /// Shows the connecting card, then fills in the model and battery once they're known.
    func announce(name: String, transport: UInt32, address: String?, simulated: BluetoothDeviceInfo? = nil) {
        let flash = ConnectionFlash(
            name: name,
            symbols: DeviceSymbols.guess(name: name, transport: transport),
            isAirPlay: transport == kAudioDeviceTransportTypeAirPlay
        )
        activity.beginConnection(flash)

        lookupTask?.cancel()
        let isBluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        lookupTask = Task { [weak self] in
            async let info = Self.details(simulated: simulated, isBluetooth: isBluetooth, address: address, name: name)
            try? await Task.sleep(for: Self.minimumSpin)
            let details = await info
            guard !Task.isCancelled, let self else { return }
            self.activity.completeConnection(id: flash.id) { flash in
                guard let details else { return }
                flash.battery = details.battery
                flash.modelName = details.modelName
                if let symbols = details.symbols { flash.symbols = symbols }
            }
        }
    }
}

extension AudioRouteMonitor {
    nonisolated static func details(simulated: BluetoothDeviceInfo?, isBluetooth: Bool, address: String?, name: String) async -> BluetoothDeviceInfo? {
        if let simulated { return simulated }
        guard isBluetooth else { return nil }
        return await BluetoothDeviceInfo.lookup(address: address, name: name)
    }
}

/// A headphone or speaker that just became the audio output.
struct ConnectionFlash: Equatable, Identifiable {
    let id = UUID()
    var name: String
    var symbols: DeviceSymbols
    var isAirPlay = false
    var modelName: String?
    var battery: DeviceBattery?
    /// False while the ring spins; true once the details have loaded.
    var isConnected = false
}

nonisolated struct DeviceBattery: Equatable, Sendable {
    var left: Int?
    var right: Int?
    var chargingCase: Int?
    /// Single-battery devices: AirPods Max, Beats headphones, speakers.
    var main: Int?

    var isEmpty: Bool { left == nil && right == nil && chargingCase == nil && main == nil }

    /// The level the ring shows: the emptiest bud, or the device's only battery.
    var headline: Int? {
        let buds = [left, right].compactMap { $0 }
        return buds.min() ?? main
    }
}

/// SF Symbols for a device and, for earbuds, each bud and the case.
nonisolated struct DeviceSymbols: Equatable, Sendable {
    var device: String
    var left: String?
    var right: String?
    var chargingCase: String?

    static let headphones = DeviceSymbols(device: "headphones")

    /// Apple's Bluetooth product IDs for AirPods and Beats.
    static func forProductID(_ id: Int) -> DeviceSymbols? {
        switch id {
        case 0x2002, 0x200F:
            DeviceSymbols(device: "airpods", chargingCase: "airpods.chargingcase.fill")
        case 0x2013:
            DeviceSymbols(device: "airpods.gen3", left: "airpod.gen3.left", right: "airpod.gen3.right",
                          chargingCase: "airpods.gen3.chargingcase.wireless.fill")
        case 0x2019, 0x201B, 0x201C, 0x201E, 0x2020, 0x2026, 0x2030:
            DeviceSymbols(device: "airpods.gen4", left: "airpods.gen4.left", right: "airpods.gen4.right",
                          chargingCase: "airpods.gen4.chargingcase.wireless.fill")
        case 0x200E, 0x2014, 0x2024:
            DeviceSymbols(device: "airpods.pro", left: "airpods.pro.left", right: "airpods.pro.right",
                          chargingCase: "airpods.pro.chargingcase.wireless.fill")
        case 0x2027:
            DeviceSymbols(device: "airpods.pro.gen3", left: "airpods.pro.gen3.left", right: "airpods.pro.gen3.right",
                          chargingCase: "airpods.pro.gen3.chargingcase.wireless.fill")
        case 0x200A, 0x201F, 0x202D:
            DeviceSymbols(device: "airpods.max")
        case 0x2010, 0x2011, 0x2016, 0x2017, 0x2025, 0x2028:
            DeviceSymbols(device: "beats.headphones")
        case 0x2012, 0x200B, 0x200C, 0x200D, 0x2015:
            DeviceSymbols(device: "beats.earphones")
        case 0x201D, 0x2021:
            DeviceSymbols(device: "beats.powerbeats.pro")
        default:
            nil
        }
    }

    /// Best guess from the device name, used until (or instead of) the product ID.
    static func guess(name: String, transport: UInt32) -> DeviceSymbols {
        let lowered = name.lowercased()
        if lowered.contains("airpods max") { return DeviceSymbols(device: "airpods.max") }
        if lowered.contains("airpods pro") {
            return DeviceSymbols(device: "airpods.pro", left: "airpods.pro.left", right: "airpods.pro.right",
                                 chargingCase: "airpods.pro.chargingcase.wireless.fill")
        }
        if lowered.contains("airpods") {
            return DeviceSymbols(device: "airpods.gen4", left: "airpods.gen4.left", right: "airpods.gen4.right",
                                 chargingCase: "airpods.gen4.chargingcase.wireless.fill")
        }
        if lowered.contains("beats") { return DeviceSymbols(device: "beats.headphones") }
        if lowered.contains("homepod") { return DeviceSymbols(device: "homepod.fill") }
        if transport == kAudioDeviceTransportTypeAirPlay {
            return DeviceSymbols(device: lowered.contains("tv") ? "appletv.fill" : "hifispeaker.fill")
        }
        if lowered.contains("speaker") || lowered.contains("sound") { return DeviceSymbols(device: "hifispeaker.fill") }
        return .headphones
    }
}

extension AudioOutputDevices.Device {
    /// Devices worth announcing: wireless headphones and speakers, not the built-in output.
    var isPersonal: Bool {
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE, kAudioDeviceTransportTypeAirPlay:
            true
        default:
            false
        }
    }
}
