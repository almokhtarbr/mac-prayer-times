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
