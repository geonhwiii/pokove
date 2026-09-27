import Foundation
import UniformTypeIdentifiers

/// Model and battery details for a Bluetooth audio device, read from `system_profiler`.
///
/// IOBluetooth would need Bluetooth permission; the system profiler already reports AirPods
/// battery levels (left, right, case) and the product ID that identifies the model.
nonisolated struct BluetoothDeviceInfo: Equatable, Sendable {
    var modelName: String?
    var symbols: DeviceSymbols?
    var battery: DeviceBattery?

    /// Looks the device up by address (preferred) or name. Returns nil if it can't be found in time.
    nonisolated static func lookup(address: String?, name: String) async -> BluetoothDeviceInfo? {
        guard let data = await runProfiler(timeout: 3) else { return nil }
        return parse(data, address: address, name: name)
    }

    nonisolated static func parse(_ data: Data, address: String?, name: String) -> BluetoothDeviceInfo? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }

        var candidates: [(name: String, info: [String: Any])] = []
        for section in sections {
            for key in ["device_connected", "device_not_connected"] {
                for entry in section[key] as? [[String: Any]] ?? [] {
                    for (deviceName, info) in entry {
                        if let info = info as? [String: Any] { candidates.append((deviceName, info)) }
                    }
                }
            }
        }
        let normalizedAddress = address?.uppercased()
        let match = candidates.first { ($0.info["device_address"] as? String)?.uppercased() == normalizedAddress && normalizedAddress != nil }
            ?? candidates.first { $0.name == name }
        guard let info = match?.info else { return nil }

        func level(_ key: String) -> Int? {
            (info[key] as? String).flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "% "))) }
        }
        let battery = DeviceBattery(
            left: level("device_batteryLevelLeft"),
            right: level("device_batteryLevelRight"),
            chargingCase: level("device_batteryLevelCase"),
            main: level("device_batteryLevelMain")
        )
        let productID = (info["device_productID"] as? String).flatMap { Int($0.dropFirst(2), radix: 16) }
        return BluetoothDeviceInfo(
            modelName: productID.flatMap(modelName(forProductID:)),
            symbols: productID.flatMap(DeviceSymbols.forProductID),
            battery: battery.isEmpty ? nil : battery
        )
    }

    /// "AirPods 4", "AirPods Pro (2nd generation)"… localized, from the system's device types.
    nonisolated static func modelName(forProductID id: Int) -> String? {
        let tagClass = UTTagClass(rawValue: "com.apple.device-model-code")
        guard let type = UTType(tag: "Device1,\(id)", tagClass: tagClass, conformingTo: nil),
              !type.isDynamic else { return nil }
        return type.localizedDescription
    }

    private nonisolated static func runProfiler(timeout: TimeInterval) async -> Data? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            let lock = NSLock()
            nonisolated(unsafe) var finished = false
            func finish(_ data: Data?) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                continuation.resume(returning: data)
            }

            // Read on a background queue so a large report can't fill the pipe and stall.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                } catch {
                    finish(nil)
                    return
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning { process.terminate() }
                    finish(nil)
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                finish(process.terminationStatus == 0 ? data : nil)
            }
        }
    }
}
