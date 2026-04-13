import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var licenseKeyInput = ""
    @State private var isValidating = false
    @State private var licenseError = false
    @State private var isInstalling = false
    @State private var installError: String?
    @Environment(\.dismiss) private var dismiss

    private let primaryColor = Color(hex: "FF2A1F")
    private let bgColor = Color(hex: "0D0D17")
    private let surfaceColor = Color(hex: "16162A")
    private let textHigh = Color(hex: "F0F0F5")
    private let textLow = Color(hex: "8888AA")
    private let accentColor = Color(hex: "FFD60A")

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index <= currentStep ? primaryColor : Color(hex: "2A2A42"))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 24)

                Spacer()

                // Content
                switch currentStep {
                case 0: welcomeStep
                case 1: permissionsStep
                case 2: activateStep
                default: EmptyView()
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 560)
    }

    // ── Step 1: Welcome ────────────────────────────────────────────────
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Text("👋")
                .font(.system(size: 80))
                .shadow(color: primaryColor.opacity(0.5), radius: 20)

            Text("Gifle ton Mac.")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(textHigh)

            Text(Constants.tagline)
                .font(.system(size: 18))
                .foregroundColor(textLow)

            Text("Ton MacBook a un accéléromètre secret.\nMaclaque le transforme en punching bag vocal.")
                .font(.system(size: 14))
                .foregroundColor(textLow)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { withAnimation { currentStep = 1 } }) {
                Text("Commencer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
                    .background(primaryColor)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Step 2: Permissions ────────────────────────────────────────────
    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(accentColor)

            Text("Installation du daemon")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(textHigh)

            Text("Maclaque a besoin d'un petit composant\npour lire l'accéléromètre de ton Mac.\nTon mot de passe sera demandé une seule fois.")
                .font(.system(size: 13))
                .foregroundColor(textLow)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Install button or status
            if appState.isDaemonConnected {
                // Already connected
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Daemon installé et connecté !")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.vertical, 8)
            } else if DaemonInstaller.isInstalled {
                // Installed but not connected yet
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Daemon installé, connexion en cours...")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 8)
            } else {
                // Not installed — show install button
                Button(action: installDaemon) {
                    HStack(spacing: 8) {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(isInstalling ? "Installation..." : "Installer")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 12)
                    .background(accentColor.opacity(isInstalling ? 0.5 : 1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)
            }

            // Error message
            if let error = installError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // What this does
            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "shield.checkmark", text: "Composant vérifié et signé par Maclaque")
                infoRow(icon: "bolt.fill", text: "Se lance automatiquement au démarrage")
                infoRow(icon: "trash", text: "Désinstallable à tout moment depuis les Paramètres")
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Button(action: { withAnimation { currentStep = 2 } }) {
                Text(appState.isDaemonConnected ? "Continuer" : "Passer pour l'instant")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 10)
                    .background(appState.isDaemonConnected ? primaryColor : Color(hex: "2A2A42"))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Step 3: Activate ───────────────────────────────────────────────
    private var activateStep: some View {
        VStack(spacing: 20) {
            Text("🎉")
                .font(.system(size: 64))

            Text(appState.isLicensed ? "C'est parti !" : "\(Constants.maxFreeSlaps) gifles offertes !")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(textHigh)

            Text(appState.isLicensed
                 ? "Maclaque est activé. Giflez sans limite."
                 : "Essaie Maclaque maintenant.\nSi t'aimes, c'est 4,99€ pour la vie.")
                .font(.system(size: 14))
                .foregroundColor(textLow)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Image(systemName: "menubar.arrow.up.rectangle")
                    .foregroundColor(accentColor)
                    .font(.system(size: 16))
                Text("Maclaque vit dans ta barre de menu\nen haut à droite de l'écran.")
                    .font(.system(size: 12))
                    .foregroundColor(textLow)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            if !appState.isLicensed {
                Link(destination: URL(string: Constants.lemonSqueezyCheckoutURL)!) {
                    Text("Acheter 4,99€")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                        .background(accentColor)
                        .cornerRadius(12)
                }

                HStack {
                    TextField("Ou entrer une clé de licence", text: $licenseKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)

                    Button("Activer") {
                        validateLicense()
                    }
                    .disabled(licenseKeyInput.isEmpty || isValidating)
                }
                .padding(.horizontal, 40)

                if licenseError {
                    Text("Clé invalide")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Button(action: finishOnboarding) {
                Text(appState.isLicensed ? "Commencer" : "Essayer gratuitement")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 10)
                    .background(primaryColor)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(textLow)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(textLow)
        }
    }

    private func installDaemon() {
        isInstalling = true
        installError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let error = DaemonInstaller.install()
            DispatchQueue.main.async {
                isInstalling = false
                installError = error
                if error == nil {
                    // Reconnect to the daemon
                    appState.connectToDaemon()
                }
            }
        }
    }

    private func validateLicense() {
        isValidating = true
        licenseError = false
        Task {
            let success = await appState.activateLicense(licenseKeyInput)
            await MainActor.run {
                isValidating = false
                licenseError = !success
            }
        }
    }

    private func finishOnboarding() {
        appState.hasCompletedOnboarding = true
        dismiss()
    }
}
