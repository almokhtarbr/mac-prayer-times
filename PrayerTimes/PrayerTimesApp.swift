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

        Settings {
            SettingsView()
                .environmentObject(prayerManager)
        }
    }
}
