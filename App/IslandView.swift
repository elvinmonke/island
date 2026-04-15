import SwiftUI

struct IslandView: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    var body: some View {
        GeometryReader { geo in
            let expanded = (settings.expandOnHover && hovering) || vm.forceExpanded
            let width: CGFloat = expanded ? 460 : (vm.hasContent ? 240 : 200)
            let height: CGFloat = expanded ? 120 : 34

            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    Spacer()
                    IslandPill(expanded: expanded)
                        .frame(width: width, height: height)
                        .onHover { h in
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                hovering = h
                            }
                        }
                    Spacer()
                }
                .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

struct IslandPill: View {
    @EnvironmentObject var vm: IslandViewModel
    var expanded: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: expanded ? 28 : 17, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.35), radius: expanded ? 22 : 8, y: 6)

            if expanded {
                ExpandedContent()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            } else {
                CollapsedContent()
                    .transition(.opacity)
                    .padding(.horizontal, 14)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: expanded)
    }
}

struct CollapsedContent: View {
    @EnvironmentObject var vm: IslandViewModel
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.isPlaying ? "waveform" : "music.note")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.green)
                .symbolEffect(.variableColor.iterative, isActive: vm.isPlaying)
            if vm.hasContent {
                Text(vm.title.isEmpty ? "Island" : vm.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 6, height: 6)
        }
    }
}

struct ExpandedContent: View {
    @EnvironmentObject var vm: IslandViewModel
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        HStack(spacing: 14) {
            if settings.showArtwork {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.title.isEmpty ? "Nothing playing" : vm.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(vm.artist.isEmpty ? "Island · Dynamic Island for Mac" : vm.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                HStack(spacing: 14) {
                    ControlButton(system: "backward.fill") { vm.previous() }
                    ControlButton(system: vm.isPlaying ? "pause.fill" : "play.fill") { vm.playPause() }
                    ControlButton(system: "forward.fill") { vm.next() }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
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
                .foregroundStyle(.white.opacity(hovering ? 1 : 0.85))
                .frame(width: 26, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
