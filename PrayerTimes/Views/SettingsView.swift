import SwiftUI
import ServiceManagement
import Adhan

struct SettingsView: View {
    @EnvironmentObject var prayerManager: PrayerManager
    @AppStorage("adhanEnabled") private var adhanEnabled = true
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

            Section("General") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            }

            Section("About") {
                LabeledContent("Method") {
                    Text("ISNA (North America)")
                }
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 520)
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
