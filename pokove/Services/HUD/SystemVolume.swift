import AudioToolbox
import CoreAudio
import Foundation

/// Reads and writes the default output device's volume, and reports changes from any source.
final class SystemVolume {
    var onChange: ((_ volume: Float, _ muted: Bool) -> Void)?

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    /// Suppresses change callbacks right after a device switch, which report stale jumps.
    private var quietUntil = Date.distantPast

    init() {
        deviceID = Self.defaultOutputDevice()
        observeDefaultDevice()
        observeDevice()
    }

    deinit {
        MainActor.assumeIsolated {
            removeDeviceListeners()
            if let defaultDeviceListener {
                var address = Self.defaultDeviceAddress
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, defaultDeviceListener)
            }
        }
    }

    // MARK: Volume

    var volume: Float {
        get {
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
            return status == noErr ? value : 0
        }
        set {
            var value = Float32(min(max(newValue, 0), 1))
            let size = UInt32(MemoryLayout<Float32>.size)
            var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
        }
    }

    var isMuted: Bool {
        get {
            var value = UInt32(0)
            var size = UInt32(MemoryLayout<UInt32>.size)
            var address = Self.address(kAudioDevicePropertyMute)
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
            return status == noErr && value != 0
        }
        set {
            var value = UInt32(newValue ? 1 : 0)
            let size = UInt32(MemoryLayout<UInt32>.size)
            var address = Self.address(kAudioDevicePropertyMute)
            AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
        }
    }

    var canSetVolume: Bool {
        var address = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(deviceID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    var canSetMute: Bool {
        var address = Self.address(kAudioDevicePropertyMute)
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr && settable.boolValue
    }

    /// Steps the volume the way the keyboard does, snapping to the step grid.
    func step(by delta: Float) -> (volume: Float, muted: Bool) {
        let steps: Float = abs(delta) < 1.0 / 32 ? 64 : 16
        var target = (volume * steps + (delta > 0 ? 1 : -1)).rounded() / steps
        target = min(max(target, 0), 1)
        volume = target
        if isMuted && delta > 0 { isMuted = false }
        if target == 0 && delta < 0 { isMuted = true }
        return (target, isMuted)
    }

    func toggleMute() -> (volume: Float, muted: Bool) {
        isMuted.toggle()
        return (volume, isMuted)
    }

    // MARK: Observation

    private static let defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private func observeDefaultDevice() {
        var address = Self.defaultDeviceAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.removeDeviceListeners()
                self.deviceID = Self.defaultOutputDevice()
                self.quietUntil = Date().addingTimeInterval(1)
                self.observeDevice()
            }
        }
        defaultDeviceListener = listener
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
    }

    private func observeDevice() {
        let selectors: [(AudioObjectPropertySelector, AudioObjectPropertyElement)] = [
            (kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyElementMain),
            (kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyElementMain),
            (kAudioDevicePropertyVolumeScalar, 1),
            (kAudioDevicePropertyVolumeScalar, 2),
            (kAudioDevicePropertyMute, kAudioObjectPropertyElementMain),
        ]
        for (selector, element) in selectors {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
            guard AudioObjectHasProperty(deviceID, &address) else { continue }
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.notifyChange() }
            }
            if AudioObjectAddPropertyListenerBlock(deviceID, &address, .main, listener) == noErr {
                deviceListeners.append((address, listener))
            }
        }
    }

    private func removeDeviceListeners() {
        for (address, listener) in deviceListeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, .main, listener)
        }
        deviceListeners.removeAll()
    }

    private var lastReported: (Float, Bool)?

    private func notifyChange() {
        guard Date() > quietUntil else { return }
        let current = (volume, isMuted)
        // Stereo devices fire once per channel; report each distinct value once.
        if let lastReported, abs(lastReported.0 - current.0) < 0.001, lastReported.1 == current.1 { return }
        lastReported = current
        onChange?(current.0, current.1)
    }

    // MARK: Helpers

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }

    private static func defaultOutputDevice() -> AudioObjectID {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = defaultDeviceAddress
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }
}
