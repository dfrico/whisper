import KeyboardShortcuts

final class HotkeyManager {
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        setupHandlers()
    }

    private func setupHandlers() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.appState.toggleRecording()
        }

        KeyboardShortcuts.onKeyDown(for: .commitTranscript) { [weak self] in
            self?.appState.commitTranscript()
        }
    }
}
