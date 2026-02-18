import AppKit
import Observation

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let appState: AppState
    private let settingsWindowController: SettingsWindowController
    private var startStopItem: NSMenuItem!
    private var commitItem: NSMenuItem!

    init(appState: AppState) {
        self.appState = appState
        self.settingsWindowController = SettingsWindowController(appState: appState)
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "Whisper"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        startStopItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        startStopItem.target = self

        commitItem = NSMenuItem(
            title: "Commit Transcript",
            action: #selector(commitTranscript),
            keyEquivalent: ""
        )
        commitItem.target = self

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit Whisper",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        menu.addItem(startStopItem)
        menu.addItem(commitItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        startStopItem.title = appState.isRecording ? "Stop Recording" : "Start Recording"
        commitItem.isEnabled = appState.isRecording || !appState.finalTranscript.isEmpty
    }

    // MARK: - Actions

    @objc private func toggleRecording() {
        appState.toggleRecording()
    }

    @objc private func commitTranscript() {
        appState.commitTranscript()
    }

    @objc private func openSettings() {
        settingsWindowController.showSettings()
    }
}
