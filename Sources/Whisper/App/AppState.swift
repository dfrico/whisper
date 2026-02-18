import AppKit
import Observation

enum RecordingState: Equatable {
    case idle
    case recording
    case finalizing
    case error(String)

    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.finalizing, .finalizing):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    var liveTranscript: String = ""
    var finalTranscript: String = ""
    var isSpeechDetected: Bool = false
    var audioLevel: Float = 0.0

    /// The frontmost app when recording started, used for auto-paste targeting.
    var sourceApp: NSRunningApplication?

    var isRecording: Bool {
        recordingState == .recording
    }

    func toggleRecording() {
        switch recordingState {
        case .idle, .error:
            recordingState = .recording
            liveTranscript = ""
            finalTranscript = ""
        case .recording:
            recordingState = .idle
            isSpeechDetected = false
            audioLevel = 0.0
        case .finalizing:
            break
        }
    }

    func commitTranscript() {
        guard isRecording || !finalTranscript.isEmpty else { return }
        if isRecording {
            recordingState = .finalizing
        }
    }

    func setError(_ message: String) {
        recordingState = .error(message)
        isSpeechDetected = false
        audioLevel = 0.0
    }
}
