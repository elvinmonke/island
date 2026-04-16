import SwiftUI

enum IslandState: Equatable {
    case idle, active, expanded
}

struct IslandView: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    private var state: IslandState {
        if hovering && settings.expandOnHover { return .expanded }
        if vm.isPlaying { return .active }
        return .idle
    }

    private var pillWidth: CGFloat {
        switch state {
        case .idle: return 190
        case .active: return 340
        case .expanded: return 420
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle: return 34
        case .active: return 38
        case .expanded: return 150
        }
    }

    // Idle = fully rounded capsule (top half clips behind bezel → notch looks like a pill)
    // Active/Expanded = tight top corners flush with notch, round bottom as it drops down
    private var topRadius: CGFloat {
        state == .idle ? pillHeight / 2 : 12
    }

    private var bottomRadius: CGFloat {
        pillHeight / 2
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
                                radius: state == .expanded ? 28 : 10, y: 6)

                        Group {
                            switch state {
                            case .idle:
                                IdleContent()
                            case .active:
                                ActiveContent()
                            case .expanded:
                                ExpandedContent()
                            }
                        }
                        .clipped()
                    }
                    .frame(width: pillWidth, height: pillHeight)
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
    }
}

// MARK: - Idle: capsule morphing the notch

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

// MARK: - Active: extends with album + waveform

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

// MARK: - Expanded: drops down with centered content

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
