# Island

**Dynamic Island for macOS.** A floating pill at the top of your screen that
shows now‑playing music and expands on hover with playback controls.

```
        ╭─────────────────────────────────────────╮
        │  ♪  Blinding Lights — The Weeknd    •  │
        ╰─────────────────────────────────────────╯

                        hover ↓

        ╭─────────────────────────────────────────────╮
        │  ┌────┐   Blinding Lights                   │
        │  │ ♪  │   The Weeknd                        │
        │  └────┘   ⏮   ⏸   ⏭                         │
        ╰─────────────────────────────────────────────╯
```

## Features

- **Floating pill** at the top‑center of your main display, above all apps.
- **Now‑playing** from Apple Music and Spotify (auto‑detected).
- **Hover to expand** into full media controls — play / pause / skip.
- **Menu bar icon** to toggle visibility or quit.
- **Lightweight.** Native SwiftUI, no Electron, no background video.
- **No login, no telemetry, no noise.** Just the island.

## Install

Download the latest DMG from the
[releases page](https://github.com/elvinmonke/island/releases/latest), open it, and drag
**Island.app** into your Applications folder.

On first launch macOS will ask permission for **Apple Events** — this is how
Island reads the current track from Music / Spotify.

> The app is self‑signed. If Gatekeeper blocks it, right‑click → **Open**, or
> run `xattr -dr com.apple.quarantine /Applications/Island.app`.

## Build from source

Requires macOS 14+, Xcode 15+, and [XcodeGen](https://github.com/yonki/xcodegen).

```bash
brew install xcodegen
git clone https://github.com/elvinmonke/island.git
cd island
./build.sh                  # produces build/Release/Island.app
./scripts/make_dmg.sh       # produces build/Island-1.0.0.dmg
```

## Architecture

```
 ┌────────────────────┐     AppleScript      ┌──────────────┐
 │   IslandViewModel  │ ───────────────────► │  Music /     │
 │   (polls 3s)       │ ◄─────────────────── │  Spotify     │
 └─────────┬──────────┘                      └──────────────┘
           │ @Published
           ▼
 ┌────────────────────┐
 │   IslandView       │      SwiftUI
 │   (collapsed ↔     │ ───────────────►  NSPanel (.screenSaver level,
 │    expanded)       │                    all spaces, borderless)
 └────────────────────┘
```

- `IslandApp.swift` — entry point + menu bar item.
- `IslandWindowController.swift` — borderless `NSPanel` pinned top‑center.
- `IslandView.swift` — SwiftUI pill with spring‑animated expand/collapse.
- `IslandViewModel.swift` + `NowPlaying` — AppleScript bridge to media apps.

## License

MIT — do whatever you want. See [LICENSE](LICENSE).
