import SwiftUI

struct OverlayView: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status row
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()

                if appState.isSpeechDetected {
                    Text("SPEECH")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }

            // Audio level meter
            if appState.isRecording {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.quaternary)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(appState.isSpeechDetected ? .green : .blue)
                            .frame(
                                width: geometry.size.width * CGFloat(min(appState.audioLevel, 1.0)),
                                height: 4
                            )
                            .animation(.linear(duration: 0.05), value: appState.audioLevel)
                    }
                }
                .frame(height: 4)
            }

            // Transcript area — finalized text (primary) + live partial (secondary)
            if !appState.finalTranscript.isEmpty || !appState.liveTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !appState.finalTranscript.isEmpty {
                        Text(appState.finalTranscript)
                            .font(.system(.body, design: .default))
                            .foregroundStyle(.primary)
                            .lineLimit(nil)
                            .textSelection(.enabled)
                    }
                    if !appState.liveTranscript.isEmpty {
                        Text(appState.liveTranscript)
                            .font(.system(.body, design: .default))
                            .foregroundStyle(.secondary)
                            .italic()
                            .lineLimit(nil)
                            .textSelection(.enabled)
                    }
                }
            } else if appState.isRecording {
                Text("Listening…")
                    .font(.system(.body, design: .default))
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            // Hotkey hints
            HStack {
                Spacer()
                Text("⌥Space toggle · ⌥Enter commit")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(16)
        .frame(width: 360, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        switch appState.recordingState {
        case .recording:
            return appState.isSpeechDetected ? .green : .red
        case .error:
            return .orange
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch appState.recordingState {
        case .idle:
            return "Idle"
        case .recording:
            return appState.isSpeechDetected ? "Recording (speech)" : "Recording (silence)"
        case .finalizing:
            return "Finalizing…"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}
