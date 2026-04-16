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

    var isPlaying: Bool { nowPlaying.isPlaying }
    var hasContent: Bool { !nowPlaying.title.isEmpty }
    var activeNotification: IslandNotification? { notificationMonitor.activeNotification }

    private let mediaRemote = MediaRemoteBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var hudDismissWork: DispatchWorkItem?
    private var lockDismissWork: DispatchWorkItem?
    private var elapsedTimer: Timer?
    private var pollTimer: Timer?

    init() {
        mediaRemote.register()
        fetchNowPlaying()
        setupObservers()
        startElapsedTimer()
        registerLockNotifications()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: MediaRemoteBridge.infoChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.fetchNowPlaying() }

        NotificationCenter.default.addObserver(
            forName: MediaRemoteBridge.appPlayingChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.fetchNowPlaying() }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }

        volumeMonitor.$volume
            .dropFirst()
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
        let work = DispatchWorkItem { [weak self] in
            self?.activeHUD = nil
        }
        hudDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: - Activity Cycling

    func cycleActivity() {
        let tabs = ActivityTab.allCases
        guard let idx = tabs.firstIndex(of: activeTab) else { return }
        activeTab = tabs[(idx + 1) % tabs.count]
    }

    // MARK: - Lock / Unlock

    private func registerLockNotifications() {
        let center = DistributedNotificationCenter.default()

        center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.handleLock() }

        center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main
        ) { [weak self] _ in self?.handleUnlock() }
    }

    private func handleLock() {
        lockDismissWork?.cancel()
        lockState = .locking
        let work = DispatchWorkItem { [weak self] in
            self?.lockState = nil
        }
        lockDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func handleUnlock() {
        lockDismissWork?.cancel()
        lockState = .unlocking
        let work = DispatchWorkItem { [weak self] in
            self?.lockState = nil
        }
        lockDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    // MARK: - Notification shortcuts

    func acceptCall() { notificationMonitor.acceptCall() }
    func declineCall() { notificationMonitor.declineCall() }
    func dismissNotification() { notificationMonitor.dismissNotification() }
}
