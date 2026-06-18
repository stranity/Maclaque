import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLanguage: AppLanguage = AppLanguage(rawValue: Preferences.shared.language) ?? .fr

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(L10n.tabGeneral, systemImage: "gear")
                }

            CustomPackView()
                .environmentObject(appState)
                .tabItem {
                    Label(L10n.tabCustomPack, systemImage: "wand.and.stars")
                }

            aboutTab
                .tabItem {
                    Label(L10n.tabAbout, systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 520)
    }

    // ── General tab ────────────────────────────────────────────────────
    private var generalTab: some View {
        Form {
            // Language picker
            Picker(L10n.language, selection: $selectedLanguage) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .onChange(of: selectedLanguage) { newValue in
                Preferences.shared.language = newValue.rawValue
            }

            Toggle(L10n.launchAtStartup, isOn: Binding(
                get: { LaunchAtLogin.isEnabled },
                set: { LaunchAtLogin.isEnabled = $0 }
            ))

            Toggle(L10n.chargeSoundToggle, isOn: $appState.chargeSoundEnabled)

            Slider(value: $appState.sensitivity, in: 1...10, step: 1) {
                Text(L10n.sensitivityLabel(Int(appState.sensitivity)))
            }

            Slider(value: $appState.cooldown, in: 0.3...2.0, step: 0.1) {
                Text(L10n.cooldownLabel(String(format: "%.1f", appState.cooldown)))
            }

            Slider(value: $appState.masterVolume, in: 0...1) {
                Text(L10n.volumeLabel(Int(appState.masterVolume * 100)))
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
            Text(L10n.tagline)
                .foregroundColor(.secondary)
            Text("v\(Constants.version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text(L10n.totalSlaps(appState.totalSlaps))
                .font(.caption)

            Text(L10n.privacyNote)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
