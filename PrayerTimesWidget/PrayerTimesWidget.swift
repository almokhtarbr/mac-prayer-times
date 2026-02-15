import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let prayerName: String
    let prayerTime: Date
    let iqamaTime: Date
    let hijriDate: String
    let allPrayers: [(name: String, time: Date, isNext: Bool)]
}

// MARK: - Timeline Provider

struct PrayerTimesProvider: TimelineProvider {
    private let shared = UserDefaults(suiteName: "group.com.prayertimes.shared")

    func placeholder(in context: Context) -> PrayerWidgetEntry {
        PrayerWidgetEntry(
            date: Date(),
            prayerName: "Dhuhr",
            prayerTime: Date().addingTimeInterval(3600),
            iqamaTime: Date().addingTimeInterval(4500),
            hijriDate: "15 Sha'ban 1447",
            allPrayers: [
                ("Fajr", Date(), false),
                ("Dhuhr", Date().addingTimeInterval(3600), true),
                ("Asr", Date().addingTimeInterval(7200), false),
                ("Maghrib", Date().addingTimeInterval(10800), false),
                ("Isha", Date().addingTimeInterval(14400), false)
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let entry = buildEntry()

        // Refresh every 15 minutes for updated countdown
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func buildEntry() -> PrayerWidgetEntry {
        let name = shared?.string(forKey: "nextPrayerName") ?? "—"
        let timeInterval = shared?.double(forKey: "nextPrayerTime") ?? Date().timeIntervalSince1970
        let iqamaInterval = shared?.double(forKey: "nextIqamaTime") ?? timeInterval
        let hijri = shared?.string(forKey: "hijriDate") ?? ""

        var allPrayers: [(String, Date, Bool)] = []
        if let raw = shared?.array(forKey: "allPrayerTimes") as? [[String: Any]] {
            for dict in raw {
                let n = dict["name"] as? String ?? ""
                let t = dict["time"] as? TimeInterval ?? 0
                let isNext = dict["isNext"] as? Bool ?? false
                allPrayers.append((n, Date(timeIntervalSince1970: t), isNext))
            }
        }

        return PrayerWidgetEntry(
            date: Date(),
            prayerName: name,
            prayerTime: Date(timeIntervalSince1970: timeInterval),
            iqamaTime: Date(timeIntervalSince1970: iqamaInterval),
            hijriDate: hijri,
            allPrayers: allPrayers
        )
    }
}

// MARK: - Small Widget View

struct PrayerWidgetSmallView: View {
    let entry: PrayerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("Next Prayer")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(entry.prayerName)
                .font(.title2)
                .fontWeight(.bold)

            Text(entry.prayerTime, style: .time)
                .font(.callout)
                .monospacedDigit()

            Spacer()

            Text(entry.prayerTime, style: .relative)
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
    }
}

// MARK: - Medium Widget View

struct PrayerWidgetMediumView: View {
    let entry: PrayerWidgetEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Left: next prayer highlight
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.green)
                    Text(entry.prayerName)
                        .font(.title3)
                        .fontWeight(.bold)
                }

                Text(entry.prayerTime, style: .time)
                    .font(.callout)
                    .monospacedDigit()

                Text(entry.prayerTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.green)

                if !entry.hijriDate.isEmpty {
                    Text(entry.hijriDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: all 5 prayers
            if !entry.allPrayers.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.allPrayers, id: \.name) { prayer in
                        HStack {
                            Circle()
                                .fill(prayer.isNext ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text(prayer.name)
                                .font(.caption2)
                                .fontWeight(prayer.isNext ? .bold : .regular)
                                .frame(width: 50, alignment: .leading)
                            Text(Self.timeFormatter.string(from: prayer.time))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundColor(prayer.isNext ? .primary : .secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget Definition

struct PrayerTimesWidget: Widget {
    let kind: String = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimesProvider()) { entry in
            if #available(macOS 14.0, *) {
                PrayerWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PrayerWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Prayer Times")
        .description("Shows the next prayer time with countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PrayerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PrayerWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            PrayerWidgetMediumView(entry: entry)
        default:
            PrayerWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct PrayerTimesWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
    }
}
