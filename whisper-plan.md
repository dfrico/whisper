# macOS Menu-Bar Dictation App (Local whisper.cpp) — Implementation Plan

## Goal

Build a macOS app that runs in the background (menu bar only) and, when the user presses a global hotkey (default **⌥ Space**), starts capturing microphone audio and shows a lightweight **overlay/mini window** with a **live transcript** that updates while the user speaks. Pressing a “commit” hotkey copies the transcript to the clipboard and **optionally** pastes it into the previously focused app.

This plan assumes:

- Transcription is done **locally** using **whisper.cpp** and a local model file.
- “Easy mode” UX: **overlay** for live text + **commit** action (copy + paste).

---

## Requirements

### Functional

- Runs as a **menu bar app** (no dock icon by default).
- Global hotkey:
  - `⌥ Space` toggles recording (start/stop) OR start-recording while held (choose one; see “Hotkey behavior”).
  - A separate commit hotkey (e.g. `⌥ Enter`) commits transcript.
- Audio capture:
  - Capture mic continuously while recording.
  - Convert to format expected by whisper.cpp: **mono, 16 kHz, 16-bit PCM** (or float32 depending on wrapper).
- Live transcription:
  - Display incremental transcript updates while speaking.
  - Finalize the current utterance when speech ends or user stops recording.
- Commit:
  - Copy final (or current) transcript to clipboard.
  - Attempt auto-paste into previously focused app (optional; may require Accessibility permission).
- Settings UI from menu bar:
  - Model selection/path
  - Language (auto/en), CPU threads, VAD sensitivity, update interval
  - “Auto-paste on commit” toggle

### Non-functional

- Low-latency, responsive UI; transcription runs off the main thread.
- Energy-aware (don’t transcribe when not recording).
- Safe permissions handling (Microphone; optional Accessibility).

---

## High-Level Architecture

### Core Modules

1. **App Shell (Menu Bar + Settings)**
   - Menu bar icon and dropdown:
     - Start/Stop Recording
     - Commit
     - Settings…
     - Quit
   - App lifecycle: background-only behavior.

2. **Hotkey Manager**
   - Registers global shortcuts (default ⌥ Space).
   - Emits actions into a state machine (start/stop/commit).
   - Stores user-customizable shortcuts in preferences.

3. **Audio Capture Pipeline**
   - `AVAudioEngine` input tap.
   - Conversion to 16 kHz mono PCM.
   - Writes frames into a ring buffer / segment buffer.

4. **Speech Segmentation (VAD / Turn Detection)**
   - Detect speech start/end.
   - Maintains “current utterance” buffer.
   - Determines when to run partial vs final transcription.

5. **Transcription Engine (whisper.cpp wrapper)**
   - Loads model once on app start or first use.
   - Provides:
     - `transcribePartial(audioWindow) -> partialText`
     - `transcribeFinal(utteranceAudio) -> finalText`
   - Runs in a dedicated worker queue; supports cancellation.

6. **Overlay UI (Mini Window)**
   - Non-activating floating panel (does not steal focus).
   - Shows:
     - Recording indicator
     - Partial transcript (live updates)
     - Committed transcript (optional)
     - Hint text for hotkeys (optional)

7. **Commit Controller**
   - Copies text to NSPasteboard.
   - Optionally issues a Cmd+V paste event into previously focused app.
   - Tracks previous frontmost app at recording start.

8. **Preferences / Model Management**
   - Stores settings in `UserDefaults` (or `AppStorage`).
   - Manages model files in `~/Library/Application Support/<AppName>/Models`.

---

## Technology Choices

### UI

- **SwiftUI** for views + **AppKit** for:
  - Menu bar status item (`NSStatusBar`)
  - Overlay window using `NSPanel` configured as non-activating, floating, joins all spaces.

### Global Hotkey

- Recommended: **KeyboardShortcuts** (Swift Package) for global hotkeys.
  - Doesn’t usually require Accessibility permission to register hotkeys.
  - Provides user-configurable shortcut recorder UI.

### whisper.cpp Integration

Two viable approaches; pick one:

**A) In-process C/C++ library (recommended)**

- Build whisper.cpp as a static library / XCFramework and expose a C header to Swift.
- Implement a Swift wrapper class around whisper.cpp APIs.
- Pros: lowest overhead, easiest streaming loop, best control.
- Cons: build system work (CMake + Xcode + SwiftPM integration).

