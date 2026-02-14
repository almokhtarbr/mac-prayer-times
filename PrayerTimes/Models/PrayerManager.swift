import Foundation
import Combine
import UserNotifications
import Adhan

struct PrayerEntry: Identifiable {
    let id: String
    let name: String
    let time: Date
    let iqamaTime: Date
    let isNext: Bool
}

enum CalculationMethodOption: String, CaseIterable, Identifiable {
    case northAmerica = "ISNA (North America)"
    case muslimWorldLeague = "Muslim World League"
    case egyptian = "Egyptian"
    case ummAlQura = "Umm al-Qura (Saudi)"
    case dubai = "Dubai"
    case karachi = "Karachi"
    case kuwait = "Kuwait"
    case qatar = "Qatar"
    case singapore = "Singapore"
    case tehran = "Tehran"
    case turkey = "Turkey"

    var id: String { rawValue }

    var calculationParameters: CalculationParameters {
        switch self {
        case .northAmerica: return CalculationMethod.northAmerica.params
        case .muslimWorldLeague: return CalculationMethod.muslimWorldLeague.params
        case .egyptian: return CalculationMethod.egyptian.params
        case .ummAlQura: return CalculationMethod.ummAlQura.params
        case .dubai: return CalculationMethod.dubai.params
        case .karachi: return CalculationMethod.karachi.params
        case .kuwait: return CalculationMethod.kuwait.params
        case .qatar: return CalculationMethod.qatar.params
        case .singapore: return CalculationMethod.singapore.params
        case .tehran: return CalculationMethod.tehran.params
        case .turkey: return CalculationMethod.turkey.params
        }
    }
}

class PrayerManager: ObservableObject {
    @Published var prayerEntries: [PrayerEntry] = []
    @Published var nextPrayerEntry: PrayerEntry?
    @Published var menuBarText: String = ""
    @Published var hijriDateString: String = ""

    let locationManager = LocationManager()
    let adhanPlayer = AdhanPlayer()

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var playedPrayers: Set<String> = []
    private var currentDateKey: String = ""

    static let displayPrayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    static let prayerNames: [Prayer: String] = [
        .fajr: "Fajr",
        .sunrise: "Sunrise",
        .dhuhr: "Dhuhr",
        .asr: "Asr",
        .maghrib: "Maghrib",
        .isha: "Isha"
    ]

    // UserDefaults keys for iqama offsets (minutes after adhan)
    static let iqamaKeys: [Prayer: String] = [
        .fajr: "iqamaFajr",
        .dhuhr: "iqamaDhuhr",
        .asr: "iqamaAsr",
        .maghrib: "iqamaMaghrib",
        .isha: "iqamaIsha"
    ]

    // Default iqama offsets in minutes
    static let defaultIqamaOffsets: [Prayer: Int] = [
        .fajr: 20,
        .dhuhr: 15,
        .asr: 10,
        .maghrib: 5,
        .isha: 15
    ]

    var locationName: String {
        locationManager.locationName
    }

    func iqamaOffset(for prayer: Prayer) -> Int {
        let key = Self.iqamaKeys[prayer] ?? ""
        return UserDefaults.standard.integer(forKey: key)
    }

