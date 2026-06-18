import Foundation

/// Supported app languages
enum AppLanguage: String, CaseIterable {
    case fr
    case en

    var displayName: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        }
    }
}

/// Dictionary-based localization — reads language from Preferences.shared.language
enum L10n {
    private static var lang: AppLanguage {
        AppLanguage(rawValue: Preferences.shared.language) ?? .fr
    }

    private static func t(_ fr: String, _ en: String) -> String {
        lang == .fr ? fr : en
    }

    // ── Constants / App-level ──────────────────────────────────────────
    static var tagline: String { t("Il te répond en français.", "It talks back. In French.") }

    // ── MenuBarView ────────────────────────────────────────────────────
    static var daemonConnected: String { t("Daemon connecté", "Daemon connected") }
    static var daemonDisconnected: String { t("Daemon déconnecté", "Daemon disconnected") }
    static var active: String { t("Actif", "Active") }
    static var inactive: String { t("Inactif", "Inactive") }
    static var soundPack: String { t("Pack de sons", "Sound pack") }
    static var createCustomPack: String { t("Créer un pack personnalisé", "Create a custom pack") }
    static var sensitivity: String { t("Sensibilité", "Sensitivity") }
    static var volume: String { t("Volume", "Volume") }
    static func slapCount(_ n: Int) -> String { t("\(n) gifles", "\(n) slaps") }
    static var chargeSound: String { t("Son de charge", "Charge sound") }
    static var settings: String { t("Paramètres...", "Settings...") }
    static var quit: String { t("Quitter", "Quit") }
    static var back: String { t("Retour", "Back") }

    // ── Trial ──────────────────────────────────────────────────────────
    static var trialExpiredTitle: String { t("Essai terminé !", "Trial over!") }
    static var trialExpiredMessage: String {
        t("Tu as utilisé tes \(Constants.freeSlapsLimit) claques gratuites.\nDébloque Maclaque pour continuer à gifler.",
          "You've used your \(Constants.freeSlapsLimit) free slaps.\nUnlock Maclaque to keep slapping.")
    }
    static var unlockMaclaque: String { t("Débloquer Maclaque", "Unlock Maclaque") }
    static var customPackLocked: String { t("Fonctionnalité payante", "Premium feature") }
    static var customPackLockedMessage: String {
        t("Les packs custom et le clonage de voix sont disponibles avec Maclaque Basic ou Plus.",
          "Custom packs and voice cloning are available with Maclaque Basic or Plus.")
    }
    static func trialRemaining(_ n: Int) -> String {
        t("Essai gratuit : \(n) claques restantes", "Free trial: \(n) slaps remaining")
    }

    // ── SettingsView ───────────────────────────────────────────────────
    static var tabGeneral: String { t("Général", "General") }
    static var tabCustomPack: String { t("Pack custom", "Custom pack") }
    static var tabAbout: String { t("À propos", "About") }
    static var launchAtStartup: String { t("Lancer au démarrage", "Launch at startup") }
    static var chargeSoundToggle: String { t("Son de charge (branchement)", "Charge sound (plug-in)") }
    static func sensitivityLabel(_ val: Int) -> String { t("Sensibilité : \(val)", "Sensitivity: \(val)") }
    static func cooldownLabel(_ val: String) -> String { t("Cooldown : \(val)s", "Cooldown: \(val)s") }
    static func volumeLabel(_ val: Int) -> String { t("Volume : \(val)%", "Volume: \(val)%") }
    static func totalSlaps(_ n: Int) -> String { t("Gifles totales : \(n)", "Total slaps: \(n)") }
    static var privacyNote: String { t("100% local. Zéro tracking. RGPD-friendly.", "100% local. Zero tracking. GDPR-friendly.") }
    static var language: String { t("Langue", "Language") }

    // ── OnboardingView ─────────────────────────────────────────────────
    static var slapYourMac: String { t("Gifle ton Mac.", "Slap your Mac.") }
    static var onboardingDescription: String {
        t("Ton MacBook a un accéléromètre secret.\nMaclaque le transforme en punching bag vocal.",
          "Your MacBook has a hidden accelerometer.\nMaclaque turns it into a vocal punching bag.")
    }
    static var start: String { t("Commencer", "Get started") }
    static var daemonInstallTitle: String { t("Installation du daemon", "Daemon installation") }
    static var daemonInstallDescription: String {
        t("Maclaque a besoin d'un petit composant\npour lire l'accéléromètre de ton Mac.\nTon mot de passe sera demandé une seule fois.",
          "Maclaque needs a small helper component\nto read your Mac's accelerometer.\nYour password will only be asked once.")
    }
    static var daemonInstalledConnected: String { t("Daemon installé et connecté !", "Daemon installed and connected!") }
    static var daemonInstalledConnecting: String { t("Daemon installé, connexion en cours...", "Daemon installed, connecting...") }
    static var install: String { t("Installer", "Install") }
    static var installing: String { t("Installation...", "Installing...") }
    static var infoSigned: String { t("Composant vérifié et signé par Maclaque", "Component verified and signed by Maclaque") }
    static var infoAutoStart: String { t("Se lance automatiquement au démarrage", "Launches automatically at startup") }
    static var infoUninstall: String { t("Désinstallable à tout moment depuis les Paramètres", "Can be uninstalled anytime from Settings") }
    static var continueButton: String { t("Continuer", "Continue") }
    static var skipForNow: String { t("Passer pour l'instant", "Skip for now") }
    static var letsGo: String { t("C'est parti !", "Let's go!") }
    static var onboardingReady: String {
        t("Maclaque est prêt.\nGifle ton Mac et profite !",
          "Maclaque is ready.\nSlap your Mac and enjoy!")
    }
    static var menuBarHint: String {
        t("Maclaque vit dans ta barre de menu\nen haut à droite de l'écran.",
          "Maclaque lives in your menu bar\nat the top-right of your screen.")
    }

