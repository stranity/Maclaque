import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCustomPack = false

    private let labelColor = Color.primary.opacity(0.55)
    private let textColor = Color.primary

    var body: some View {
        if showCustomPack {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { withAnimation { showCustomPack = false } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(L10n.back)
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 8)

                CustomPackView()
                    .environmentObject(appState)
            }
            .padding(16)
            .frame(width: 420)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Maclaque")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FF2A1F"))

                Spacer()

                Circle()
                    .fill(appState.isDaemonConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .help(appState.isDaemonConnected ? L10n.daemonConnected : L10n.daemonDisconnected)
            }

            // ON/OFF Toggle
            Toggle(isOn: $appState.isActive) {
                HStack {
                    Image(systemName: appState.isActive ? "hand.raised.fill" : "hand.raised.slash")
                    Text(appState.isActive ? L10n.active : L10n.inactive)
                        .fontWeight(.medium)
                }
            }
            .toggleStyle(.switch)
            .tint(Color(hex: "FF2A1F"))

            Divider()

            // Pack picker
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.soundPack)
                    .font(.caption)
                    .foregroundColor(labelColor)

                PackPickerView()
                    .environmentObject(appState)

                Button(action: { withAnimation { showCustomPack = true } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "FFD60A"))
                        Text(L10n.createCustomPack)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Sensitivity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.sensitivity)
                        .font(.caption)
                        .foregroundColor(labelColor)
                    Spacer()
                    Text("\(Int(appState.sensitivity))")
                        .font(.caption)
                        .foregroundColor(textColor)
                }
                Slider(value: $appState.sensitivity, in: 1...10, step: 1)
                    .tint(Color(hex: "FF2A1F"))
            }

            // Volume slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.volume)
                        .font(.caption)
                        .foregroundColor(labelColor)
                    Spacer()
                    Text("\(Int(appState.masterVolume * 100))%")
                        .font(.caption)
                        .foregroundColor(textColor)
                }
                Slider(value: $appState.masterVolume, in: 0...1)
                    .tint(Color(hex: "FF2A1F"))
            }

            Divider()

            // Trial banner
            if Preferences.shared.tier == "free" {
                if appState.trialExpired {
                    VStack(spacing: 8) {
                        Text(L10n.trialExpiredTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(L10n.trialExpiredMessage)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                        Link(destination: URL(string: "https://maclaque.com")!) {
                            Text(L10n.unlockMaclaque)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "FF2A1F"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "FF2A1F").opacity(0.9))
                    .cornerRadius(10)
                } else {
                    let remaining = Constants.freeSlapsLimit - appState.totalSlaps
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "FFD60A"))
                        Text(L10n.trialRemaining(remaining))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(labelColor)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(hex: "FFD60A").opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Stats
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(Color(hex: "FFD60A"))
                Text(L10n.slapCount(appState.totalSlaps))
                    .font(.caption)
                    .foregroundColor(labelColor)
                Spacer()
            }

            // Charge sound toggle
            Toggle(isOn: $appState.chargeSoundEnabled) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(Color(hex: "FFD60A"))
                    Text(L10n.chargeSound)
                        .font(.caption)
                }
            }
            .toggleStyle(.switch)

            Divider()

            // Footer buttons
            HStack {
                if #available(macOS 14, *) {
                    SettingsLink {
                        Text(L10n.settings)
                            .font(.caption)
                    }
                } else {
                    Button(L10n.settings) {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                    .font(.caption)
                }

                Spacer()

                Button(L10n.quit) {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .foregroundColor(labelColor)
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
