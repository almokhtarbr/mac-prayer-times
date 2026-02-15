# Prayer Times Mac App — Dev Log

All decisions, conversations, and context for this project.

## Session 1 — Feb 14, 2026

### What was built
- Complete Mac menu bar prayer times app from scratch
- SwiftUI + MenuBarExtra, adhan-swift for calculations, CoreLocation for GPS
- Full adhan audio playback at prayer time
- Iqama times with configurable per-prayer offsets
- System notifications at both adhan and iqama times
- Settings window (NSWindow-based, not SwiftUI Settings scene — see bug fix below)
- Launch at login via SMAppService
- GitHub repo with CI/CD (GitHub Actions auto-builds on tag)

### Architecture decisions
- **adhan-swift** chosen over API calls — 100% offline, no dependencies, no rate limits
- **ISNA calculation method** hardcoded for MVP — will add picker later
- **MenuBarExtra with .window style** — gives a proper SwiftUI popover, not a basic menu
- **LSUIElement = YES** — no dock icon, pure menu bar app
- **PrayerManager owns LocationManager and AdhanPlayer** — single source of truth
- **Iqama as offset (minutes after adhan)** — stored in UserDefaults per prayer, not fixed clock times
- **NSWindow for Settings** — SwiftUI `Settings` scene + `showSettingsWindow:` selector doesn't work in MenuBarExtra/LSUIElement apps. Replaced with direct NSWindow via SettingsWindowController singleton.
- **No app sandbox** — user removed it during dev. Needed for location to work without friction. Will re-enable for App Store submission.

### Bugs fixed
1. **adhan.mp3 not in bundle** — file was in Resources/ folder but not referenced in pbxproj. Added file reference + build phase entry.
2. **Wrong audio filename** — AdhanPlayer referenced "cd17c7200df5" instead of "adhan". Fixed to match actual filename.
3. **Settings button not working** — `showSettingsWindow:` selector doesn't work from MenuBarExtra popover in LSUIElement apps. Replaced with SettingsWindowController using direct NSWindow + NSHostingController.
4. **"App is damaged" on download** — macOS Gatekeeper blocks unsigned apps. Added `xattr -cr` instructions to README and release notes. Proper fix requires $99/year Apple Developer Account for code signing + notarization.
5. **GitHub Actions release permission** — `softprops/action-gh-release` needs `permissions: contents: write` in the workflow.

### Distribution
- GitHub repo: https://github.com/almokhtarbr/mac-prayer-times
- Releases via GitHub Actions — tag `vX.Y.Z` → auto-build → release with PrayerTimes.zip
- Unsigned build — users need `xattr -cr` on first run
- Posted to: (pending) Reddit r/islam, r/macapps, Product Hunt, Hacker News

### Feature discussions
Discussed and prioritized features for the roadmap:

**High impact:**
1. Hijri date in header
2. Countdown to iqama (not just adhan)
3. Fajr tomorrow after Isha passes
4. Calculation method picker
5. Friday/Jumuah mode

**Medium impact:**
6. Sunrise row
7. Sound picker (multiple adhan recordings)
8. Volume control
9. Global keyboard shortcut
10. Quiet hours / do not disturb

**Nice to have:**
11. Qibla compass
12. Ramadan mode (Suhoor/Iftar)
13. Notification Center widget
14. iCloud sync
15. Menu bar display options

### Tech notes
- adhan-swift v1.4.0, package name "Adhan"
- `CalculationMethod.northAmerica.params` = ISNA
- `PrayerTimes(coordinates:date:calculationParameters:)` returns times for all prayers
- `times.nextPrayer(at: Date())` returns `Prayer?` — can be `.sunrise` (skip it in display)
- `times.time(for: .fajr)` returns `Date`
- macOS Ventura (13.0) minimum deployment target
- GitHub Actions uses `macos-15` runner with Xcode 16.2

---

## Session 2 — Feb 14, 2026

### What was built
Implemented all 5 high-priority features from the roadmap, following proper software engineering workflow (feature branches → PRs → merge to main).

