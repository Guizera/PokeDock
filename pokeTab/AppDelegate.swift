import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    private var encounterPanel: NSPanel?
    private var customDockPanel: NSPanel?
    private var customDockContentWidth: CGFloat = 0
    private let game = GameController.shared

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        syncCustomDock()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        positionCustomDock()
        if let encounterPanel { positionEncounter(encounterPanel) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    func showEncounter() {
        guard game.currentEncounter != nil else { return }
        game.markCurrentEncounterSeen()
        NSApp.activate(ignoringOtherApps: true)
        if let encounterPanel {
            positionEncounter(encounterPanel)
            encounterPanel.makeKeyAndOrderFront(nil)
            encounterPanel.orderFrontRegardless()
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = NSLocalizedString("Encontro Pokémon", comment: "Encounter window title")
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: EncounterView(game: game) { [weak self] in
            self?.encounterPanel?.close()
            self?.encounterPanel = nil
        })
        positionEncounter(panel)
        encounterPanel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func positionEncounter(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let screen {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.midX - panel.frame.width / 2, y: visible.midY - panel.frame.height / 2))
        } else {
            panel.center()
        }
    }

    func syncCustomDock() {
        DockAutoHideController.shared.sync(enabled: CustomDockController.shared.isEnabled)
        guard CustomDockController.shared.isEnabled else {
            customDockPanel?.close()
            customDockPanel = nil
            return
        }
        if let customDockPanel {
            positionCustomDock()
            customDockPanel.orderFrontRegardless()
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: DockMetrics.fixedWidth + 100, height: DockMetrics.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: CustomDockView())
        customDockPanel = panel
        positionCustomDock()
        panel.orderFrontRegardless()
    }

    func updateCustomDockContentWidth(_ width: CGFloat) {
        guard abs(customDockContentWidth - width) > 0.5 else { return }
        customDockContentWidth = width
        positionCustomDock()
    }

    private func positionCustomDock() {
        guard let customDockPanel, let screen = customDockPanel.screen ?? NSScreen.main else { return }
        let frame = screen.frame
        let desiredWidth = DockMetrics.fixedWidth + customDockContentWidth
        let width = min(desiredWidth, max(0, frame.width - 32))
        customDockPanel.setFrame(
            NSRect(x: frame.midX - width / 2, y: frame.minY + 2, width: width, height: DockMetrics.panelHeight),
            display: true
        )
    }
}
