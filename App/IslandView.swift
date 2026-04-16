import SwiftUI

enum IslandState: Equatable {
    case idle, active, expanded, notification, call
}

struct IslandView: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    private var state: IslandState {
        if vm.activeNotification?.kind == .call { return .call }
        if vm.activeNotification != nil { return .notification }
        if hovering && settings.expandOnHover { return .expanded }
        if vm.isPlaying { return .active }
        return .idle
    }

    private var pillWidth: CGFloat {
        switch state {
        case .idle:          return 190
        case .active:        return 340
        case .expanded:      return 420
        case .notification:  return hovering ? 400 : 340
        case .call:          return hovering ? 420 : 360
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle:          return 34
        case .active:        return 38
        case .expanded:      return 150
        case .notification:  return hovering ? 90 : 50
        case .call:          return hovering ? 140 : 54
        }
    }

    private var topRadius: CGFloat {
        state == .idle ? pillHeight / 2 : 12
    }

    private var bottomRadius: CGFloat {
        pillHeight / 2
    }

    /// Semi-transparent when normal windows sit behind the Island
    private var pillOpacity: Double {
        if state == .call || state == .notification { return 1.0 }
        if hovering { return 1.0 }
        if vm.hasWindowsUnderneath { return 0.45 }
        return 1.0
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    ZStack {
                        UnevenRoundedRectangle(
                            topLeadingRadius: topRadius,
                            bottomLeadingRadius: bottomRadius,
                            bottomTrailingRadius: bottomRadius,
                            topTrailingRadius: topRadius
                        )
                        .fill(Color(white: 0.04))
                        .shadow(color: .black.opacity(state == .idle ? 0.2 : 0.45),
                                radius: state == .expanded || state == .call ? 28 : 10, y: 6)

                        Group {
                            switch state {
                            case .idle:
                                IdleContent()
                            case .active:
                                ActiveContent()
                            case .expanded:
                                ExpandedContent()
                            case .notification:
                                NotificationContent(isHovering: hovering)
                            case .call:
                                CallContent(isHovering: hovering)
                            }
                        }
                        .clipped()
                    }
                    .frame(width: pillWidth, height: pillHeight)
                    .opacity(pillOpacity)
                    .onHover { h in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                            hovering = h
                        }
                        vm.isHovering = h
                    }
                    Spacer()
                }
                Spacer()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: state)
        .animation(.easeInOut(duration: 0.3), value: vm.hasWindowsUnderneath)
    }
}

// MARK: - Idle

struct IdleContent: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green.opacity(0.5))
                .frame(width: 5, height: 5)
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 5, height: 5)
        }
    }
}

// MARK: - Active (music playing)

struct ActiveContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 24, height: 24)
            .padding(.leading, 8)

            Spacer()

            Text(vm.title.isEmpty ? "Island" : vm.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160)

            Spacer()

            WaveformBars(isPlaying: vm.isPlaying)
                .padding(.trailing, 10)
        }
    }
}

// MARK: - Waveform

struct WaveformBars: View {
    var isPlaying: Bool
    @State private var animating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Color.green)
                    .frame(width: 2.5,
                           height: animating ? [16, 12, 18, 10][i] : 4)
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

// MARK: - Expanded (hover on music)

struct ExpandedContent: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 16) {
            if settings.showArtwork {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 80, height: 80)
            }

            VStack(spacing: 8) {
                Text(vm.title.isEmpty ? "Nothing playing" : vm.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(vm.artist.isEmpty ? "Island" : vm.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                HStack(spacing: 22) {
                    ControlButton(system: "backward.fill") { vm.previous() }
                    ControlButton(system: vm.isPlaying ? "pause.fill" : "play.fill", size: 16) {
                        vm.playPause()
                    }
                    ControlButton(system: "forward.fill") { vm.next() }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }
}

// MARK: - Notification (general)

struct NotificationContent: View {
    @EnvironmentObject var vm: IslandViewModel
    var isHovering: Bool

    var body: some View {
        if let notif = vm.activeNotification {
            if isHovering {
                // Expanded notification
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notif.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if !notif.subtitle.isEmpty {
                                Text(notif.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Button { vm.dismissNotification() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.opacity)
            } else {
                // Compact notification
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .padding(.leading, 14)

                    Text(notif.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Text(timeAgo(notif.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.trailing, 14)
                }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 5 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        return "\(seconds / 60)m"
    }
}

// MARK: - Call

struct CallContent: View {
    @EnvironmentObject var vm: IslandViewModel
    var isHovering: Bool

    @State private var pulseRing = false

    var body: some View {
        if isHovering {
            expandedCall
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            compactCall
                .transition(.opacity)
        }
    }

    // Compact: icon + title + small accept/decline
    private var compactCall: some View {
        HStack(spacing: 0) {
            // Pulsing phone icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(pulseRing ? 0.0 : 0.3))
                    .frame(width: pulseRing ? 30 : 22, height: pulseRing ? 30 : 22)
                Image(systemName: "phone.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.green)
            }
            .frame(width: 36, height: 36)
            .padding(.leading, 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseRing = true
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.activeNotification?.title ?? "Incoming Call")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(vm.activeNotification?.subtitle ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            // Decline
            Button { vm.declineCall() } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.red))
            }
            .buttonStyle(.plain)

            // Accept
            Button { vm.acceptCall() } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.green))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .padding(.trailing, 10)
        }
    }

    // Expanded: larger layout with big buttons
    private var expandedCall: some View {
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
                // Decline
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

                // Accept
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
    }
}

// MARK: - Shared

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
