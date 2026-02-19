# Whisper

A macOS menu-bar app for local speech-to-text transcription using [whisper.cpp](https://github.com/ggerganov/whisper.cpp). All processing happens on-device — no cloud services, no API keys, no data leaves your machine.

## Features

- **Global hotkeys** — `⌥Space` to toggle recording, `⌥Enter` to commit transcription
- **Live partial transcription** — see text appear as you speak, updated every ~500ms
- **Local inference** — runs whisper.cpp with Metal GPU acceleration on Apple Silicon
- **Auto-language detection** — supports all languages whisper.cpp supports, or can be forced to a specific language
- **Auto-paste** — optionally paste transcribed text directly into the frontmost app
- **Floating overlay** — draggable, always-on-top panel that remembers its position
- **Energy-based VAD** — adaptive voice activity detection with configurable sensitivity
- **Menu-bar only** — no Dock icon, lives entirely in the macOS menu bar

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- CMake (`brew install cmake` or via [asdf](https://asdf-vm.com/))
- A whisper.cpp GGML model file (see [Downloading a Model](#downloading-a-model))

## Building

### 1. Clone and initialize submodules

```sh
git clone <repo-url> whisper-app
cd whisper-app
git submodule update --init --recursive
```

### 2. Build whisper.cpp static libraries

```sh
scripts/build-whisper.sh
```

This compiles whisper.cpp with Metal and Accelerate support, producing static libraries in `vendor/lib/`. Pass `--force` to rebuild from scratch.

### 3. Build and bundle the app

```sh
scripts/bundle.sh
```

This runs `swift build -c release`, then assembles `Whisper.app` with the binary, Info.plist, app icon, and Metal shader library.

### 4. Run

```sh
open Whisper.app
```

On first launch, macOS will ask for **Microphone** permission. If you enable auto-paste, you'll also need to grant **Accessibility** permission (System Settings > Privacy & Security > Accessibility).

## Downloading a Model

Whisper requires a GGML-format model file. Models are stored in `~/Library/Application Support/Whisper/Models/`.

You can download models using the script bundled with whisper.cpp:

```sh
# Example: download the base English model (~142 MB)
vendor/whisper.cpp/models/download-ggml-model.sh base.en

# Example: download large-v3-turbo (~1.6 GB, best quality/speed balance)
vendor/whisper.cpp/models/download-ggml-model.sh large-v3-turbo
```

Then move the downloaded `.bin` file into the models directory:

```sh
mkdir -p ~/Library/Application\ Support/Whisper/Models/
mv vendor/whisper.cpp/models/ggml-*.bin ~/Library/Application\ Support/Whisper/Models/
```

Select the model in the app's Settings > Models tab.

### Recommended Models

| Model | Size | Speed | Quality | Notes |
|---|---|---|---|---|
| `base.en` | ~142 MB | Fast | Good | English only |
| `small` | ~466 MB | Moderate | Better | Multilingual |
| `large-v3-turbo` | ~1.6 GB | Moderate | Best | Multilingual, best quality/speed balance |

## Usage

| Action | Shortcut |
|---|---|
| Toggle recording | `⌥Space` |
| Commit transcription | `⌥Enter` |

1. Press `⌥Space` to start recording — a floating overlay appears
2. Speak — partial transcription appears in real-time
3. Pause — the partial text is finalized with higher quality (beam search)
4. Continue speaking — new text is appended
5. Press `⌥Enter` to commit — text is copied to the clipboard (and optionally pasted into the active app)

The overlay can be dragged to any position and it will remember its location between sessions.

## Settings

Access settings from the menu bar icon dropdown. Three tabs are available:

### General
- **Language** — `auto` for detection, or force a specific language (en, es, fr, de, etc.)
- **CPU Threads** — number of threads for inference (default: 4)
- **Mic Gain** — input amplification from 1x to 5x (default: 2x), useful for quiet microphones
- **VAD Sensitivity** — voice activity detection sensitivity from 0.0 to 1.0 (default: 0.7)
- **Partial Update Interval** — how often partial transcription refreshes in seconds (default: 0.5)
- **Auto-Paste** — automatically paste text into the frontmost app on commit (requires Accessibility permission)
- **Hide on Commit** — dismiss the overlay when transcription is committed (default: on)

### Models
- View, select, import, and delete whisper model files
- Models are stored in `~/Library/Application Support/Whisper/Models/`

### Shortcuts
- Customize the toggle recording and commit hotkeys

## Architecture

```
Sources/
├── CWhisper/              # C bridging module for whisper.cpp
│   └── include/           # Module map + symlinked whisper headers
├── Whisper/
│   ├── App/               # AppDelegate, AppState, Settings, SettingsView
│   ├── Audio/             # AudioEngineManager, EnergyVAD, RingBuffer, UtteranceBuffer
│   ├── Commit/            # CommitController, ClipboardManager, PasteInjector
│   ├── Hotkeys/           # HotkeyManager (global keyboard shortcuts)
│   ├── Overlay/           # OverlayPanelController, OverlayView (SwiftUI)
│   └── Transcription/     # WhisperContext, TranscriptionWorker, ModelManager
scripts/
├── build-whisper.sh       # CMake build for whisper.cpp static libs
└── bundle.sh              # Build + create Whisper.app bundle
vendor/
└── whisper.cpp/           # Git submodule (v1.8.3)
```

### Threading Model

- **Main thread** — UI, state mutations, commit flow
- **Audio thread** — AVAudioEngine tap, sample conversion, ring buffer writes
- **VAD queue** — serial queue for energy-based voice activity detection
- **Inference queue** — serial queue for all whisper.cpp calls (the C context is not thread-safe)
- **Background** — model loading on app launch

### Audio Pipeline

```
Microphone → AVAudioEngine (48kHz) → Resample to 16kHz mono Float32
  → Apply gain → Ring buffer (circular, ~30s)
  → EnergyVAD (adaptive noise floor, debounced)
  → Speech start: prepend ~300ms lookback from ring buffer
  → During speech: accumulate in utterance buffer
  → Speech end: add ~500ms tail padding, trigger final inference
```

### Transcription Pipeline

- **Partial inference** — greedy decoding, single segment, fires every ~500ms during speech for live preview
- **Final inference** — beam search (beam size 5), runs on speech pause for higher accuracy
- Results are displayed in the floating overlay: finalized text in primary style, live partials in italic

## Dependencies

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) v1.8.3 — C/C++ inference engine (git submodule)
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 1.15.0 — global hotkey handling (SwiftPM)
- Apple frameworks: AppKit, AVFoundation, Metal, Accelerate

## License

This project uses whisper.cpp which is licensed under the MIT License. Model files are subject to OpenAI's whisper model license.
