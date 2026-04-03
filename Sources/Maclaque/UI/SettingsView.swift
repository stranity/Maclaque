import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var licenseKeyInput = ""
    @State private var licenseError = false
    @State private var isValidating = false

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

            licenseTab
                .tabItem {
                    Label("Licence", systemImage: "key.fill")
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

    // ── License tab ────────────────────────────────────────────────────
    private var licenseTab: some View {
        VStack(spacing: 16) {
            if appState.isLicensed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("Licence activée")
                    .font(.headline)
                Text("Merci pour votre achat !")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "FF2A1F"))

                Text("Activer Maclaque")
                    .font(.headline)
                Text("\(appState.freeSlapsRemaining) gifles gratuites restantes")
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Clé de licence", text: $licenseKeyInput)
                        .textFieldStyle(.roundedBorder)

                    Button(action: validateLicense) {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Activer")
                        }
                    }
                    .disabled(licenseKeyInput.isEmpty || isValidating)
                }

                if licenseError {
                    Text("Clé invalide. Vérifiez et réessayez.")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Link("Acheter une licence (4,99€)", destination: URL(string: Constants.lemonSqueezyCheckoutURL)!)
                    .font(.caption)
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

    private func validateLicense() {
        isValidating = true
        licenseError = false
        Task {
            let success = await appState.activateLicense(licenseKeyInput)
            await MainActor.run {
                isValidating = false
                licenseError = !success
                if success { licenseKeyInput = "" }
            }
        }
    }
}
