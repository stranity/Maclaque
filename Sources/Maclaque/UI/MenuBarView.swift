import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Maclaque")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FF2A1F"))

                Spacer()

                // Daemon status indicator
                Circle()
                    .fill(appState.isDaemonConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .help(appState.isDaemonConnected ? "Daemon connecté" : "Daemon déconnecté")
            }

            // ON/OFF Toggle
            Toggle(isOn: $appState.isActive) {
                HStack {
                    Image(systemName: appState.isActive ? "hand.raised.fill" : "hand.raised.slash")
                    Text(appState.isActive ? "Actif" : "Inactif")
                        .fontWeight(.medium)
                }
            }
            .toggleStyle(.switch)
            .tint(Color(hex: "FF2A1F"))

            Divider()

            // Pack picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Pack de sons")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8888AA"))

                PackPickerView()
                    .environmentObject(appState)
            }

            Divider()

            // Sensitivity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensibilité")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8888AA"))
                    Spacer()
                    Text("\(Int(appState.sensitivity))")
                        .font(.caption)
                        .foregroundColor(Color(hex: "F0F0F5"))
                }
                Slider(value: $appState.sensitivity, in: 1...10, step: 1)
                    .tint(Color(hex: "FF2A1F"))
            }

            // Volume slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Volume")
                        .font(.caption)
                        .foregroundColor(Color(hex: "8888AA"))
                    Spacer()
                    Text("\(Int(appState.masterVolume * 100))%")
                        .font(.caption)
                        .foregroundColor(Color(hex: "F0F0F5"))
                }
                Slider(value: $appState.masterVolume, in: 0...1)
                    .tint(Color(hex: "FF2A1F"))
            }

            Divider()

            // Stats & actions
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(Color(hex: "FFD60A"))
                Text("\(appState.totalSlaps) gifles")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8888AA"))
                Spacer()

                if !appState.isLicensed {
                    Text("\(appState.freeSlapsRemaining) essais restants")
                        .font(.caption)
                        .foregroundColor(Color(hex: "FF5A54"))
                }
            }

            // Charge sound toggle
            Toggle(isOn: $appState.chargeSoundEnabled) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color(hex: "FFD60A"))
                    Text("Son de charge")
                        .font(.caption)
                }
            }
            .toggleStyle(.switch)

            Divider()

            // Footer buttons
            HStack {
                if #available(macOS 14, *) {
                    SettingsLink {
                        Text("Paramètres...")
                            .font(.caption)
                    }
                } else {
                    Button("Paramètres...") {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                    .font(.caption)
                }

                Spacer()

                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .foregroundColor(Color(hex: "8888AA"))
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

// ── Color hex extension ────────────────────────────────────────────────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