    // ── CustomPackView ─────────────────────────────────────────────────
    static var createYourPack: String { t("Crée ton pack", "Create your pack") }
    static func packLimitDescription(maxPacks: Int) -> String {
        t("Max \(maxPacks) packs, 5 sons de gifle + événements. Générations illimitées.",
          "Max \(maxPacks) packs, 5 slap sounds + events. Unlimited generations.")
    }
    static var packName: String { t("Nom du pack", "Pack name") }
    static var voice: String { t("Voix", "Voice") }
    static var cloneAVoice: String { t("Cloner une voix", "Clone a voice") }
    static var activateMaclaquePlus: String { t("Activer Maclaque+", "Activate Maclaque+") }

    // Slaps section
    static var slaps: String { t("Gifles", "Slaps") }
    static var slapPlaceholder: String { t("Ex: Aïe ! Mais arrête !", "e.g. Ouch! Stop that!") }
    static var add: String { t("Ajouter", "Add") }

    // Events section
    static var plugIn: String { t("Branchement", "Plug in") }
    static var plugInPlaceholder: String { t("Ex: Mmh enfin du jus !", "e.g. Mmh, finally some juice!") }
    static var unplug: String { t("Débranchement", "Unplug") }
    static var unplugPlaceholder: String { t("Ex: Hé ! Remets ça !", "e.g. Hey! Plug me back in!") }
    static var lidOpen: String { t("Ouverture couvercle", "Lid open") }
    static var lidOpenPlaceholder: String { t("Ex: Ah te revoilà !", "e.g. Oh, you're back!") }
    static var lidClose: String { t("Fermeture couvercle", "Lid close") }
    static var lidClosePlaceholder: String { t("Ex: Non ! Me laisse pas !", "e.g. No! Don't leave me!") }

    // Generate section
    static func generatingProgress(_ current: Int, _ total: Int) -> String {
        t("Génération \(current)/\(total)...", "Generating \(current)/\(total)...")
    }
    static func generatePack(_ count: Int) -> String {
        t("Générer le pack (\(count) sons)", "Generate pack (\(count) sounds)")
    }

    // Voice clone sheet
    static var cloneAVoiceTitle: String { t("Cloner une voix", "Clone a voice") }
    static func cloneDescription(used: Int, max: Int) -> String {
        t("Importe un MP3 d'au moins 30 secondes de voix.\n\(used)/\(max) voix utilisées.",
          "Import an MP3 with at least 30 seconds of voice.\n\(used)/\(max) voices used.")
    }
    static var voiceNamePlaceholder: String { t("Nom de la voix (ex: Papa, Kylian...)", "Voice name (e.g. Dad, Kylian...)") }
    static var cloningInProgress: String { t("Clonage en cours...", "Cloning in progress...") }
    static var chooseMP3: String { t("Choisir un fichier MP3", "Choose an MP3 file") }
    static var yourClonedVoices: String { t("Tes voix clonées", "Your cloned voices") }
    static var close: String { t("Fermer", "Close") }
    static func voiceCloned(_ name: String) -> String {
        t("Voix \"\(name)\" clonée !", "Voice \"\(name)\" cloned!")
    }

    // Activation sheet
    static var maclaquePlusFeatures: String {
        t("10 voix clonées • 10 packs custom\nGénérations illimitées",
          "10 cloned voices • 10 custom packs\nUnlimited generations")
    }
    static var activationCode: String { t("Code d'activation", "Activation code") }
    static var activating: String { t("Activation...", "Activating...") }
    static var activate: String { t("Activer", "Activate") }
    static var maclaquePlusActivated: String { t("Maclaque+ activé !", "Maclaque+ activated!") }

    // Pack generation messages
    static func maxPacksReached(_ max: Int) -> String {
        t("Maximum \(max) packs custom. Supprime-en un pour en créer un nouveau.",
          "Maximum \(max) custom packs. Delete one to create a new one.")
    }
    static func packCreated(name: String, count: Int) -> String {
        t("Pack \"\(name)\" créé avec \(count) sons !",
          "Pack \"\(name)\" created with \(count) sounds!")
    }

    // File picker
    static var chooseAudioFile: String { t("Choisis un fichier audio", "Choose an audio file") }

    // ── VoiceCloneService errors ───────────────────────────────────────
    static var errorCloneLimitReached: String {
        t("Tu as atteint la limite de voix clonées.",
          "You've reached the cloned voice limit.")
    }
    static var errorNeedsUpgrade: String {
        t("Passe à Maclaque+ pour cloner plus de voix.",
          "Upgrade to Maclaque+ to clone more voices.")
    }
    static func errorApi(_ code: Int, _ msg: String) -> String {
        t("Erreur \(code): \(msg)", "Error \(code): \(msg)")
    }
    static func errorNetwork(_ msg: String) -> String {
        t("Erreur réseau: \(msg)", "Network error: \(msg)")
    }
    static func errorActivation(_ msg: String) -> String {
        t("Activation échouée: \(msg)", "Activation failed: \(msg)")
    }
}
