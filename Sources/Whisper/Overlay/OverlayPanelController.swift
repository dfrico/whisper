import AppKit
import SwiftUI

final class OverlayPanelController {
    private let panel: NSPanel
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: OverlayView(appState: appState))
        panel.contentView = hostingView
    }

    func showOverlay() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hideOverlay() {
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Fit content
        panel.contentView?.layout()
        let contentSize = panel.contentView?.fittingSize ?? CGSize(width: 360, height: 120)
        let panelFrame = NSRect(
            x: screenFrame.midX - contentSize.width / 2,
            y: screenFrame.maxY - contentSize.height - 40,
            width: contentSize.width,
            height: contentSize.height
        )
        panel.setFrame(panelFrame, display: true)
    }
}
