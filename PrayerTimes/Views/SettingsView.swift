import SwiftUI
import ServiceManagement
import Adhan

struct SettingsView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @AppStorage("adhanEnabled") private var adhanEnabled = true
    @AppStorage("adhanVolume") private var adhanVolume: Double = 0.8
    @AppStorage("calculationMethod") private var calculationMethodRaw = CalculationMethodOption.northAmerica.rawValue
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayRaw = MenuBarDisplayMode.nameAndCountdown.rawValue
    @AppStorage("dndEnabled") private var dndEnabled = false
    @AppStorage("dndStart") private var dndStartMinutes: Int = 1380  // 23:00
    @AppStorage("dndEnd") private var dndEndMinutes: Int = 420       // 07:00
    @State private var launchAtLogin = false

    // Iqama offsets (minutes after adhan)
    @AppStorage("iqamaFajr") private var iqamaFajr = 20
    @AppStorage("iqamaDhuhr") private var iqamaDhuhr = 15
    @AppStorage("iqamaAsr") private var iqamaAsr = 10
    @AppStorage("iqamaMaghrib") private var iqamaMaghrib = 5
    @AppStorage("iqamaIsha") private var iqamaIsha = 15

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play Adhan at prayer time", isOn: $adhanEnabled)

                if adhanEnabled {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Slider(value: $adhanVolume, in: 0...1, step: 0.05)
                            .onChange(of: adhanVolume) { newValue in
                                prayerManager.adhanPlayer.volume = Float(newValue)
                            }
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(Int(adhanVolume * 100))%")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 36, alignment: .trailing)
                    }

                    Button("Preview") {
                        prayerManager.adhanPlayer.play()
                    }
                }
            }

            Section {
                Toggle("Quiet Hours", isOn: $dndEnabled)
                if dndEnabled {
                    HStack {
                        Text("From")
                        Picker("", selection: $dndStartMinutes) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour * 60)
                            }
                        }
                        .frame(width: 90)
                        Text("to")
                        Picker("", selection: $dndEndMinutes) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour * 60)
                            }
                        }
                        .frame(width: 90)
                    }
                }
            } header: {
                Text("Do Not Disturb")
            } footer: {
                Text("Mute adhan sound during quiet hours. Notifications still appear.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                iqamaRow("Fajr", value: $iqamaFajr, prayer: .fajr)
                iqamaRow("Dhuhr", value: $iqamaDhuhr, prayer: .dhuhr)
                iqamaRow("Asr", value: $iqamaAsr, prayer: .asr)
                iqamaRow("Maghrib", value: $iqamaMaghrib, prayer: .maghrib)
                iqamaRow("Isha", value: $iqamaIsha, prayer: .isha)
            } header: {
                Text("Iqama Offsets")
            } footer: {
                Text("Minutes after adhan when iqama (congregation) starts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Location") {
                LabeledContent("Current Location") {
                    Text(prayerManager.locationName)
                }
                Button("Refresh Location") {
                    prayerManager.locationManager.requestLocation()
                }
            }

            Section("Menu Bar") {
                Picker("Display", selection: $menuBarDisplayRaw) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
            }

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("Calculation Method") {
                Picker("Method", selection: $calculationMethodRaw) {
                    ForEach(CalculationMethodOption.allCases) { method in
                        Text(method.rawValue).tag(method.rawValue)
                    }
                }
                .onChange(of: calculationMethodRaw) { newValue in
                    if let method = CalculationMethodOption(rawValue: newValue) {
                        prayerManager.setCalculationMethod(method)
                    }
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 700)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func iqamaRow(_ name: String, value: Binding<Int>, prayer: Prayer) -> some View {
        HStack {
            Text(name)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Stepper(
                "\(value.wrappedValue) min",
                value: value,
                in: 0...60,
                step: 5
            )
            .onChange(of: value.wrappedValue) { newValue in
                prayerManager.setIqamaOffset(for: prayer, minutes: newValue)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
            launchAtLogin = !enable
        }
    }
}
