import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("Général", systemImage: "gear")
                }

            CustomPackView()
                .environmentObject(appState)
                .tabItem {
                    Label("Pack custom", systemImage: "wand.and.stars")
                }

            aboutTab
                .tabItem {
                    Label("À propos", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 520)
    }

    // ── General tab ────────────────────────────────────────────────────
    private var generalTab: some View {
        Form {
            Toggle("Lancer au démarrage", isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { LaunchAtLogin.isEnabled = $0 }
            ))

            Toggle("Son de charge (branchement)", isOn: $appState.chargeSoundEnabled)

            Slider(value: $appState.sensitivity, in: 1...10, step: 1) {
                Text("Sensibilité : \(Int(appState.sensitivity))")
            }

            Slider(value: $appState.cooldown, in: 0.3...2.0, step: 0.1) {
                Text("Cooldown : \(String(format: "%.1f", appState.cooldown))s")
            }

            Slider(value: $appState.masterVolume, in: 0...1) {
                Text("Volume : \(Int(appState.masterVolume * 100))%")
            }
        }
        .padding()
    }

    // ── About tab ──────────────────────────────────────────────────────
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Text("👋")
                .font(.system(size: 64))
            Text("Maclaque")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "FF2A1F"))
            Text(Constants.tagline)
                .foregroundColor(.secondary)
            Text("v\(Constants.version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Gifles totales : \(appState.totalSlaps)")
                .font(.caption)

            Text("100% local. Zéro tracking. RGPD-friendly.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