**B) Out-of-process helper**

- Ship whisper.cpp binary and communicate via stdin/stdout or sockets.
- Pros: simpler Swift build.
- Cons: higher latency, harder partial updates, process mgmt.

This plan assumes **A (in-process)**.

### Performance Backends

- Enable Metal acceleration in whisper.cpp build if available (optional but recommended).
- Allow user to configure CPU threads; default to `max(2, physicalCores - 1)`.

---

## App State Machine

### States

- `idle`
- `recording`
- `finalizing` (stop requested, finishing last inference)
- `error`

### Events

- `hotkeyToggleRecording`
- `hotkeyCommit`
- `menuStartStop`
- `menuCommit`
- `vadSpeechStart`
- `vadSpeechEnd`
- `enginePartial(text)`
- `engineFinal(text)`
- `engineError(err)`

### Transitions (simplified)

- idle + toggle -> recording
- recording + toggle -> finalizing -> idle
- recording + commit -> commit current transcript (copy/paste) (remain recording or stop; decide UX)
- recording + speechEnd -> run final transcription for that utterance; append to committed transcript

---

## Audio Capture Pipeline Details

### Capture

- Use `AVAudioEngine` input node:
  - Install tap with small buffer size (e.g., 1024–2048 frames).
  - Capture in whatever the hardware provides, then convert.

### Conversion

- Convert to:
  - 16 kHz
  - Mono
  - PCM int16 or float32 (match your whisper.cpp wrapper expectations)
- Use `AVAudioConverter` to resample and downmix.

### Buffering Strategy

Maintain:

- `ringBuffer`: last N seconds of audio for partial transcription (e.g., 10–15s)
- `utteranceBuffer`: audio since last detected speech start

Ring buffer is used for partial updates; utterance buffer is used for finalization.

---

## VAD / Turn Detection

### Goals

- Detect start/end of speech to segment utterances.
- Avoid transcribing silence.
- Provide stable final chunks while allowing partial updates.

### Implementation Options

- Simple energy-based VAD (fast to implement):
  - Compute RMS/peak energy per frame.
  - Adaptive threshold (noise floor).
  - Require `minSpeechMs` before “speech start”
  - Require `silenceMs` before “speech end”
- Later upgrade option:
  - Integrate a more robust VAD model (not required for initial version).

### Suggested Defaults

- `minSpeechMs`: 150–250ms
- `silenceMs`: 600–900ms
- `partialUpdateInterval`: 300–700ms
- `maxPartialWindowSec`: 10–15s

---

## Live Transcription Strategy (Local whisper.cpp)

### Principle

Because Whisper-style models can revise text, “true streaming deltas” are approximated by:

- Running **partial transcription** repeatedly on a **sliding window** of recent audio while speech is ongoing.
- Running a **final transcription** on the utterance buffer when speech ends or recording stops.

### Partial Updates

- Every `partialUpdateInterval` while speech is detected:
  - Take last `maxPartialWindowSec` from ring buffer (or utterance buffer if shorter).
  - Run whisper.cpp inference with “fast/partial-friendly” settings:
    - No timestamps
    - Greedy decoding (optional)
    - Lower beam size for speed
  - Update overlay partial text.
- Optional improvement: “prompt” the decoder with already finalized text to improve continuity.

### Final Updates

- On `vadSpeechEnd` or stop recording:
  - Run full-quality inference on `utteranceBuffer`.
  - Append result to `finalTranscript` (with spacing rules).
  - Clear `utteranceBuffer` and partial text.

### Concurrency

- Audio capture runs on real-time thread; do minimal work there.
- VAD computation can run on a lightweight audio queue.
- whisper.cpp inference must run on a dedicated serial queue:
  - Cancel outstanding partial job when a newer one is scheduled.
  - Ensure model context is not accessed concurrently unless whisper.cpp API supports it (assume not).

---

## Overlay UI (Easy Mode)

### Window Type

- Use `NSPanel` with:
  - `isFloatingPanel = true`
  - `level = .floating`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
  - `hidesOnDeactivate = false`
  - `becomesKeyOnlyIfNeeded = false`
  - Configure as non-activating if possible so it doesn’t steal focus.

### Content

- SwiftUI view inside the panel:
  - Title row: mic icon + “Listening…” state
  - Large text area for live transcript (partial + finalized)
  - Optional hint row: “⌥ Enter to commit” etc.

### Positioning

