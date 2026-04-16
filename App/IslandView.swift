import SwiftUI

enum IslandState: Equatable {
    case idle, active, expanded, hud, notification, call
}

// MARK: - Main View

struct IslandView: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    private var state: IslandState {
        if vm.activeHUD != nil { return .hud }
        if vm.activeNotification?.kind == .call { return .call }
        if vm.activeNotification != nil { return .notification }
        if hovering { return .expanded }
        if vm.isPlaying || vm.timerManager.isRunning { return .active }
        return .idle
    }

    private var pillWidth: CGFloat {
        switch state {
        case .idle:         return 190
        case .active:       return 340
        case .expanded:     return 440
        case .hud:          return 280
        case .notification: return 340
        case .call:         return 360
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle:         return 10
        case .active:       return 48
        case .expanded:     return 240
        case .hud:          return 48
        case .notification: return 52
        case .call:         return 140
        }
    }

    private var topRadius: CGFloat {
        state == .idle ? pillHeight / 2 : 10
    }

    private var bottomRadius: CGFloat {
        state == .idle ? pillHeight / 2 : 22
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Color.clear
                        .frame(width: 200, height: 34)

                    ZStack {
                        islandBackground
                        Group {
                            switch state {
                            case .idle:         IdleContent()
                            case .active:       ActiveContent()
                            case .expanded:     ExpandedContent()
                            case .hud:          if let hud = vm.activeHUD { HUDContent(kind: hud) }
                            case .notification: NotificationContent()
                            case .call:         CallContent()
                            }
                        }
                        .clipped()
                    }
                    .frame(width: pillWidth, height: pillHeight)
                }
                .frame(width: max(pillWidth, 200), height: max(pillHeight, 34))
                .contentShape(Rectangle())
                .onHover { h in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.74)) {
                        hovering = h
                    }
                    vm.isHovering = h
                }

                Spacer()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.74), value: state)
    }

    @ViewBuilder
    private var islandBackground: some View {
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: topRadius,
            bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius,
            topTrailingRadius: topRadius
        )
        if settings.glassEffect {
            shape.fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(state == .idle ? 0 : 0.5),
                        radius: state == .expanded || state == .call ? 28 : 12, y: 8)
        } else {
            shape.fill(Color(white: 0.04))
                .shadow(color: .black.opacity(state == .idle ? 0 : 0.5),
                        radius: state == .expanded || state == .call ? 28 : 12, y: 8)
        }
    }
}

// MARK: - Idle

struct IdleContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(vm.isPlaying ? Color.green.opacity(0.7) : Color.white.opacity(0.2))
                .frame(width: 4, height: 4)

            if vm.timerManager.isRunning {
                Circle()
                    .fill(Color.orange.opacity(0.7))
                    .frame(width: 4, height: 4)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Active (compact)

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
        HStack(spacing: 0) {
            ArtworkView(image: vm.nowPlaying.artwork, size: 32)
                .padding(.leading, 10)

            Spacer()

            VStack(spacing: 2) {
                Text(vm.nowPlaying.title.isEmpty ? "Island" : vm.nowPlaying.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 160)

                if !vm.nowPlaying.artist.isEmpty {
                    Text(vm.nowPlaying.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                        .frame(maxWidth: 160)
                }
            }

            Spacer()

            WaveformBars(isPlaying: vm.isPlaying)
                .padding(.trailing, 12)
        }
    }

    private var timerCompact: some View {
        HStack(spacing: 0) {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.leading, 14)

            Spacer()

            Text(vm.timerManager.timeString)
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: 1 - vm.timerManager.progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            .padding(.trailing, 14)
        }
    }
}

// MARK: - Expanded (hover)

struct ExpandedContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        VStack(spacing: 0) {
            ActivityTabBar(activeTab: $vm.activeTab, hasTimer: vm.timerManager.totalSeconds > 0)

            Divider().opacity(0.15).padding(.horizontal, 16)

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
    @Binding var activeTab: ActivityTab
    let hasTimer: Bool

