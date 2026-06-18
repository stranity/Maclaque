import Foundation

enum Constants {
    static let appName = "Maclaque"
    static let tagline = "Il te répond en français."
    static let version = "1.0.0"

    static let socketPath = "/var/run/maclaque.sock"
    static let daemonLabel = "com.maclaque.daemon"

    // Defaults keys
    static let keyIsActive = "maclaque.isActive"
    static let keyCurrentPackId = "maclaque.currentPackId"
    static let keySensitivity = "maclaque.sensitivity"
    static let keyCooldown = "maclaque.cooldown"
    static let keyMasterVolume = "maclaque.masterVolume"
    static let keyTotalSlaps = "maclaque.totalSlaps"
    static let keyLaunchAtLogin = "maclaque.launchAtLogin"
    static let keyChargeSound = "maclaque.chargeSound"
    static let keyHasCompletedOnboarding = "maclaque.hasCompletedOnboarding"

    // Proxy (ElevenLabs TTS)
    static let proxyBaseURL = "https://maclaque-proxy.melbeherec.workers.dev"
    static let proxyAppSecret = "mcq-2026-prod-s3cr3t"

    // Trial
    static let freeSlapsLimit = 10

    // Custom voices
    static let keyCustomVoices = "maclaque.customVoices"
    static let keyTier = "maclaque.tier"
    static let keyActivationCode = "maclaque.activationCode"
}
