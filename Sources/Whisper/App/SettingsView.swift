import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    let appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 420, height: 260)
    }
}

private struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings will appear here.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
            KeyboardShortcuts.Recorder("Commit Transcript:", name: .commitTranscript)
        }
        .formStyle(.grouped)
    }
}