- Default near top-center or near mouse cursor at recording start.
- Remember last position if user drags.

---

## Commit Behavior (Copy + Optional Paste)

### Copy

- On commit:
  - Copy `finalTranscript + partialTranscript` (or just final; decide) to clipboard via `NSPasteboard.general`.

### Optional Auto-Paste

- Attempt to paste into the previously focused app:
  - Track `frontmostApplication` when recording starts.
  - On commit:
    - Activate previous app
    - Send Cmd+V key event via `CGEvent` (requires Accessibility permissions).
- If Accessibility permission not granted:
  - Still copy to clipboard.
  - Provide UI feedback: “Copied to clipboard (enable Accessibility for auto-paste).”

### Text Normalization

- Trim whitespace.
- Ensure spacing between finalized segments.
- Optional punctuation/formatting is out-of-scope for v1.

---

## Permissions & Entitlements

### Microphone

- Add `NSMicrophoneUsageDescription` in Info.plist.

### Accessibility (only if auto-paste enabled)

- Explain clearly in UI why it’s needed.
- Provide a one-click link to System Settings → Privacy & Security → Accessibility (open URL or instructions).

### Sandboxing

- Decide early:
  - If sandboxed (Mac App Store), model files must be in app container.
  - Non-sandboxed is simpler for a dev tool.
- This plan assumes sandbox is optional; start non-sandboxed for iteration.

---

## Repository / Project Structure (Suggested)

- `App/`
  - `AppDelegate.swift` / `@main` entry
  - `MenuBarController.swift`
  - `SettingsView.swift`
- `Hotkeys/`
  - `HotkeyManager.swift`
- `Audio/`
  - `AudioEngineManager.swift`
  - `AudioConverter.swift`
  - `RingBuffer.swift`
  - `VAD.swift`
- `Transcription/`
  - `WhisperCppWrapper.swift`
  - `TranscriptionWorker.swift`
  - `ModelManager.swift`
- `Overlay/`
  - `OverlayPanelController.swift`
  - `OverlayView.swift`
- `Commit/`
  - `ClipboardManager.swift`
  - `PasteInjector.swift`
- `Resources/`
  - Default config, placeholder model instructions

---

## Implementation Steps (Milestones)

### Milestone 1 — Skeleton App

- Menu bar app with start/stop menu items.
- Settings window (empty).
- Overlay panel that can be shown/hidden.

### Milestone 2 — Hotkeys

- Add KeyboardShortcuts.
- Implement ⌥ Space toggle and ⌥ Enter commit.
- Show current status in overlay.

### Milestone 3 — Audio Capture + VAD

- Implement AVAudioEngine capture and resampling to 16 kHz mono.
- Implement simple VAD and utterance segmentation.
- Display “speech detected” indicator.

### Milestone 4 — whisper.cpp Integration

- Add whisper.cpp as dependency (submodule or vendor).
- Build as library/XCFramework.
- Implement minimal wrapper:
  - load model
  - transcribe float PCM buffer
- Validate with a recorded WAV file test.

### Milestone 5 — Live Partial Transcription

- Schedule partial inference every N ms during speech.
- Update overlay with partial text.
- Implement cancellation of overlapping partial jobs.

### Milestone 6 — Finalization + Commit

- On speech end, finalize utterance and append to final transcript.
- On commit: copy to clipboard.
- Add optional auto-paste with Accessibility gating.

### Milestone 7 — Model Management + Settings

- Download/import model file UI (choose file dialog).
- Save in Application Support.
- Expose settings: threads, VAD thresholds, update interval, model selection.

---

## Hotkey Behavior (Pick a v1)

Choose one and implement consistently:

**Option A: Toggle**

- ⌥ Space: start if idle, stop if recording.
- ⌥ Enter: commit (copy/paste). Recording continues unless user stops.

**Option B: Push-to-talk**

- Hold ⌥ Space: record while held; release stops and finalizes.
- ⌥ Enter: commit.

For simplest behavior and fewer edge cases: **Option A (Toggle)**.

---

## Notes / Risks

- Real-time feel depends on model size + hardware. Provide a default smaller model (e.g., base/small) and allow upgrade.
- Partial transcription may “rewrite” earlier words; v1 should treat partial as provisional and final as authoritative.
- If using in-process whisper.cpp, ensure no concurrent access to shared whisper context unless explicitly safe; serialize inference calls.
- Auto-paste requires Accessibility; make this optional and degrade gracefully.
