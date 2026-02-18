import SwiftUI

@main
struct WhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes — this is a menu-bar-only app.
        // Settings window is managed directly via SettingsWindowController.
        Settings {
            EmptyView()
        }
    }
}
