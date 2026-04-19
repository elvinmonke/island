import Foundation
import Combine
import AppKit

enum HUDKind: Equatable {
    case volume(Float)
    case brightness(Float)
}

enum LockState: Equatable {
    case locking, unlocking
}

enum ActivityTab: Int, CaseIterable {
    case nowPlaying, calendar, battery, timer
}

final class IslandViewModel: ObservableObject {
    @Published var nowPlaying = NowPlayingInfo()
    @Published var currentElapsed: Double = 0
    @Published var activeTab: ActivityTab = .nowPlaying
    @Published var isHovering: Bool = false
    @Published var activeHUD: HUDKind? = nil
    @Published var lockState: LockState? = nil

    let volumeMonitor = VolumeMonitor()
    let brightnessMonitor = BrightnessMonitor()
    let batteryMonitor = BatteryMonitor()
    let calendarMonitor = CalendarMonitor()
    let timerManager = TimerManager()
    let notificationMonitor = NotificationMonitor()
    let audioDeviceMonitor = AudioDeviceMonitor()
    let deviceBatteryMonitor = DeviceBatteryMonitor()

    var isPlaying: Bool { nowPlaying.isPlaying }
    var hasContent: Bool { !nowPlaying.title.isEmpty }
    var activeNotification: IslandNotification? { notificationMonitor.activeNotification }

    var settings: AppSettings?

    private let mediaRemote = MediaRemoteBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var hudDismissWork: DispatchWorkItem?
    private var lockDismissWork: DispatchWorkItem?
    private var isScreenLocked = false
    private var elapsedTimer: Timer?
    private var pollTimer: Timer?

    init() {
        islandLog("IslandViewModel init")
        mediaRemote.register()
        fetchNowPlaying()
        setupObservers()
        startElapsedTimer()
        registerLockNotifications()
        islandLog("All notifications registered")
    }

    private func setupObservers() {
        for name in [MediaRemoteBridge.infoChanged,
                     MediaRemoteBridge.appPlayingChanged,
                     MediaRemoteBridge.playerChanged,
                     MediaRemoteBridge.activePlayerChanged] {
            NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in self?.fetchNowPlaying() }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }

        volumeMonitor.$volume
            .dropFirst()
            .filter { $0 >= 0 }
            .sink { [weak self] vol in self?.showHUD(.volume(vol)) }
            .store(in: &cancellables)

        brightnessMonitor.$brightness
            .dropFirst()
            .sink { [weak self] b in self?.showHUD(.brightness(b)) }
            .store(in: &cancellables)

        notificationMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        batteryMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        calendarMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        timerManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        audioDeviceMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        deviceBatteryMonitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let info = self.nowPlaying
            guard info.isPlaying, info.duration > 0 else { return }
            let timeSince = Date().timeIntervalSince(info.timestamp)
            self.currentElapsed = min(info.elapsed + timeSince * info.playbackRate, info.duration)
        }
    }

    func fetchNowPlaying() {
        mediaRemote.fetch { [weak self] info in
            guard let self else { return }
            self.nowPlaying = info
            if info.isPlaying { self.currentElapsed = info.elapsed }
        }
    }

    // kept for menu item compat
    func refresh() { fetchNowPlaying() }

    // MARK: - Controls

    func playPause() {
        mediaRemote.togglePlayPause()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() }
    }

    func next() {
        mediaRemote.nextTrack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() }
    }

    func previous() {
        mediaRemote.previousTrack()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.fetchNowPlaying() }
    }

    // MARK: - HUD

    private func showHUD(_ kind: HUDKind) {
        hudDismissWork?.cancel()
        activeHUD = kind
        let duration = settings?.hudSpeed.duration ?? 1.8
        let work = DispatchWorkItem { [weak self] in
            self?.activeHUD = nil
        }
        hudDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    // MARK: - Activity Cycling

    func cycleActivity() {
        let tabs = ActivityTab.allCases
        guard let idx = tabs.firstIndex(of: activeTab) else { return }
        activeTab = tabs[(idx + 1) % tabs.count]
    }

    // MARK: - Lock / Unlock

    private func registerLockNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let lockCB: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let vm = Unmanaged<IslandViewModel>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                NSLog("[Island] CFDarwin: screenIsLocked")
                vm.handleLock()
            }
        }
        let unlockCB: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let vm = Unmanaged<IslandViewModel>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async {
                NSLog("[Island] CFDarwin: screenIsUnlocked")
                vm.handleUnlock()
            }
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center, selfPtr, lockCB,
            "com.apple.screenIsLocked" as CFString,
            nil, .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center, selfPtr, unlockCB,
            "com.apple.screenIsUnlocked" as CFString,
            nil, .deliverImmediately
        )

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            NSLog("[Island] screensDidSleep")
            self?.handleLock()
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            NSLog("[Island] screensDidWake")
            self?.handleScreenWake()
        }
        ws.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            NSLog("[Island] sessionDidBecomeActive")
            self?.handleUnlock()
        }
        ws.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            NSLog("[Island] sessionDidResignActive")
            self?.handleLock()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in
            NSLog("[Island] Distributed: screenIsLocked")
            self?.handleLock()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in
            NSLog("[Island] Distributed: screenIsUnlocked")
            self?.handleUnlock()
        }
    }

    private func handleLock() {
        islandLog("handleLock called, isScreenLocked=\(isScreenLocked)")
        guard !isScreenLocked else { return }
        isScreenLocked = true
        lockDismissWork?.cancel()
        lockState = .locking
        NotificationCenter.default.post(name: NSNotification.Name("IslandLockStateChanged"), object: nil)
    }

    private func handleScreenWake() {
        islandLog("handleScreenWake called, isScreenLocked=\(isScreenLocked)")
        if isScreenLocked {
            lockState = .locking
            NotificationCenter.default.post(name: NSNotification.Name("IslandLockStateChanged"), object: nil)
        }
    }

    private func handleUnlock() {
        islandLog("handleUnlock called, isScreenLocked=\(isScreenLocked)")
        guard isScreenLocked else { return }
        isScreenLocked = false
        lockDismissWork?.cancel()
        lockState = .unlocking
        NotificationCenter.default.post(name: NSNotification.Name("IslandLockStateChanged"), object: nil)
        let dismiss = DispatchWorkItem { [weak self] in
            self?.lockState = nil
        }
        lockDismissWork = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: dismiss)
    }

    // MARK: - Notification shortcuts

    func acceptCall() { notificationMonitor.acceptCall() }
    func declineCall() { notificationMonitor.declineCall() }
    func dismissNotification() { notificationMonitor.dismissNotification() }
}
