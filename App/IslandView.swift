import SwiftUI

enum IslandState: Equatable {
    case idle, active, expanded, hud, lock, notification, call, airpods
}

// MARK: - Main View

struct IslandView: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    private let notchWidth: CGFloat = 200
    private let notchHeight: CGFloat = 32

    private var state: IslandState {
        if vm.lockState != nil && settings.enableLockScreen { return .lock }
        if vm.audioDeviceMonitor.connectedDevice != nil { return .airpods }
        if vm.activeHUD != nil {
            if case .volume = vm.activeHUD, !settings.enableVolume { } else
            if case .brightness = vm.activeHUD, !settings.enableBrightness { } else
            { return .hud }
        }
        if vm.activeNotification?.kind == .call { return .call }
        if vm.activeNotification != nil { return .notification }
        if hovering && settings.expandOnHover { return .expanded }
        if (vm.isPlaying && settings.enableNowPlaying) || (vm.timerManager.isRunning && settings.enableTimer) { return .active }
        return .idle
    }

    private var dropsDown: Bool {
        [.expanded, .airpods, .call, .hud].contains(state)
    }

    private var pillWidth: CGFloat {
        switch state {
        case .idle:         return notchWidth
        case .active:       return 280
        case .expanded:     return 340
        case .hud:          return 380
        case .lock:         return vm.lockState == .locking ? notchWidth : 300
        case .notification: return 380
        case .call:         return 500
        case .airpods:      return 240
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle:         return notchHeight
        case .active:       return notchHeight + 6
        case .expanded:     return 230
        case .hud:          return notchHeight + 28
        case .lock:         return notchHeight + 6
        case .notification: return notchHeight + 20
        case .call:         return 82
        case .airpods:      return 120
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ZStack(alignment: .top) {
                    notchBackground
                    contentLayer
                        .padding(.top, dropsDown ? notchHeight : 0)
                }
                .frame(width: pillWidth, height: pillHeight)
                .clipped()
                .contentShape(Rectangle())
                .onHover { h in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                        hovering = h
                    }
                    vm.isHovering = h
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: state)
    }

    @ViewBuilder
    private var contentLayer: some View {
        switch state {
        case .idle:
            EmptyView()
        case .active:
            ActiveContent()
        case .expanded:
            ExpandedContent()
        case .hud:
            if let hud = vm.activeHUD { HUDContent(kind: hud) }
        case .lock:
            if let lock = vm.lockState { LockContent(state: lock) }
        case .notification:
            NotificationContent()
        case .call:
            CallContent()
        case .airpods:
            if let dev = vm.audioDeviceMonitor.connectedDevice { AirPodsContent(device: dev) }
        }
    }

    @ViewBuilder
    private var notchBackground: some View {
        if settings.glassEffect && !dropsDown {
            NotchShape(notchRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(state == .idle ? 0 : 0.4), radius: 12, y: 4)
        } else {
            NotchShape(notchRadius: dropsDown ? 18 : 12)
                .fill(Color(white: 0.04))
                .shadow(color: .black.opacity(state == .idle ? 0 : 0.5), radius: dropsDown ? 24 : 12, y: 6)
        }
    }
}

