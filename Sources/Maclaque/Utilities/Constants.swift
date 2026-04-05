import Foundation

enum Constants {
    static let appName = "Maclaque"
    static let tagline = "Il te répond en français."
    static let version = "1.0.0"

    static let socketPath = "/var/run/maclaque.sock"
    static let daemonLabel = "com.maclaque.daemon"

    // Trial
    static let maxFreeSlaps = 5

    // Defaults keys
    static let keyIsActive = "maclaque.isActive"
    static let keyCurrentPackId = "maclaque.currentPackId"
    static let keySensitivity = "maclaque.sensitivity"
    static let keyCooldown = "maclaque.cooldown"
    static let keyMasterVolume = "maclaque.masterVolume"
    static let keyTotalSlaps = "maclaque.totalSlaps"
    static let keyFreeSlapsRemaining = "maclaque.freeSlapsRemaining"
    static let keyLaunchAtLogin = "maclaque.launchAtLogin"
    static let keyChargeSound = "maclaque.chargeSound"
    static let keyHasCompletedOnboarding = "maclaque.hasCompletedOnboarding"

    // Proxy
    static let proxyBaseURL = "https://maclaque-proxy.melbeherec.workers.dev"

    // LemonSqueezy
    static let lemonSqueezyCheckoutURL = "https://maclaque.lemonsqueezy.com/checkout/buy/651fea4d-9ce5-4478-a1fa-09f054b8556b"
    static let lemonSqueezyValidateURL = "https://api.lemonsqueezy.com/v1/licenses/validate"
}
