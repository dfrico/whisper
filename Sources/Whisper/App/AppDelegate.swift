import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let appState = AppState()
    private var menuBarController: MenuBarController!
    private var overlayController: OverlayPanelController!
    private var hotkeyManager: HotkeyManager!
    private var audioManager: AudioEngineManager!
    private var transcriptionWorker: TranscriptionWorker?
    private var whisperContext: WhisperContext?

    func applicationDidFinishLaunching(_ notification: Notification) {
        audioManager = AudioEngineManager(appState: appState)
        menuBarController = MenuBarController(appState: appState)
        overlayController = OverlayPanelController(appState: appState)
        hotkeyManager = HotkeyManager(appState: appState)

        audioManager.onSpeechStateChanged = { [weak self] isSpeech in
            self?.handleSpeechTransition(isSpeech: isSpeech)
        }

        loadWhisperModel()
        observeRecordingState()
    }

    private func loadWhisperModel() {
        let settings = AppSettings()
        guard let modelPath = settings.selectedModelPath else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let ctx = try WhisperContext(modelPath: modelPath)
                let service = WhisperTranscriptionService(
                    context: ctx,
                    language: settings.language,
                    threads: settings.cpuThreads
                )
                let worker = TranscriptionWorker(
                    service: service,
                    utteranceBuffer: self.audioManager.utteranceBuffer,
                    appState: self.appState
                )
                worker.partialInterval = settings.partialUpdateInterval
                DispatchQueue.main.async {
                    self.whisperContext = ctx
                    self.transcriptionWorker = worker
                }
            } catch {
                DispatchQueue.main.async {
                    self.appState.setError("Model load failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func reloadWhisperModel() {
        guard appState.recordingState == .idle else { return }
        whisperContext = nil
        transcriptionWorker = nil
        loadWhisperModel()
    }

    private func handleSpeechTransition(isSpeech: Bool) {
        guard appState.isRecording else { return }

        if isSpeech {
            transcriptionWorker?.startPartialLoop()
        } else {
            transcriptionWorker?.stopPartialLoop()
            // Run final inference for this utterance segment
            transcriptionWorker?.runFinalInference { [weak self] text in
                guard let self, self.appState.isRecording else { return }
                if !text.isEmpty {
                    if self.appState.finalTranscript.isEmpty {
                        self.appState.finalTranscript = text
                    } else {
                        self.appState.finalTranscript += " " + text
                    }
                }
                self.appState.liveTranscript = ""
                self.audioManager.utteranceBuffer.reset()
            }
        }
    }

    private func observeRecordingState() {
        withObservationTracking {
            _ = appState.recordingState
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.handleRecordingStateChange()
                self?.observeRecordingState()
            }
        }
    }

    private func handleRecordingStateChange() {
        switch appState.recordingState {
        case .recording:
            appState.sourceApp = NSWorkspace.shared.frontmostApplication
            startAudioCapture()
            overlayController.showOverlay()
        case .idle:
            audioManager.stop()
            transcriptionWorker?.stopPartialLoop()
            overlayController.hideOverlay()
        case .finalizing:
            performCommit()
        case .error:
            audioManager.stop()
            transcriptionWorker?.stopPartialLoop()
            overlayController.showOverlay()
        }
    }

    private func startAudioCapture() {
        let settings = AppSettings()
        audioManager.setVADSensitivity(settings.vadSensitivity)
        audioManager.inputGain = settings.inputGain
        transcriptionWorker?.partialInterval = settings.partialUpdateInterval

        do {
            try audioManager.start()
        } catch {
            appState.setError("Mic error: \(error.localizedDescription)")
        }
    }

    private func performCommit() {
        audioManager.stop()
        transcriptionWorker?.stopPartialLoop()

        let settings = AppSettings()
        let buffer = audioManager.utteranceBuffer

        if buffer.count > 0 {
            // Final inference on remaining audio, then commit
            transcriptionWorker?.runFinalInference { [weak self] text in
                guard let self else { return }
                if !text.isEmpty {
                    if self.appState.finalTranscript.isEmpty {
                        self.appState.finalTranscript = text
                    } else {
                        self.appState.finalTranscript += " " + text
                    }
                }
                buffer.reset()
                self.finishCommit(settings: settings)
            }
        } else {
            finishCommit(settings: settings)
        }
    }

    private func finishCommit(settings: AppSettings) {
        let text = CommitController.assembleText(
            finalTranscript: appState.finalTranscript,
            liveTranscript: appState.liveTranscript
        )

        guard !text.isEmpty else {
            appState.recordingState = .idle
            return
        }

        CommitController.commit(
            text: text,
            sourceApp: appState.sourceApp,
            autoPaste: settings.autoPasteEnabled
        )

        appState.liveTranscript = ""
        appState.finalTranscript = ""
        appState.recordingState = .idle
    }
}