### Features implemented
1. **Hijri date in header** (#1, PR #16) — Uses Foundation's `Calendar(identifier: .islamicUmmAlQura)` to show Islamic date like "16 Sha'ban 1447 AH" in the popover header.
2. **Iqama countdown** (#2, PR #16) — After adhan time passes, countdown switches to show "Dhuhr iqama in 12m" instead of just going to the next prayer.
3. **Fajr tomorrow** (#3, PR #16) — After Isha passes, the app shows tomorrow's Fajr time as the next prayer with accurate countdown.
4. **Calculation method picker** (#4, PR #17) — Settings now has a dropdown with 11 methods: ISNA, MWL, Egyptian, Umm al-Qura, Dubai, Karachi, Kuwait, Qatar, Singapore, Tehran, Turkey. Selection persists and recalculates immediately.
5. **Friday / Jumuah mode** (#5, PR #18) — On Fridays, "Dhuhr" automatically shows as "Jumuah".

### Process improvements
- Created 15 GitHub Issues for the full roadmap (labeled by priority)
- Updated README roadmap to link to GitHub Issues
- Adopted feature branch workflow: `feature/xxx` → PR → merge → delete branch
- Each feature verified with `xcodebuild` before committing

### Architecture decisions
- **CalculationMethodOption enum** — Maps readable names to adhan-swift's `CalculationMethod` and `CalculationParameters`. Stored as raw string in UserDefaults.
- **Hijri via Foundation** — No external dependency. `Calendar(identifier: .islamicUmmAlQura)` is built into macOS. Umm al-Qura variant chosen as it's the most widely used.
- **countdownInfo() tuple** — Returns `(label, time)` so the view doesn't need to know about adhan vs iqama state logic.
- **Tomorrow's Fajr** — When `nextPrayer()` returns nil and we're past Isha iqama, calculate tomorrow's date components and get a fresh PrayerTimes object for Fajr.

### Tech notes
- `Calendar.current.component(.weekday, from: Date()) == 6` = Friday in Foundation (1=Sunday)
- `Calendar(identifier: .islamicUmmAlQura)` with `DateFormatter.dateFormat = "d MMMM yyyy"` gives "16 Sha'ban 1447"
- adhan-swift supports: `.northAmerica`, `.muslimWorldLeague`, `.egyptian`, `.ummAlQura`, `.dubai`, `.karachi`, `.kuwait`, `.qatar`, `.singapore`, `.tehran`, `.turkey`

---

## Session 3 — Feb 14, 2026

### What was built
Implemented 5 medium/nice-to-have features from the roadmap in 2 PRs, plus Notification Center widget and iCloud sync prep.

### Features implemented

**PR #19 — Widget, iCloud sync, menu bar display options:**
1. **Notification Center widget** (#13) — WidgetKit-based widget in small and medium sizes. Small shows next prayer name + countdown. Medium shows next prayer highlight on left + full 5-prayer list on right with Hijri date. Uses App Group (`group.com.prayertimes.shared`) UserDefaults to share data from the main app.
2. **iCloud settings sync** (#14) — `SettingsSync` service wraps `NSUbiquitousKeyValueStore` to sync all settings (calculation method, iqama offsets, adhan toggle, display mode) across devices. Falls back gracefully when no paid dev account is active. Local-wins on first launch, then listens for `didChangeExternallyNotification`.
3. **Menu bar display options** (#15) — 4 modes via `MenuBarDisplayMode` enum: "Prayer + countdown" (default), "Countdown only", "Prayer + time", "Icon only". Stored in UserDefaults, picker in Settings.

**PR #20 — Sunrise row, volume control, quiet hours:**
4. **Sunrise row** (#6) — Added `.sunrise` to `displayPrayers` list. Renders with a sunrise icon instead of the green/gray dot. No iqama column for sunrise (empty cell). Excluded from adhan playback and notifications.
5. **Volume control** (#8) — `AdhanPlayer` now stores volume in UserDefaults (`adhanVolume`, default 0.8). Slider in Settings (0–100%) with speaker icons. Preview button to test sound. Volume changes apply to currently playing audio immediately.
6. **Quiet hours / DND** (#10) — Configurable start/end time range stored as minutes-from-midnight. Supports overnight ranges (e.g. 23:00–07:00). When active, `isDNDActive()` returns true and adhan audio is skipped (notifications still fire).

### Architecture decisions

- **App Group for widget** — `group.com.prayertimes.shared` UserDefaults suite. Main app writes `nextPrayerName`, `nextPrayerTime`, `nextIqamaTime`, `hijriDate`, `allPrayerTimes` (array of dicts), plus location coordinates and calculation method. Widget reads on timeline refresh (every 15 min).
- **iCloud via NSUbiquitousKeyValueStore** — Simpler than CloudKit, perfect for small settings. Syncs 8 keys. Posts custom `.settingsDidSyncFromCloud` notification so PrayerManager recalculates immediately when settings arrive from another device.
- **DND as minutes-from-midnight** — Avoids Date serialization complexity. Two integers (`dndStart`, `dndEnd`). Handles overnight ranges by checking `now >= start || now < end` when start > end.
- **Volume in UserDefaults** — `AdhanPlayer.volume` property reads/writes `adhanVolume` key directly. Setting updates both the stored value and the live `AVAudioPlayer.volume`.
- **Sunrise as display-only row** — Added to `displayPrayers` but filtered out in `checkForAdhan()`, `scheduleNotifications()`, and iqama column display. Uses `entry.id == "Sunrise"` checks.
- **MenuBarDisplayMode enum** — `CaseIterable + Identifiable`, raw string values for both display and storage. `PrayerManager.displayMode` computed property reads from UserDefaults.

### File-by-file source overview (1,275 lines total)

| File | Lines | Purpose |
|------|-------|---------|
| `PrayerTimesApp.swift` | 48 | App entry point. `MenuBarExtra` with `.window` style. `SettingsWindowController` singleton for NSWindow-based settings (works around LSUIElement limitation). |
| `MenuBarView.swift` | 145 | Dropdown popover. Header (Gregorian + Hijri dates), prayer list with adhan/iqama columns, sunrise row with icon, next-prayer countdown, settings/stop/quit footer. |
| `SettingsView.swift` | 183 | Form with grouped sections: Sound (toggle + volume slider + preview), Quiet Hours (toggle + time pickers), Iqama Offsets (5 steppers), Location, Menu Bar display picker, General (launch at login), Calculation Method picker, About (version). |
| `PrayerManager.swift` | 480 | Core model. Owns `LocationManager` and `AdhanPlayer`. Calculates prayer times via adhan-swift, manages entries, handles tomorrow's Fajr after Isha, Jumuah on Fridays, Hijri date formatting, menu bar text by display mode, adhan triggering with DND check, iqama countdown logic, notification scheduling, widget data sharing via App Group. 30-second timer for recalculation. |
| `LocationManager.swift` | 62 | CLLocationManager wrapper. Publishes `location` and `locationName`. Requests when-in-use authorization, reverse geocodes to "City, Country" string. |
| `AdhanPlayer.swift` | 59 | AVFoundation audio player. Loads `adhan.mp3` from bundle, plays with configurable volume, publishes `isPlaying` state, delegate-based stop detection. |
| `SettingsSync.swift` | 80 | iCloud KVS sync. Pushes 8 UserDefaults keys to `NSUbiquitousKeyValueStore`. Pulls on `didChangeExternallyNotification` (server change + initial sync only). Posts `.settingsDidSyncFromCloud` for app-level refresh. |
| `PrayerTimesWidget.swift` | 218 | WidgetKit extension. `PrayerTimesProvider` reads from App Group UserDefaults. `PrayerWidgetSmallView` (next prayer + countdown), `PrayerWidgetMediumView` (next prayer highlight + full prayer list). Refreshes every 15 min. |

### Data flow

```
GPS → LocationManager → PrayerManager.calculateTimes()
                              ↓
                    adhan-swift (astronomy math)
                              ↓
              PrayerEntry[] (6 prayers incl. sunrise)
                    ↓              ↓              ↓
            MenuBarView    Notifications    App Group UD
            (popover)      (adhan + iqama)  (widget data)
                    ↓                              ↓
            Menu bar text              PrayerTimesWidget
            (4 display modes)          (small + medium)
```

### UserDefaults keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `adhanEnabled` | Bool | true | Play adhan sound at prayer time |
| `adhanVolume` | Float | 0.8 | Volume 0.0–1.0 |
| `dndEnabled` | Bool | false | Quiet hours toggle |
| `dndStart` | Int | 1380 | Quiet hours start (minutes from midnight, 23:00) |
| `dndEnd` | Int | 420 | Quiet hours end (minutes from midnight, 07:00) |
| `calculationMethod` | String | "ISNA (North America)" | CalculationMethodOption raw value |
| `menuBarDisplayMode` | String | "Prayer + countdown" | MenuBarDisplayMode raw value |
| `iqamaFajr` | Int | 20 | Fajr iqama offset in minutes |
| `iqamaDhuhr` | Int | 15 | Dhuhr iqama offset in minutes |
| `iqamaAsr` | Int | 10 | Asr iqama offset in minutes |
| `iqamaMaghrib` | Int | 5 | Maghrib iqama offset in minutes |
| `iqamaIsha` | Int | 15 | Isha iqama offset in minutes |

### Build & distribution

- **Local build**: `xcodebuild -scheme PrayerTimes -configuration Debug -derivedDataPath build build`
- **CI/CD**: GitHub Actions on tag push (`v*`), `macos-15` runner, Xcode 16.2, Release config, unsigned
- **Output**: `build/Build/Products/Debug/PrayerTimes.app` (local) or `PrayerTimes.zip` (release)
- **Code signing**: Local = "Sign to Run Locally", CI = disabled (`CODE_SIGN_IDENTITY="-"`)
- **Deployment target**: macOS 14.0
- **Marketing version**: 1.0
- **Widget**: `PrayerTimesWidgetExtension.appex` embedded in app bundle

### Git workflow

```
main (protected)
  ├── feature/hijri-date         → PR #16 (merged)
  ├── feature/calculation-method → PR #17 (merged)
  ├── feature/jumuah-mode        → PR #18 (merged)
  ├── feature/display-icloud-widget → PR #19 (merged)
  └── feature/sunrise-volume-dnd → PR #20 (merged)
```

17 commits, 20 PRs/merges, 15 issues tracked.

### Remaining roadmap
- [ ] Sound picker — multiple adhan recordings (#7)
- [ ] Global keyboard shortcut (#9)
- [ ] Qibla compass (#11)
- [ ] Ramadan mode (#12)
- [ ] iCloud sync — code ready, needs $99/year Apple Developer Account (#14)