    func setIqamaOffset(for prayer: Prayer, minutes: Int) {
        let key = Self.iqamaKeys[prayer] ?? ""
        UserDefaults.standard.set(minutes, forKey: key)
        // Recalculate to reflect new offsets
        if let location = locationManager.location {
            calculateTimes(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }

    init() {
        // Register defaults: adhan enabled + iqama offsets
        var defaults: [String: Any] = ["adhanEnabled": true]
        for (prayer, offset) in Self.defaultIqamaOffsets {
            if let key = Self.iqamaKeys[prayer] {
                defaults[key] = offset
            }
        }
        UserDefaults.standard.register(defaults: defaults)

        requestNotificationPermission()

        locationManager.$location
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                self?.calculateTimes(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
            .store(in: &cancellables)

        locationManager.$locationName
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        locationManager.requestLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var selectedMethod: CalculationMethodOption {
        let raw = UserDefaults.standard.string(forKey: "calculationMethod") ?? CalculationMethodOption.northAmerica.rawValue
        return CalculationMethodOption(rawValue: raw) ?? .northAmerica
    }

    func setCalculationMethod(_ method: CalculationMethodOption) {
        UserDefaults.standard.set(method.rawValue, forKey: "calculationMethod")
        if let location = locationManager.location {
            calculateTimes(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    func calculateTimes(latitude: Double, longitude: Double) {
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        let params = selectedMethod.calculationParameters
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day], from: now)

        guard let times = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: params) else {
            return
        }

        var next = times.nextPrayer(at: now)
        if next == .sunrise { next = .dhuhr }

        // Check if all prayers (including iqama) have passed — need tomorrow's Fajr
        var allPassed = false
        if next == nil {
            // After Isha iqama, show tomorrow's Fajr as next
            let ishaTime = times.time(for: .isha)
            let ishaIqama = ishaTime.addingTimeInterval(Double(iqamaOffset(for: .isha)) * 60)
            if now > ishaIqama {
                allPassed = true
            }
        }

        var entries: [PrayerEntry] = []
        for prayer in Self.displayPrayers {
            let adhanTime = times.time(for: prayer)
            let offset = iqamaOffset(for: prayer)
            let iqamaTime = adhanTime.addingTimeInterval(Double(offset) * 60)

            entries.append(PrayerEntry(
                id: Self.prayerNames[prayer]!,
                name: Self.prayerNames[prayer]!,
                time: adhanTime,
                iqamaTime: iqamaTime,
                isNext: prayer == next
            ))
        }

        prayerEntries = entries
        nextPrayerEntry = entries.first(where: { $0.isNext })

        // If all today's prayers passed, compute tomorrow's Fajr
        if allPassed || nextPrayerEntry == nil {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
            let tomorrowComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
            if let tomorrowTimes = PrayerTimes(coordinates: coordinates, date: tomorrowComponents, calculationParameters: params) {
                let fajrTime = tomorrowTimes.time(for: .fajr)
                let fajrIqama = fajrTime.addingTimeInterval(Double(iqamaOffset(for: .fajr)) * 60)
                nextPrayerEntry = PrayerEntry(
                    id: "Fajr",
                    name: "Fajr",
                    time: fajrTime,
                    iqamaTime: fajrIqama,
                    isNext: true
                )
            }
        }

        updateHijriDate()
        updateMenuBarText()
        scheduleNotifications(entries: entries)
        resetPlayedIfNewDay()
        checkForAdhan()
    }

    private func tick() {
        guard let location = locationManager.location else { return }
        calculateTimes(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    private static let hijriFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    private func updateHijriDate() {
        hijriDateString = Self.hijriFormatter.string(from: Date())
    }

    private func updateMenuBarText() {
        guard let next = nextPrayerEntry else {
            menuBarText = ""
            return
        }

        let remaining = next.time.timeIntervalSince(Date())
        guard remaining > 0 else {
            menuBarText = next.name
            return
        }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            menuBarText = "\(next.name) \(hours)h \(minutes)m"
        } else {
            menuBarText = "\(next.name) \(minutes)m"
        }
    }

    private func checkForAdhan() {
        let enabled = UserDefaults.standard.bool(forKey: "adhanEnabled")
        guard enabled else { return }

        let now = Date()
        for entry in prayerEntries {
            let diff = abs(now.timeIntervalSince(entry.time))
            if diff < 45 {
                let key = "\(currentDateKey)-\(entry.id)"
                if !playedPrayers.contains(key) {
                    playedPrayers.insert(key)
                    adhanPlayer.play()
                }
            }
        }
    }

    private func resetPlayedIfNewDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        if today != currentDateKey {
            currentDateKey = today
            playedPrayers.removeAll()
        }
    }

    private func scheduleNotifications(entries: [PrayerEntry]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let now = Date()
        for entry in entries {
            // Notification at adhan time
            if entry.time > now {
                let content = UNMutableNotificationContent()
                content.title = entry.name
                content.body = "It's time for \(entry.name) prayer"
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents(
                    [.hour, .minute, .second], from: entry.time
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerDate, repeats: false
                )
                center.add(UNNotificationRequest(
                    identifier: "adhan-\(entry.id)",
                    content: content,
                    trigger: trigger
                ))
            }

            // Notification at iqama time
            if entry.iqamaTime > now {
                let content = UNMutableNotificationContent()
                content.title = "\(entry.name) Iqama"
                content.body = "Iqama for \(entry.name) — prayer is starting"
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents(
                    [.hour, .minute, .second], from: entry.iqamaTime
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: triggerDate, repeats: false
                )
                center.add(UNNotificationRequest(
                    identifier: "iqama-\(entry.id)",
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }

    /// Returns (label, timeString) — e.g. ("Dhuhr", "1h 20m") or ("Dhuhr iqama", "12m")
    func countdownInfo(for entry: PrayerEntry) -> (label: String, time: String) {
        let now = Date()
        let toAdhan = entry.time.timeIntervalSince(now)

        if toAdhan > 0 {
            return (entry.name, formatInterval(toAdhan))
        }

        // Adhan has passed — check iqama
        let toIqama = entry.iqamaTime.timeIntervalSince(now)
        if toIqama > 0 {
            return ("\(entry.name) iqama", formatInterval(toIqama))
        }

        return (entry.name, "Now")
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
