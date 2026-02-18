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

            ModelSettingsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
        }
        .frame(width: 480, height: 380)
    }
}

private struct GeneralSettingsView: View {
    @State private var language: String = AppSettings().language
    @State private var cpuThreads: Int = AppSettings().cpuThreads
    @State private var vadSensitivity: Float = AppSettings().vadSensitivity
    @State private var inputGain: Float = AppSettings().inputGain
    @State private var partialInterval: Double = AppSettings().partialUpdateInterval
    @State private var autoPaste: Bool = AppSettings().autoPasteEnabled
    @State private var hasAccessibility: Bool = CommitController.hasAccessibilityPermission()

    var body: some View {
        Form {
            Picker("Language:", selection: $language) {
                Text("Auto").tag("auto")
                Text("English").tag("en")
                Text("Spanish").tag("es")
                Text("French").tag("fr")
                Text("German").tag("de")
                Text("Italian").tag("it")
                Text("Portuguese").tag("pt")
                Text("Japanese").tag("ja")
                Text("Korean").tag("ko")
                Text("Chinese").tag("zh")
            }
            .onChange(of: language) { _, newValue in
                AppSettings().language = newValue
            }

            Stepper("CPU Threads: \(cpuThreads)", value: $cpuThreads, in: 1...16)
                .onChange(of: cpuThreads) { _, newValue in
                    AppSettings().cpuThreads = newValue
                }

            VStack(alignment: .leading) {
                Text("Mic Gain: \(String(format: "%.1f×", inputGain))")
                Slider(value: $inputGain, in: 1.0...5.0, step: 0.5)
                    .onChange(of: inputGain) { _, newValue in
                        AppSettings().inputGain = newValue
                    }
                Text("Boost microphone input volume (applies on next recording)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading) {
                Text("VAD Sensitivity: \(String(format: "%.0f%%", vadSensitivity * 100))")
                Slider(value: $vadSensitivity, in: 0...1, step: 0.05)
                    .onChange(of: vadSensitivity) { _, newValue in
                        AppSettings().vadSensitivity = newValue
                    }
            }

            VStack(alignment: .leading) {
                Text("Partial Update Interval: \(String(format: "%.1fs", partialInterval))")
                Slider(value: $partialInterval, in: 0.3...2.0, step: 0.1)
                    .onChange(of: partialInterval) { _, newValue in
                        AppSettings().partialUpdateInterval = newValue
                    }
            }

            Toggle("Auto-paste after commit", isOn: $autoPaste)
                .onChange(of: autoPaste) { _, newValue in
                    AppSettings().autoPasteEnabled = newValue
                    if newValue && !hasAccessibility {
                        CommitController.requestAccessibilityPermission()
                    }
                }

            if autoPaste && !hasAccessibility {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Accessibility permission required for auto-paste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Request") {
                        CommitController.requestAccessibilityPermission()
                        // Re-check after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            hasAccessibility = CommitController.hasAccessibilityPermission()
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ModelSettingsView: View {
    @State private var models: [(name: String, path: String)] = ModelManager.availableModels()
    @State private var selectedPath: String? = AppSettings().selectedModelPath
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        Form {
            Section("Installed Models") {
                if models.isEmpty {
                    Text("No models installed.")
                        .foregroundStyle(.secondary)
                    Text("Import a GGML model file (.bin) to get started.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(models, id: \.path) { model in
                        HStack {
                            Image(systemName: model.path == selectedPath ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.path == selectedPath ? .blue : .secondary)

                            Text(model.name)
                                .font(.body)

                            Spacer()

                            Button(role: .destructive) {
                                deleteModel(at: model.path)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPath = model.path
                            AppSettings().selectedModelPath = model.path
                        }
                    }
                }
            }

            Section {
                Button("Import Model…") {
                    showImporter = true
                }
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [.data],
                    allowsMultipleSelection: false
                ) { result in
                    handleImport(result)
                }

                if let error = importError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Text("Models are stored in:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ModelManager.modelsDirectory.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        importError = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            do {
                let path = try ModelManager.importModel(from: url)
                models = ModelManager.availableModels()
                if selectedPath == nil {
                    selectedPath = path
                    AppSettings().selectedModelPath = path
                }
            } catch {
                importError = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            importError = "Import failed: \(error.localizedDescription)"
        }
    }

    private func deleteModel(at path: String) {
        try? ModelManager.deleteModel(at: path)
        models = ModelManager.availableModels()
        if selectedPath == path {
            selectedPath = models.first?.path
            AppSettings().selectedModelPath = selectedPath
        }
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
