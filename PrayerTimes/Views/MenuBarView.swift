import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var prayerManager: PrayerManager

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Divider()
            prayerList

            if let next = prayerManager.nextPrayerEntry {
                Divider()
                countdown(next)
            }

            Divider()
            footer
        }
        .padding()
        .frame(width: 300)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.accentColor)
                Text("Prayer Times")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if !prayerManager.hijriDateString.isEmpty {
                Text(prayerManager.hijriDateString + " AH")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var prayerList: some View {
        VStack(spacing: 4) {
            Text(prayerManager.locationName)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Column headers
            HStack {
                Text("")
                    .frame(width: 8)
                Text("")
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text("Adhan")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Text("Iqama")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }

            ForEach(prayerManager.prayerEntries) { entry in
                HStack {
                    Circle()
                        .fill(entry.isNext ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(entry.name)
                        .fontWeight(entry.isNext ? .semibold : .regular)
                        .frame(width: 60, alignment: .leading)
                    Spacer()
                    Text(Self.timeFormatter.string(from: entry.time))
                        .monospacedDigit()
                        .font(.callout)
                        .frame(width: 70, alignment: .trailing)
                    Text(Self.timeFormatter.string(from: entry.iqamaTime))
                        .monospacedDigit()
                        .font(.callout)
                        .fontWeight(entry.isNext ? .semibold : .regular)
                        .foregroundColor(entry.isNext ? .green : .primary)
                        .frame(width: 70, alignment: .trailing)
                }
                .foregroundColor(entry.isNext ? .primary : .secondary)
                .padding(.vertical, 2)
            }
        }
    }

    private func countdown(_ next: PrayerEntry) -> some View {
        let info = prayerManager.countdownInfo(for: next)
        return HStack {
            Image(systemName: "clock")
                .foregroundColor(.green)
            Text("\(info.label) in \(info.time)")
                .font(.callout)
                .fontWeight(.medium)
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings...") {
                SettingsWindowController.shared.open(prayerManager: prayerManager)
            }

            Spacer()

            if prayerManager.adhanPlayer.isPlaying {
                Button("Stop Adhan") {
                    prayerManager.adhanPlayer.stop()
                }
                .foregroundColor(.red)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
