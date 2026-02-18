import AppKit

struct CommitController {
    /// Combine finalized segments and any pending partial text.
    static func assembleText(finalTranscript: String, liveTranscript: String) -> String {
        var parts: [String] = []
        let final = finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let live = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty { parts.append(final) }
        if !live.isEmpty { parts.append(live) }
        return parts.joined(separator: " ")
    }

    /// Copy text to clipboard and optionally auto-paste into the source app.
    static func commit(text: String, sourceApp: NSRunningApplication?, autoPaste: Bool) {
        ClipboardManager.copy(text)

        guard autoPaste, let app = sourceApp else { return }
        guard hasAccessibilityPermission() else { return }

        app.activate()
        // Small delay to allow the source app to become frontmost
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteInjector.paste()
        }
    }

    /// Check if this app has Accessibility permission (required for CGEvent paste injection).
    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrustedWithOptions(nil)
    }

    /// Prompt the user for Accessibility permission.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
