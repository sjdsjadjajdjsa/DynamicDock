<div align="center">

<img src="docs/icon.png" width="128" alt="Dynamic Dock icon">

# Dynamic Dock

**A floating music dock for macOS.**
Touch the bottom edge of your screen and your music slides up.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

[**Download the latest release**](https://github.com/sjdsjadjajdjsa/DynamicDock/releases/latest)

<img src="docs/dock.png" width="720" alt="The Dynamic Dock pill showing a track, a visualizer and playback controls">

<sub>Design render.</sub>

<img src="docs/screenshot.png" width="450" alt="Screenshot of Dynamic Dock on a desktop, with the Liquid Glass surface">

<sub>Screenshot on a real desktop, with Liquid Glass (macOS 26 and later).</sub>

</div>

## Features

- **Hidden until you want it.** The dock lives off screen and springs up when
  your cursor rests on the screen edge, like the macOS Dock.
- **Big now-playing view.** Click the album artwork to open a large glass
  card with the cover on one side and an audio visualizer that follows the
  music on the other.
- **Synced lyrics.** When a song has them, the lyrics appear under the
  visualizer and follow along line by line.
- **Five visualizer styles.** Click the visualizer to switch between bars,
  wave, mirror, dots and ring.
- **Bottom, left or right.** Put it on any of the three edges, anywhere
  along that edge. On the sides it becomes a vertical pill.
- **Now playing at a glance.** Track title, artist and album artwork from
  Spotify or Apple Music, updated the moment the song changes.
- **Playback controls.** Play, pause, skip and go back without switching apps.
- **Animated visualizer.** Five bars that move while music plays and settle
  into dots when it pauses.
- **Native look.** Liquid Glass, continuous corners, spring animations and
  scrolling text for long titles.
- **One-click updates.** Settings shows when a new version is out and
  installs it with one button.
- **Stays out of the way.** No Dock icon, never steals keyboard focus, works
  over full-screen apps and on every Space, and uses no CPU while hidden.

## Install

Requires macOS 14 or later. The Liquid Glass look needs macOS 26 or later;
earlier versions use standard vibrancy.

1. Download `DynamicDock.zip` from the
   [latest release](https://github.com/sjdsjadjajdjsa/DynamicDock/releases/latest),
   unzip it and move `DynamicDock.app` to your Applications folder.
2. The app is not notarized by Apple, so macOS blocks it the first time.
   Remove the download quarantine flag in Terminal:

   ```sh
   xattr -dr com.apple.quarantine /Applications/DynamicDock.app
   ```

   Alternatively, try to open the app once, then go to System Settings →
   Privacy & Security and click **Open Anyway**.
3. Open the app. A music-note icon appears in the menu bar.
4. When Spotify or Music is running, macOS asks whether Dynamic Dock may
   control it. Click **Allow**. Without it the dock still shows the track
   name, but artwork and the buttons do not work.

If you clicked Don't Allow, turn it on under System Settings → Privacy &
Security → Automation → Dynamic Dock.

The first time you open the big now-playing view, macOS asks whether Dynamic
Dock may record system audio. That is what lets the visualizer follow the
music (macOS 14.2 or later). If you decline, the bars still move, but with
simulated motion.

## Usage

| To | Do this |
|---|---|
| Show the dock | Rest the cursor on the screen edge where the dock lives (bottom centre by default) |
| Hide the dock | Move the cursor away |
| Open the big now-playing view | Click the album artwork on the dock |
| Change the visualizer style | Click the visualizer in the big view |
| Close it | Press Esc, click the X, or click outside the card (Space plays and pauses) |
| Change settings | Click the music-note icon in the menu bar → Settings |
| Quit | Click the music-note icon in the menu bar → Quit |

Settings let you open the app at login, choose the screen edge (bottom, left
or right), slide the dock along that edge, set its distance from the edge,
reveal it from the entire edge, and tune how quickly it appears and hides.
The dock shows itself in its new place while you adjust its position.

If your macOS Dock is on the same edge with auto-hide on, both appear
together. Putting them on different edges avoids that.

## Build from source

Needs the Xcode Command Line Tools (`xcode-select --install`). Xcode itself is
not required.

```sh
git clone https://github.com/sjdsjadjajdjsa/DynamicDock.git
cd DynamicDock

Scripts/build-app.sh          # builds build/DynamicDock.app for this Mac
open build/DynamicDock.app

Scripts/package.sh            # universal build, zipped as build/DynamicDock.zip
```

The build is ad-hoc signed, so macOS asks for the Spotify/Music permission
again after each rebuild. To avoid that, sign with a certificate:
`SIGN_IDENTITY="Your Certificate Name" Scripts/build-app.sh`.

## How it works

| Part | Approach |
|---|---|
| Window | A borderless, non-activating `NSPanel` at status-bar level that joins every Space |
| Edge trigger | Global and local `NSEvent` mouse monitors; no Accessibility permission needed |
| Track info | Distributed notifications posted by Spotify and Music, so nothing is polled |
| Controls and artwork | Apple Events, sent only to players that are already running |
| Dock visualizer | Core Animation layers animated by the system render server |
| Now-playing visualizer | A Core Audio system tap analysed with an FFT, running only while the view is open |
| Interface | SwiftUI hosted in AppKit |

The source is organised as `App`, `Windowing`, `Media`, `UI` and `Settings`
under `Sources/DynamicDock`.

## Privacy

The app makes three kinds of network request:

- downloading album artwork from Spotify's image server;
- asking GitHub for the latest release when you open Settings, and
  downloading it if you click Update Now;
- looking up lyrics on [LRCLIB](https://lrclib.net) while the big now-playing
  view is open, which sends the song's title, artist, album and length.

It collects nothing.

While the big now-playing view is open, the app listens to the audio your Mac
is playing to draw the visualizer. The sound is turned into bar heights in
memory and is never recorded, saved or sent anywhere. It stops listening when
the view closes.

## License

[MIT](LICENSE)
