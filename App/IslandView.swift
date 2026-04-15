import SwiftUI

enum IslandState {
    case idle
    case active
    case expanded
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
        case .expanded: return 460
        }
    }

    private var pillHeight: CGFloat {
        switch state {
        case .idle: return 34
        case .active: return 38
        case .expanded: return 140
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    ZStack(alignment: .top) {
                        // Pill shape — top corners are tight, bottom corners round
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: pillHeight / 2,
                            bottomTrailingRadius: pillHeight / 2,
                            topTrailingRadius: 12
                        )
                        .fill(Color(white: 0.04))
                        .shadow(color: .black.opacity(state == .idle ? 0.2 : 0.4),
                                radius: state == .expanded ? 24 : 10, y: 6)

                        // Content
                        switch state {
                        case .idle:
                            IdleContent()
                        case .active:
                            ActiveContent()
                        case .expanded:
                            ExpandedContent()
                        }
                    }
                    .frame(width: pillWidth, height: pillHeight)
                    .onHover { h in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                            hovering = h
                        }
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

// MARK: - Idle: tiny rounded pill blending with notch

struct IdleContent: View {
    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            Circle()
                .fill(Color.green.opacity(0.5))
                .frame(width: 5, height: 5)
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 5, height: 5)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Active: extends showing album + waveform (not hovered)

struct ActiveContent: View {
    @EnvironmentObject var vm: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left side — album art
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

            // Center — song title
            Text(vm.title.isEmpty ? "Island" : vm.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140)

            Spacer()

            // Right side — waveform bars
            WaveformBars(isPlaying: vm.isPlaying)
                .padding(.trailing, 10)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Waveform animation

struct WaveformBars: View {
    var isPlaying: Bool
    @State private var animating = false

    private let barCount = 4
    private let barWidth: CGFloat = 2.5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(Color.green)
                    .frame(width: barWidth,
                           height: animating ? heights[i].active : heights[i].idle)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: speeds[i])
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

    private var heights: [(idle: CGFloat, active: CGFloat)] {
        [(4, 16), (4, 12), (4, 18), (4, 10)]
    }

    private var speeds: [Double] {
        [0.42, 0.55, 0.38, 0.5]
    }
}

// MARK: - Expanded: full controls on hover

struct ExpandedContent: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // Top row — compact info
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 5, height: 5)
                Text(vm.title.isEmpty ? "Nothing playing" : vm.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                Spacer()
                Text(vm.artist)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)

            Spacer(minLength: 4)

            // Bottom row — artwork + controls
            HStack(spacing: 14) {
                if settings.showArtwork {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "music.note")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 54, height: 54)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.title.isEmpty ? "Nothing playing" : vm.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(vm.artist.isEmpty ? "Island" : vm.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    ControlButton(system: "backward.fill") { vm.previous() }
                    ControlButton(system: vm.isPlaying ? "pause.fill" : "play.fill") {
                        vm.playPause()
                    }
                    ControlButton(system: "forward.fill") { vm.next() }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }
}

struct ControlButton: View {
    let system: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

extension IslandState: Equatable {}
