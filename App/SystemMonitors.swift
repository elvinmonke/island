import Foundation
import CoreAudio
import AudioToolbox
import IOKit
import IOKit.ps
import IOKit.hid
import AppKit
import Combine

func islandLog(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    let path = "/tmp/island_debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

// MARK: - Volume Monitor

final class VolumeMonitor: ObservableObject {
    @Published var volume: Float = 0

    private var timer: Timer?
    private var lastVolume: Float = -1
    private var deviceID: AudioDeviceID = 0

    init() {
        deviceID = Self.getDefaultOutputDevice()
        volume = Self.getVolume(deviceID)
        lastVolume = volume
        addVolumeListeners(for: deviceID)
        addDeviceChangeListener()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            let v = Self.getVolume(self.deviceID)
            guard v >= 0, abs(v - self.lastVolume) > 0.001 else { return }
            self.lastVolume = v
            self.volume = v
        }
    }

    deinit { timer?.invalidate() }

    private func addVolumeListeners(for device: AudioDeviceID) {
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            guard AudioObjectHasProperty(device, &address) else { continue }
            AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main) { [weak self] _, _ in
                guard let self else { return }
                let v = Self.getVolume(self.deviceID)
                guard v >= 0 else { return }
                self.lastVolume = v
                self.volume = v
            }
        }
    }

    private func addDeviceChangeListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self else { return }
            self.deviceID = Self.getDefaultOutputDevice()
            let v = Self.getVolume(self.deviceID)
            if v >= 0 { self.lastVolume = v; self.volume = v }
            self.addVolumeListeners(for: self.deviceID)
        }
    }

    static func getVolume(_ deviceID: AudioDeviceID) -> Float {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)

        for element: UInt32 in [1, 2, kAudioObjectPropertyElementMain] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
            return volume
        }

        let script = NSAppleScript(source: "output volume of (get volume settings)")
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let val = result?.int32Value {
            return Float(val) / 100.0
        }

        return -1
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

// MARK: - Audio Device Monitor (AirPods / Bluetooth detection)

struct ConnectedAudioDevice: Equatable {
    let name: String
    let isAirPods: Bool
}

final class AudioDeviceMonitor: ObservableObject {
    @Published var connectedDevice: ConnectedAudioDevice? = nil

    private var lastDeviceID: AudioDeviceID = 0
    private var dismissWork: DispatchWorkItem?

    init() {
        lastDeviceID = VolumeMonitor.getDefaultOutputDevice()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main
        ) { [weak self] _, _ in
            self?.checkDeviceChange()
        }
    }

    private func checkDeviceChange() {
        let newDevice = VolumeMonitor.getDefaultOutputDevice()
        let transport = Self.getTransportType(newDevice)
        let name = Self.getDeviceName(newDevice)
        islandLog("AudioDevice changed: id=\(newDevice) lastId=\(lastDeviceID) name=\(name) transport=\(String(format: "0x%08X", transport))")

        guard newDevice != lastDeviceID else { return }
        lastDeviceID = newDevice

        let isBluetooth = transport == 0x626C7565 // 'blue' (Bluetooth)
            || transport == 0x626C7468 // 'blth'
        islandLog("Transport check: 0x\(String(format: "%08X", transport)) isBT=\(isBluetooth)")
        guard isBluetooth else {
            islandLog("Not bluetooth, skipping")
            return
        }

        let isAirPods = name.lowercased().contains("airpods")
        islandLog("Bluetooth device connected: \(name) isAirPods=\(isAirPods)")

        dismissWork?.cancel()
        connectedDevice = ConnectedAudioDevice(name: name, isAirPods: isAirPods)
        let work = DispatchWorkItem { [weak self] in
            self?.connectedDevice = nil
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }

    static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr else {
            return "Audio Device"
        }
        var cfName: CFString = "" as CFString
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &cfName) == noErr else {
            return "Audio Device"
        }
        return cfName as String
    }

    static func getTransportType(_ deviceID: AudioDeviceID) -> UInt32 {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        return transport
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

// MARK: - Device Battery Monitor

struct DeviceBattery: Identifiable, Equatable {
    let id: String
    let name: String
    let level: Int
    let levelLeft: Int?
    let levelRight: Int?
    let levelCase: Int?
    let category: DeviceCategory

    enum DeviceCategory: String {
        case airpods, headphones, mouse, keyboard, trackpad, gamepad, other
    }

    var icon: String {
        switch category {
        case .airpods:    return "airpodspro"
        case .headphones: return "headphones"
        case .mouse:      return "magicmouse"
        case .keyboard:   return "keyboard"
        case .trackpad:   return "trackpad"
        case .gamepad:    return "gamecontroller"
        case .other:      return "battery.100percent"
        }
    }

    var hasIndividualLevels: Bool { levelLeft != nil || levelRight != nil }
}

final class DeviceBatteryMonitor: ObservableObject {
    @Published var devices: [DeviceBattery] = []

    private var timer: Timer?

    init() {
        refreshAsync()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshAsync()
        }
    }

    deinit { timer?.invalidate() }

    private func refreshAsync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let devs = Self.getDeviceBatteries()
            DispatchQueue.main.async { self?.devices = devs }
        }
    }

    static func getDeviceBatteries() -> [DeviceBattery] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        do { try proc.run() } catch { return [] }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let btArray = json["SPBluetoothDataType"] as? [[String: Any]],
              let bt = btArray.first else { return [] }

        var result: [DeviceBattery] = []

        for section in ["device_connected", "device_not_connected"] {
            guard let deviceList = bt[section] as? [[String: Any]] else { continue }
            for deviceDict in deviceList {
                for (name, value) in deviceDict {
                    guard let info = value as? [String: Any] else { continue }
                    let hasBattery = info.keys.contains(where: { $0.contains("battery") })
                    guard hasBattery else { continue }

                    let overall = parsePercent(info["device_batteryLevel"] as? String)
                    let left = parsePercent(info["device_batteryLevelLeft"] as? String)
                    let right = parsePercent(info["device_batteryLevelRight"] as? String)
                    let caseLevel = parsePercent(info["device_batteryLevelCase"] as? String)

                    let level = overall ?? left ?? right ?? 0
                    guard level > 0 else { continue }

                    let minorType = info["device_minorType"] as? String ?? ""
                    let cat = categorize(name, minorType: minorType)
                    let addr = info["device_address"] as? String ?? name

                    result.append(DeviceBattery(
                        id: addr, name: name, level: level,
                        levelLeft: left, levelRight: right, levelCase: caseLevel,
                        category: cat
                    ))
                }
            }
        }

        return result
    }

    private static func parsePercent(_ str: String?) -> Int? {
        guard let s = str else { return nil }
        let digits = s.filter(\.isNumber)
        return Int(digits)
    }

    private static func categorize(_ name: String, minorType: String) -> DeviceBattery.DeviceCategory {
        let lower = name.lowercased()
        if lower.contains("airpods") { return .airpods }
        if lower.contains("beats") || lower.contains("buds") { return .headphones }
        if minorType.lowercased().contains("headphone") { return lower.contains("airpods") ? .airpods : .headphones }
        if lower.contains("mouse") { return .mouse }
        if lower.contains("keyboard") { return .keyboard }
        if lower.contains("trackpad") { return .trackpad }
        if lower.contains("controller") || lower.contains("dualsense") || lower.contains("xbox") { return .gamepad }
        return .other
    }
}