struct NotchShape: Shape {
    var notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(notchRadius, rect.height / 2, rect.width / 2)
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        p.addQuadCurve(to: CGPoint(x: rect.width - r, y: rect.height),
                       control: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: r, y: rect.height))
        p.addQuadCurve(to: CGPoint(x: 0, y: rect.height - r),
                       control: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Idle (nothing visible below notch)

// MARK: - Active (compact now playing — expands sideways)

struct ActiveContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        if vm.timerManager.isRunning && !vm.isPlaying {
            timerCompact
        } else {
            nowPlayingCompact
        }
    }

    private var nowPlayingCompact: some View {
        HStack {
            ArtworkView(image: vm.nowPlaying.artwork, size: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Spacer()
            WaveformBars(isPlaying: vm.isPlaying)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerCompact: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.leading, 14)

            Text(vm.timerManager.timeString)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: 1 - vm.timerManager.progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            .padding(.trailing, 14)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Expanded (hover — drops down, iPhone Control Center style)

struct ExpandedContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        VStack(spacing: 0) {
            ActivityTabBar(activeTab: $vm.activeTab, hasTimer: vm.timerManager.totalSeconds > 0)

            Group {
                switch vm.activeTab {
                case .nowPlaying: NowPlayingExpanded()
                case .calendar:   CalendarExpanded()
                case .battery:    BatteryExpanded()
                case .timer:      TimerExpanded()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }
}

struct ActivityTabBar: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var activeTab: ActivityTab
    let hasTimer: Bool

    var body: some View {
        HStack(spacing: 14) {
            if settings.enableNowPlaying { tabIcon("music.note", tab: .nowPlaying) }
            if settings.enableCalendar { tabIcon("calendar", tab: .calendar) }
            if settings.enableBattery { tabIcon("battery.100percent", tab: .battery) }
            if hasTimer && settings.enableTimer { tabIcon("timer", tab: .timer) }
        }
        .padding(.vertical, 4)
    }

    private func tabIcon(_ system: String, tab: ActivityTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { activeTab = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: system)
                    .font(.system(size: 10, weight: activeTab == tab ? .bold : .regular))
                    .foregroundStyle(activeTab == tab ? .white : .white.opacity(0.3))
                    .frame(width: 24, height: 14)
                Circle()
                    .fill(activeTab == tab ? Color.white : Color.clear)
                    .frame(width: 3, height: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Now Playing (Expanded — iPhone Control Center style)

struct NowPlayingExpanded: View {
    @EnvironmentObject var vm: IslandViewModel

    private var progress: Double {
        guard vm.nowPlaying.duration > 0 else { return 0 }
        return min(vm.currentElapsed / vm.nowPlaying.duration, 1.0)
    }

    private var airpodsIcon: String {
        guard let name = vm.audioDeviceMonitor.connectedDevice?.name.lowercased() else { return "airpods.gen3" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods") { return "airpods.gen3" }
        return "headphones"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ArtworkView(image: vm.nowPlaying.artwork, size: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.nowPlaying.title.isEmpty ? "Nothing Playing" : vm.nowPlaying.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(vm.nowPlaying.artist.isEmpty ? "Island" : vm.nowPlaying.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                WaveformBars(isPlaying: vm.isPlaying)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(Color.white.opacity(0.7))
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(formatTime(vm.currentElapsed))
                    Spacer()
                    Text("-\(formatTime(max(0, vm.nowPlaying.duration - vm.currentElapsed)))")
                }
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 10)

            HStack(spacing: 24) {
                ControlButton(system: "shuffle", size: 12) {}
                ControlButton(system: "backward.fill", size: 16) { vm.previous() }
                ControlButton(system: vm.isPlaying ? "pause.fill" : "play.fill", size: 24) { vm.playPause() }
                ControlButton(system: "forward.fill", size: 16) { vm.next() }
                ControlButton(system: vm.audioDeviceMonitor.connectedDevice != nil ? airpodsIcon : "speaker.wave.2.fill", size: 12) {}
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 6)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Calendar (Expanded)

struct CalendarExpanded: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        if vm.calendarMonitor.upcomingEvents.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.3))
                Text(vm.calendarMonitor.hasAccess ? "No upcoming events" : "Calendar access required")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                if !vm.calendarMonitor.hasAccess {
                    Button("Grant Access") { vm.calendarMonitor.requestAccess() }
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.calendarMonitor.upcomingEvents) { event in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(nsColor: event.color))
                                .frame(width: 3, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(event.isAllDay ? "All Day" : formatEventTime(event.startDate))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    private func formatEventTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Battery (Expanded)

struct BatteryExpanded: View {
    @EnvironmentObject var vm: IslandViewModel

    private var battery: BatteryInfo { vm.batteryMonitor.info }
    private var devices: [DeviceBattery] { vm.deviceBatteryMonitor.devices }

    private func colorFor(_ level: Int, charging: Bool = false) -> Color {
        if charging { return .green }
        if level <= 20 { return .red }
        if level <= 50 { return .yellow }
        return .green
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                if battery.hasBattery { macBatteryCard }
                ForEach(devices) { device in deviceBatteryCard(device) }
                if !battery.hasBattery && devices.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "battery.0percent")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No batteries")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private var macBatteryCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: Double(battery.level) / 100.0)
                    .stroke(colorFor(battery.level, charging: battery.isCharging),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    if battery.isCharging {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(.green)
                    }
                    Text("\(battery.level)%")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("MacBook").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text(battery.isCharging ? "Charging" : (battery.isPluggedIn ? "Plugged In" : "Battery"))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                if let mins = battery.minutesRemaining, mins > 0 {
                    Text("\(mins / 60)h \(mins % 60)m")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func deviceBatteryCard(_ device: DeviceBattery) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: Double(device.level) / 100.0)
                    .stroke(colorFor(device.level), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: device.icon).font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if device.hasIndividualLevels {
                    HStack(spacing: 6) {
                        if let l = device.levelLeft {
                            Label("\(l)%", systemImage: "l.circle.fill")
                                .font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(colorFor(l))
                        }
                        if let r = device.levelRight {
                            Label("\(r)%", systemImage: "r.circle.fill")
                                .font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(colorFor(r))
                        }
                        if let c = device.levelCase {
                            Label("\(c)%", systemImage: "case.fill")
                                .font(.system(size: 9, weight: .medium).monospacedDigit()).foregroundStyle(colorFor(c))
                        }
                    }
                } else {
                    Text("\(device.level)%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(colorFor(device.level))
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Timer (Expanded)

struct TimerExpanded: View {
    @EnvironmentObject var vm: IslandViewModel
    @State private var selectedMinutes: Double = 5
    private var timer: TimerManager { vm.timerManager }

    var body: some View {
        HStack(spacing: 20) {
            if timer.totalSeconds > 0 {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: 1 - timer.progress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(timer.timeString)
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 70, height: 70)

                HStack(spacing: 16) {
                    Button { timer.toggle() } label: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }.buttonStyle(.plain)
                    Button { timer.reset() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }.buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 8) {
                    Text("\(Int(selectedMinutes)) min")
                        .font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundStyle(.white)
                    Slider(value: $selectedMinutes, in: 1...60, step: 1).tint(.orange).frame(width: 180)
                    Button { timer.start(minutes: Int(selectedMinutes)) } label: {
                        Text("Start").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 8)
                            .background(Capsule().fill(Color.orange))
                    }.buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }
}

// MARK: - HUD (Volume / Brightness — expands sideways)

struct HUDContent: View {
    @EnvironmentObject var settings: AppSettings
    let kind: HUDKind

    var body: some View {
        HStack(spacing: 10) {
            icon.font(.system(size: 12, weight: .semibold)).frame(width: 18)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(barColor).frame(width: max(0, geo.size.width * CGFloat(level)))
                }
            }
            .frame(height: 4)
            if settings.showHUDPercentage {
                Text("\(Int(level * 100))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 26, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
    }

    private var level: Float {
        switch kind { case .volume(let v): return v; case .brightness(let b): return b }
    }
    @ViewBuilder private var icon: some View {
        switch kind {
        case .volume(let v): Image(systemName: volumeIcon(v)).foregroundStyle(.white)
        case .brightness(let b): Image(systemName: b > 0.5 ? "sun.max.fill" : "sun.min.fill").foregroundStyle(.yellow)
        }
    }
    private var barColor: Color {
        switch kind { case .volume: return .white; case .brightness: return .yellow }
    }
    private func volumeIcon(_ v: Float) -> String {
        if v <= 0 { return "speaker.slash.fill" }
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Lock / Unlock

struct LockContent: View {
    let state: LockState
    @State private var iconScale: CGFloat = 1.0
    @State private var iconOpacity: Double = 1.0
    @State private var unlocked = false
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 8

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Image(systemName: unlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .scaleEffect(iconScale).opacity(iconOpacity)
                .contentTransition(.symbolEffect(.replace.downUp.byLayer))
            if state == .unlocking {
                Text("Unlocked").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9)).opacity(textOpacity).offset(x: textOffset)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .onAppear { animate() }
    }

    private func animate() {
        if state == .locking { iconScale = 1.0; iconOpacity = 1.0; return }
        iconScale = 1.0; iconOpacity = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { unlocked = true; iconScale = 1.3 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { textOpacity = 1.0; textOffset = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) { iconScale = 1.0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.4)) { iconOpacity = 0; textOpacity = 0 }
        }
    }
}

// MARK: - AirPods / Bluetooth Audio (drops down)

struct AirPodsContent: View {
    @EnvironmentObject var vm: IslandViewModel
    let device: ConnectedAudioDevice
    @State private var phase = 0
    @State private var iconY: CGFloat = -15
    @State private var iconScale: CGFloat = 0.4
    @State private var titleOpacity: Double = 0
    @State private var batteryOpacity: Double = 0
    @State private var batteryOffset: CGFloat = 8

    private var icon: String {
        let name = device.name.lowercased()
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods") { return "airpods.gen3" }
        return "headphones"
    }

    private var batteryDevice: DeviceBattery? {
        vm.deviceBatteryMonitor.devices.first {
            $0.name.lowercased().contains(device.name.lowercased().components(separatedBy: " ").first ?? "airpods")
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(device.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .opacity(titleOpacity)

            Image(systemName: icon)
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.white)
                .scaleEffect(iconScale)
                .offset(y: iconY)

            HStack(spacing: 14) {
                if let dev = batteryDevice, dev.hasIndividualLevels {
                    if let l = dev.levelLeft {
                        batteryBadge(level: l)
                    }
                    if let r = dev.levelRight {
                        batteryBadge(level: r)
                    }
                } else if let dev = batteryDevice {
                    batteryBadge(level: dev.level)
                }
            }
            .opacity(batteryOpacity)
            .offset(y: batteryOffset)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
        .onAppear { runAnimation() }
    }

    private func batteryBadge(level: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: level > 20 ? "battery.75percent" : "battery.25percent")
                .font(.system(size: 11))
                .foregroundStyle(level > 20 ? .green : .red)
            Text("\(level)%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func runAnimation() {
        guard phase == 0 else { return }
        phase = 1
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.05)) {
            iconScale = 1.0
            iconY = 0
            titleOpacity = 1.0
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
            batteryOpacity = 1.0
            batteryOffset = 0
        }
    }
}

// MARK: - Notification (expands sideways)

struct NotificationContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        if let notif = vm.activeNotification {
            HStack(spacing: 8) {
                if let icon = notif.appIcon {
                    Image(nsImage: icon).resizable().frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(.leading, 10)
                } else {
                    Image(systemName: "bell.fill").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow).padding(.leading, 10)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(notif.appName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                    Text(notif.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !notif.subtitle.isEmpty {
                        Text(notif.subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button { vm.dismissNotification() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundStyle(.white.opacity(0.35))
                }.buttonStyle(.plain).padding(.trailing, 10)
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Call (drops down)

struct CallContent: View {
    @EnvironmentObject var vm: IslandViewModel
    @State private var pulseRing = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.green.opacity(pulseRing ? 0.0 : 0.25))
                    .frame(width: pulseRing ? 40 : 30, height: pulseRing ? 40 : 30)
                Image(systemName: "phone.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.green)
            }
            .frame(width: 40, height: 40)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulseRing = true }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.activeNotification?.title ?? "Incoming Call")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(vm.activeNotification?.subtitle ?? "FaceTime")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
            }

            Spacer()

            Button { vm.declineCall() } label: {
                Image(systemName: "phone.down.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Color.red))
            }.buttonStyle(.plain)

            Button { vm.acceptCall() } label: {
                Image(systemName: "phone.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Color.green))
            }.buttonStyle(.plain).padding(.trailing, 14)
        }
        .padding(.leading, 16)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }
}

// MARK: - Shared Components

struct ArtworkView: View {
    let image: NSImage?
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "music.note").font(.system(size: size * 0.3, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

struct WaveformBars: View {
    var isPlaying: Bool
    @State private var phase = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.15, paused: !isPlaying)) { timeline in
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let seed = timeline.date.timeIntervalSinceReferenceDate * [2.8, 3.5, 2.3, 3.1][i]
                    let h: CGFloat = isPlaying ? CGFloat(6 + 10 * abs(sin(seed + Double(i)))) : 4
                    Capsule().fill(Color.white.opacity(0.8))
                        .frame(width: 2.5, height: h)
                        .animation(.easeInOut(duration: 0.15), value: h)
                }
            }
        }
        .frame(width: 20, height: 20)
    }
}

struct ControlButton: View {
    let system: String
    var size: CGFloat = 13
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.7))
                .frame(width: max(28, size + 14), height: max(24, size + 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
