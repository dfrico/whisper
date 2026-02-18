import Foundation

/// Centralized typed access to UserDefaults settings.
struct AppSettings {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedModelPath = "selectedModelPath"
        static let language = "language"
        static let cpuThreads = "cpuThreads"
        static let vadSensitivity = "vadSensitivity"
        static let autoPasteEnabled = "autoPasteEnabled"
        static let partialUpdateInterval = "partialUpdateInterval"
    }

    var selectedModelPath: String? {
        get { defaults.string(forKey: Keys.selectedModelPath) }
        nonmutating set { defaults.set(newValue, forKey: Keys.selectedModelPath) }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? "en" }
        nonmutating set { defaults.set(newValue, forKey: Keys.language) }
    }

    var cpuThreads: Int {
        get {
            let val = defaults.integer(forKey: Keys.cpuThreads)
            return val > 0 ? val : 4
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.cpuThreads) }
    }

    var vadSensitivity: Float {
        get {
            if defaults.object(forKey: Keys.vadSensitivity) == nil { return 0.5 }
            return defaults.float(forKey: Keys.vadSensitivity)
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.vadSensitivity) }
    }

    var autoPasteEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoPasteEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Keys.autoPasteEnabled) }
    }

    var partialUpdateInterval: TimeInterval {
        get {
            let val = defaults.double(forKey: Keys.partialUpdateInterval)
            return val > 0 ? val : 0.5
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.partialUpdateInterval) }
    }
}
