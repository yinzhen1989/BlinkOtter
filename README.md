# BlinkOtter 🦦

A small, native, open-source video player for macOS. Open a file with **⌘O**, drag it into the window, or open it with Finder. BlinkOtter uses [mpv](https://mpv.io/) for playback and macOS AppKit for the interface.

**This project is Vibe coded.** The initial Swift interface, packaging scripts, and documentation were developed in collaboration with Codex, then compiled and checked on a real Apple Silicon Mac. AI-generated work is reviewed against actual build and playback results; the label is about the process, not a performance claim.

## What works in 0.3.0

- Native macOS window with file open and drag-and-drop.
- Playback, pause, timeline seek, and full screen.
- VideoToolbox hardware decoding when mpv considers it safe and supported.
- Cinematic AppKit interface with an immersive video stage, editorial empty state, charcoal controls, and a red play accent.
- Original cute otter icon in editable SVG, matching the dark and red player palette.
- Multiple-file open and a previous/next video queue.
- Volume and mute, six playback speeds, 10-second skip buttons, and audio/subtitle track menus.
- Text subtitles sit above the overlaid playback controls.
- A self-contained Apple Silicon `.app` and drag-to-Applications `.dmg` built from source.

The 0.3.0 visual direction was inspired by a [cinematic fullscreen reference](https://www.pinterest.com/pin/1337074874706698/): dark negative space, restrained white typography, and a fine red playback accent. The otter artwork and AppKit layout are original to BlinkOtter; no film frame from the reference is bundled.

BlinkOtter does **not** yet include Japanese/English-to-Chinese live subtitles. Subtitle translation and speech recognition are planned as background tasks so that they never delay the first frame. The current release also has no measured claim of “90% of formats” or “instant opening” for every large file; those require a public sample set and benchmarks across codecs, storage types, and Mac models. DRM media is outside the target.

## Build

Requirements: Apple Silicon Mac, macOS 13 or newer, Xcode command-line tools, Homebrew, Python 3, and mpv.

```bash
brew install mpv
bash Scripts/build.sh
```

The build produces `build/BlinkOtter.app` and `build/BlinkOtter-0.3.0-arm64.dmg`. The script copies mpv and its linked Homebrew libraries into the app bundle, rewrites library references, ad-hoc signs the bundle, and creates the disk image. No Homebrew installation is needed to play with the bundled app. The disk image contains an Applications shortcut for installation.

The 0.3.0 DMG is **ad-hoc signed and not notarized**. For a smooth public download, a maintainer must add an Apple Developer ID certificate, hardened runtime, and notarization. Apple explains the [distribution and notarization requirements](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

Open one or several files with **⌘O**. The previous/next buttons follow the order selected in the file panel. **Space** pauses or plays; **J/L** skip back/forward 10 seconds; **M** mutes; **F** enters full screen. The CC and waveform menus choose subtitle and audio tracks when the file provides them. A same-name `.srt` file beside a video is picked up by mpv. The cinematic otter icon lives in editable vector form at `Resources/BlinkOtter.svg`; `bash Scripts/make_icon.sh` regenerates its PNG and ICNS files if `rsvg-convert` is installed.

## Open source and third parties

The BlinkOtter source code is licensed under **GPL-3.0-or-later**; see [LICENSE](LICENSE). Playback comes from mpv, FFmpeg, and their codec/library dependencies. The bundled DMG includes dependency license files that Homebrew packages at the formula root and a list of bundled formulae under `BlinkOtter.app/Contents/Resources/ThirdParty/`. The actual mpv build and FFmpeg build on the packager's machine determine which GPL/LGPL terms apply. This project does not claim ownership of any third-party playback code.

Upstream projects: [mpv](https://github.com/mpv-player/mpv), [FFmpeg](https://ffmpeg.org/), [Homebrew](https://brew.sh/). mpv recommends libmpv for embedding; its license can differ with build flags and linked libraries. FFmpeg's license also depends on its build options.

## Roadmap

1. Benchmark startup-to-window, file-to-first-frame, and seek-to-resume with representative MP4, MKV, MOV, AVI, WebM, TS, subtitle, and large-file samples.
2. Translate existing English or Japanese text subtitles to simplified Chinese, asynchronously and with a local cache.
3. For files without text subtitles, transcribe the selected audio track with a multilingual whisper.cpp model and translate the transcript to Chinese. Make both engines optional and lazy-loaded.
4. Add track/subtitle selection, subtitle styling, signed and notarized releases, and Intel/universal builds.

Contributions and reproducible playback samples are welcome. Please do not add copyrighted media files to the repository.
