# Prayer Times Mac Menu Bar App — Dev Log

## What Was Built

A free, local, no-BS Mac menu bar app that shows prayer times and plays the full adhan.
No in-app purchases, no subscriptions, no API calls — everything calculated locally using the ISNA method.

## Tech Stack

- **SwiftUI** with `MenuBarExtra` (macOS 13+)
- **adhan-swift** v1.4.0 — open source prayer time calculation (SPM package)
- **AVFoundation** — play full adhan audio
- **CoreLocation** — auto-detect user location
- **UserNotifications** — system notification at prayer time
- **ServiceManagement** — launch at login toggle

## Project Structure

```
mac-prayer-times/
├── PrayerTimes.xcodeproj/
│   └── project.pbxproj              # Xcode project config + SPM dependency
│
└── PrayerTimes/
    ├── PrayerTimesApp.swift          # App entry — MenuBarExtra with moon icon
    ├── Views/
    │   ├── MenuBarView.swift         # Dropdown: 5 prayers, times, countdown
    │   └── SettingsView.swift        # Sound toggle, launch at login, location
    ├── Models/
    │   ├── PrayerManager.swift       # Brain — calculates times, notifications, adhan
    │   └── LocationManager.swift     # GPS wrapper + reverse geocoding
    ├── Services/
    │   └── AdhanPlayer.swift         # AVAudioPlayer wrapper for adhan.mp3
    ├── Resources/
    │   └── cd17c7200df5.mp3          # Adhan audio file
    ├── Assets.xcassets/              # App icons
    ├── Info.plist                    # LSUIElement=YES (menu bar only), location desc
    └── PrayerTimes.entitlements      # Sandbox + location permission
```

## Architecture (Rails Developer Translation)

| Swift Concept | Rails Equivalent |
|---|---|
| `PrayerTimesApp.swift` | `config/routes.rb` + `application.rb` |
| `PrayerManager` | Service object (`PrayerCalculationService`) |
| `LocationManager` | API client (`GoogleMapsClient`) |
| `AdhanPlayer` | `AudioPlayerService` |
| `MenuBarView` | `prayers/index.html.erb` |
| `SettingsView` | `settings/edit.html.erb` |
| `@StateObject` | Instance var that triggers re-renders |
| `@Published` | `after_save :broadcast_to_frontend` |
| `@EnvironmentObject` | `helper_method :current_user` (available in all views) |
| `Combine .sink` | Action Cable subscription |
| SPM (adhan-swift) | `gem 'adhan'` in Gemfile |
| `Info.plist` | `config/application.yml` |
| `Entitlements` | Doorkeeper/permissions config |

## How It Works — The Flow

1. **App launches** → PrayerTimesApp creates PrayerManager
2. **PrayerManager** creates LocationManager + AdhanPlayer internally
3. **Moon icon** appears in menu bar
4. **LocationManager** asks macOS for GPS → user grants permission
5. **GPS returns** coordinates → PrayerManager receives via Combine pub/sub
6. **adhan-swift** does pure astronomy math → returns 5 prayer times
7. **Menu bar** updates to show: `☽ Asr 2h 15m`
8. **Notifications** scheduled for each upcoming prayer
9. **Timer** ticks every 30 seconds:
   - Updates countdown
   - Checks if prayer time arrived → plays adhan
10. **At midnight** → recalculates for new day

## Key Decisions

- **ISNA method** hardcoded (`.northAmerica` in adhan-swift)
- **LSUIElement=YES** — no dock icon, pure menu bar app
- **30-second timer** — balance between accuracy and battery
- **Played-prayer tracking** — Set of `"2026-02-14-Fajr"` strings prevents duplicate plays
- **Sandbox enabled** — ready for App Store if needed
- **No API calls** — adhan-swift calculates from sun position math

## Build Status

- First build: **SUCCEEDED** (xcodebuild, Debug, arm64)
- Adhan audio: added (cd17c7200df5.mp3)
- SPM dependency: adhan-swift 1.4.0 resolved

## What's Next

See polishing plan for improvements.
