import Foundation
import CoreAudio
import IOKit
import IOKit.ps
import AppKit
import Combine

// MARK: - Volume Monitor

final class VolumeMonitor: ObservableObject {
    @Published var volume: Float = 0

    private var timer: Timer?
    private var lastVolume: Float = -1

    init() {
        volume = Self.getVolume()
        lastVolume = volume
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let v = Self.getVolume()
            if abs(v - self.lastVolume) > 0.003 {
                self.lastVolume = v
                self.volume = v
            }
        }
    }

    deinit { timer?.invalidate() }

    static func getVolume() -> Float {
        let deviceID = getDefaultOutputDevice()
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
            return volume
        }

        address.mElement = 1
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
            return volume
        }

        return 0.5
    }

    static func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }
}

// MARK: - Brightness Monitor

final class BrightnessMonitor: ObservableObject {
    @Published var brightness: Float = 1.0

    private var timer: Timer?
    private var lastBrightness: Float = -1

    init() {
        brightness = Self.getBrightness()
        lastBrightness = brightness
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            let b = Self.getBrightness()
            if abs(b - self.lastBrightness) > 0.005 {
                self.lastBrightness = b
                self.brightness = b
            }
        }
    }

    deinit { timer?.invalidate() }

    static func getBrightness() -> Float {
        var brightness: Float = 1.0
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator
        )
        guard result == kIOReturnSuccess else { return brightness }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var val: Float = 0
            IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &val)
            brightness = val
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return brightness
    }
}

// MARK: - Battery Monitor

struct BatteryInfo {
    var level: Int = 100
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var minutesRemaining: Int? = nil
    var hasBattery: Bool = false
}

final class BatteryMonitor: ObservableObject {
    @Published var info = BatteryInfo()

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        info = Self.getBatteryInfo()
    }

    static func getBatteryInfo() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return BatteryInfo() }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }

            let type = desc[kIOPSTransportTypeKey] as? String ?? ""
            guard type == kIOPSInternalType else { continue }

            let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let powerState = desc[kIOPSPowerSourceStateKey] as? String ?? ""
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int
            let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int

            let level = maxCapacity > 0 ? (capacity * 100) / maxCapacity : capacity
            let isPluggedIn = powerState == kIOPSACPowerValue

            var minutes: Int? = nil
            if isCharging, let ttf = timeToFull, ttf > 0 {
                minutes = ttf
            } else if !isCharging, let tte = timeToEmpty, tte > 0 {
                minutes = tte
            }

            return BatteryInfo(
                level: level,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                minutesRemaining: minutes,
                hasBattery: true
            )
        }
        return BatteryInfo()
    }
}
