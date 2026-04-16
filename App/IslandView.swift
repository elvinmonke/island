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
        if hovering { return .expanded }
        if vm.isPlaying { return .active }
        return .idle
    }

    private var pillWidth: CGFloat {
        switch state {
        case .idle:          return 190
        case .active:        return 340
        case .expanded:      return 420
        case .notification:  return 340
        case .call:          return 360
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle:          return 10
        case .active:        return 48
        case .expanded:      return 160
        case .notification:  return 52
        case .call:          return 140
        }
    }

    // Idle = fully rounded capsule that blends into the notch bottom edge
    // Active+ = tight top corners flush with notch, rounded bottom as it drops down
    private var topRadius: CGFloat {
        state == .idle ? pillHeight / 2 : 10
    }

    private var bottomRadius: CGFloat {
        switch state {
        case .idle: return pillHeight / 2
        default: return 22
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // Invisible hover zone covering the notch area so the user
                    // can trigger expansion by mousing over where the notch is
                    Color.clear
                        .frame(width: 200, height: 34)

                    // The actual pill — drops down from notch
                    ZStack {
                        UnevenRoundedRectangle(
                            topLeadingRadius: topRadius,
                            bottomLeadingRadius: bottomRadius,
                            bottomTrailingRadius: bottomRadius,
                            topTrailingRadius: topRadius
                        )
                        .fill(Color(white: 0.04))
                        .shadow(color: .black.opacity(state == .idle ? 0 : 0.5),
                                radius: state == .expanded || state == .call ? 28 : 12, y: 8)

                        Group {
                            switch state {
                            case .idle:
                                IdleContent()
                            case .active:
                                ActiveContent()
                            case .expanded:
                                ExpandedContent()
                            case .notification:
                                NotificationContent()
                            case .call:
                                CallContent()
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
}

// MARK: - Idle: thin sliver fused into the notch

struct IdleContent: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 4, height: 4)
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Active: pops out with album cover left, waveform right

struct ActiveContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Album cover (left)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Image(systemName: "music.note")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .padding(.leading, 10)

            Spacer()

            // Song title (center)
            Text(vm.title.isEmpty ? "Island" : vm.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160)

            Spacer()

            // Waveform bars (right)
            WaveformBars(isPlaying: vm.isPlaying)
                .padding(.trailing, 12)
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

// MARK: - Expanded: full music controls (drops down on hover)

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

// MARK: - Notification

struct NotificationContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        if let notif = vm.activeNotification {
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
