import Foundation

struct ModelManager {
    enum ModelSize: String, CaseIterable {
        case tiny = "tiny"
        case tinyEn = "tiny.en"
        case base = "base"
        case baseEn = "base.en"
        case small = "small"
        case smallEn = "small.en"
        case medium = "medium"
        case mediumEn = "medium.en"
        case largev3 = "large-v3"
        case largev3turbo = "large-v3-turbo"

        var displayName: String {
            switch self {
            case .tiny: return "Tiny (75 MB)"
            case .tinyEn: return "Tiny English (75 MB)"
            case .base: return "Base (142 MB)"
            case .baseEn: return "Base English (142 MB)"
            case .small: return "Small (466 MB)"
            case .smallEn: return "Small English (466 MB)"
            case .medium: return "Medium (1.5 GB)"
            case .mediumEn: return "Medium English (1.5 GB)"
            case .largev3: return "Large v3 (3.1 GB)"
            case .largev3turbo: return "Large v3 Turbo (1.6 GB)"
            }
        }
    }

    /// Directory where models are stored.
    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whisper/Models", isDirectory: true)
    }

    /// Ensure the models directory exists.
    static func ensureModelsDirectory() {
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    /// Return the default model path if one exists.
    static func defaultModelPath() -> String? {
        let models = availableModels()
        return models.first?.path
    }

    /// List all .bin model files in the models directory.
    static func availableModels() -> [(name: String, path: String)] {
        ensureModelsDirectory()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { (name: $0.deletingPathExtension().lastPathComponent, path: $0.path) }
    }

    /// Import a model file by copying it to the models directory.
    static func importModel(from sourceURL: URL) throws -> String {
        ensureModelsDirectory()
        let dest = modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: sourceURL, to: dest)
        return dest.path
    }

    /// Delete a model file.
    static func deleteModel(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
}
