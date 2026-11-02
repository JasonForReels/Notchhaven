internal import AppKit
import SwiftUI

final class HomeWindowController: NSWindowController, NSWindowDelegate {
    static let shared = HomeWindowController()

    private var appDelegate: AppDelegate?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: HomeWindowLayout.width, height: HomeWindowLayout.height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.title = "Notchhaven"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("NotchhavenHomeWindow")
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.contentView = NSHostingView(rootView: HomeView())
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupDependencies(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    func showWindow() {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        let keepsDockIcon = appDelegate?.settingsViewModel.application.isDockIconVisible ?? false
        let settingsOpen = SettingsWindowController.shared.window?.isVisible == true
        if !keepsDockIcon, !settingsOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