    var body: some View {
        HStack(spacing: 16) {
            tabIcon("music.note", tab: .nowPlaying)
            tabIcon("calendar", tab: .calendar)
            tabIcon("battery.100percent", tab: .battery)
            if hasTimer {
                tabIcon("timer", tab: .timer)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func tabIcon(_ system: String, tab: ActivityTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                activeTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: system)
                    .font(.system(size: 10, weight: activeTab == tab ? .bold : .regular))
                    .foregroundStyle(activeTab == tab ? .white : .white.opacity(0.3))
                    .frame(width: 24, height: 16)
                Circle()
                    .fill(activeTab == tab ? Color.white : Color.clear)
                    .frame(width: 3, height: 3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Now Playing (Expanded)

struct NowPlayingExpanded: View {
    @EnvironmentObject var vm: IslandViewModel

    private var progress: Double {
        guard vm.nowPlaying.duration > 0 else { return 0 }
        return min(vm.currentElapsed / vm.nowPlaying.duration, 1.0)
    }

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(image: vm.nowPlaying.artwork, size: 90)

            VStack(alignment: .leading, spacing: 6) {
                Text(vm.nowPlaying.title.isEmpty ? "Nothing Playing" : vm.nowPlaying.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(vm.nowPlaying.artist.isEmpty ? "Island" : vm.nowPlaying.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(Color.white.opacity(0.8))
                                .frame(width: max(0, geo.size.width * progress))
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text(formatTime(vm.currentElapsed))
                        Spacer()
                        Text(formatTime(vm.nowPlaying.duration))
                    }
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                }

                HStack(spacing: 20) {
                    Spacer()
                    ControlButton(system: "backward.fill") { vm.previous() }
                    ControlButton(system: vm.isPlaying ? "pause.fill" : "play.fill", size: 16) {
                        vm.playPause()
                    }
                    ControlButton(system: "forward.fill") { vm.next() }
                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
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

    private var batteryColor: Color {
        if battery.isCharging { return .green }
        if battery.level <= 20 { return .red }
        if battery.level <= 50 { return .yellow }
        return .green
    }

    var body: some View {
        if !battery.hasBattery {
            VStack(spacing: 8) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.3))
                Text("No battery")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: Double(battery.level) / 100.0)
                        .stroke(batteryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        if battery.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        }
                        Text("\(battery.level)%")
                            .font(.system(size: 18, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 6) {
                    Text(battery.isCharging ? "Charging" : (battery.isPluggedIn ? "Plugged In" : "On Battery"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    if let mins = battery.minutesRemaining, mins > 0 {
                        Text(battery.isCharging
                             ? "\(mins / 60)h \(mins % 60)m until full"
                             : "\(mins / 60)h \(mins % 60)m remaining")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Timer (Expanded)

struct TimerExpanded: View {
    @EnvironmentObject var vm: IslandViewModel
    @State private var selectedMinutes: Double = 5

    private var timer: TimerManager { vm.timerManager }

    var body: some View {
        VStack(spacing: 12) {
            if timer.totalSeconds > 0 {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: 1 - timer.progress)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(timer.timeString)
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: 80, height: 80)

                HStack(spacing: 20) {
                    Button { timer.toggle() } label: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Button { timer.reset() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("\(Int(selectedMinutes)) min")
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)

                Slider(value: $selectedMinutes, in: 1...60, step: 1)
                    .tint(.orange)
                    .frame(width: 200)

                Button { timer.start(minutes: Int(selectedMinutes)) } label: {
                    Text("Start")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.orange))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - HUD (Volume / Brightness)

struct HUDContent: View {
    let kind: HUDKind

    var body: some View {
        HStack(spacing: 10) {
            icon
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 20)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(barColor)
                        .frame(width: max(0, geo.size.width * CGFloat(level)))
                }
            }
            .frame(height: 4)

            Text("\(Int(level * 100))")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 18)
    }

    private var level: Float {
        switch kind {
        case .volume(let v): return v
        case .brightness(let b): return b
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .volume(let v):
            Image(systemName: volumeIcon(v))
                .foregroundStyle(.white)
        case .brightness(let b):
            Image(systemName: b > 0.5 ? "sun.max.fill" : "sun.min.fill")
                .foregroundStyle(.yellow)
        }
    }

    private var barColor: Color {
        switch kind {
        case .volume:     return .white
        case .brightness: return .yellow
        }
    }

    private func volumeIcon(_ v: Float) -> String {
        if v <= 0 { return "speaker.slash.fill" }
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Notification

struct NotificationContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        if let notif = vm.activeNotification {
            HStack(spacing: 10) {
                if let icon = notif.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .padding(.leading, 14)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(.leading, 14)
                }

                Text(notif.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button { vm.dismissNotification() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
        }
    }
}

// MARK: - Call

struct CallContent: View {
    @EnvironmentObject var vm: IslandViewModel
    @State private var pulseRing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(pulseRing ? 0.0 : 0.25))
                        .frame(width: pulseRing ? 50 : 38, height: pulseRing ? 50 : 38)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(width: 50, height: 50)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulseRing = true
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.activeNotification?.title ?? "Incoming Call")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(vm.activeNotification?.subtitle ?? "FaceTime")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            HStack(spacing: 40) {
                Button { vm.declineCall() } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.red))
                        Text("Decline")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)

                Button { vm.acceptCall() } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.green))
                        Text("Accept")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
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
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

struct WaveformBars: View {
    var isPlaying: Bool
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Color.green)
                    .frame(width: 2.5, height: animating ? [16, 12, 18, 10][i] : 4)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: [0.42, 0.55, 0.38, 0.5][i])
                              .repeatForever(autoreverses: true)
                              .delay(Double(i) * 0.08)
                            : .easeOut(duration: 0.3),
                        value: animating
                    )
            }
        }
        .frame(width: 20, height: 20)
        .onAppear { animating = isPlaying }
        .onChange(of: isPlaying) { _, playing in animating = playing }
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
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
