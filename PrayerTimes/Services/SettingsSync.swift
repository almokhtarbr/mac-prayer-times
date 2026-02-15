import Foundation

/// Syncs settings between UserDefaults and iCloud (NSUbiquitousKeyValueStore).
/// Falls back gracefully when iCloud is unavailable (no developer account / not signed in).
class SettingsSync {
    static let shared = SettingsSync()

    // Keys to sync between local and iCloud
    private let syncKeys: [String] = [
        "adhanEnabled",
        "calculationMethod",
        "menuBarDisplayMode",
        "iqamaFajr",
        "iqamaDhuhr",
        "iqamaAsr",
        "iqamaMaghrib",
        "iqamaIsha"
    ]

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard

    /// Call once at app launch to start syncing
    func start() {
        // Listen for external changes from iCloud
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )

        // Force an initial sync from iCloud
        cloud.synchronize()

        // Push local settings to iCloud (local wins on first launch)
        pushToCloud()
    }

    /// Push current UserDefaults to iCloud
    func pushToCloud() {
        for key in syncKeys {
            if let value = local.object(forKey: key) {
                cloud.set(value, forKey: key)
            }
        }
        cloud.synchronize()
    }

    /// Pull iCloud values into UserDefaults
    @objc private func iCloudDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }

        // Only pull on server change or initial sync — not on quota violation
        guard reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            return
        }

        if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in changedKeys where syncKeys.contains(key) {
                if let value = cloud.object(forKey: key) {
                    local.set(value, forKey: key)
                }
            }
        }

        // Notify the app that settings changed externally
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .settingsDidSyncFromCloud, object: nil)
        }
    }
}

extension Notification.Name {
    static let settingsDidSyncFromCloud = Notification.Name("settingsDidSyncFromCloud")
}
