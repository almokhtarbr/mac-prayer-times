import SwiftUI

@main
struct PrayerTimesApp: App {
    @StateObject private var prayerManager = PrayerManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(prayerManager)
        } label: {
            Image(systemName: "moon.stars.fill")
            Text(prayerManager.menuBarText)
        }
        .menuBarExtraStyle(.window)
    }
}

// Direct NSWindow for Settings — works reliably in MenuBarExtra / LSUIElement apps
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func open(prayerManager: PrayerManager) {
        // If window already exists, just bring it forward
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(prayerManager)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Prayer Times Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}
