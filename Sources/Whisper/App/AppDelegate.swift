import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    let appState = AppState()
    private var menuBarController: MenuBarController!
    private var overlayController: OverlayPanelController!
    private var hotkeyManager: HotkeyManager!
    private var audioManager: AudioEngineManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(appState: appState)
        overlayController = OverlayPanelController(appState: appState)
        hotkeyManager = HotkeyManager(appState: appState)
        audioManager = AudioEngineManager(appState: appState)

        observeRecordingState()
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
            startAudioCapture()
            overlayController.showOverlay()
        case .idle:
            audioManager.stop()
            overlayController.hideOverlay()
        case .finalizing:
            audioManager.stop()
            // Will handle commit flow in later milestones
            appState.recordingState = .idle
        case .error:
            audioManager.stop()
            overlayController.showOverlay()
        }
    }

    private func startAudioCapture() {
        do {
            try audioManager.start()
        } catch {
            appState.setError("Mic error: \(error.localizedDescription)")
        }
    }
}
