import Foundation

/// Persisted user preferences via UserDefaults
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    var isActive: Bool {
        get { defaults.object(forKey: Constants.keyIsActive) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.keyIsActive) }
    }

    var currentPackId: String {
        get { defaults.string(forKey: Constants.keyCurrentPackId) ?? "aie" }
        set { defaults.set(newValue, forKey: Constants.keyCurrentPackId) }
    }

    var sensitivity: Double {
        get { defaults.object(forKey: Constants.keySensitivity) as? Double ?? 5.0 }
        set { defaults.set(newValue, forKey: Constants.keySensitivity) }
    }

    var cooldown: Double {
        get { defaults.object(forKey: Constants.keyCooldown) as? Double ?? 0.5 }
        set { defaults.set(newValue, forKey: Constants.keyCooldown) }
    }

    var masterVolume: Double {
        get { defaults.object(forKey: Constants.keyMasterVolume) as? Double ?? 0.8 }
        set { defaults.set(newValue, forKey: Constants.keyMasterVolume) }
    }

    var totalSlaps: Int {
        get { defaults.integer(forKey: Constants.keyTotalSlaps) }
        set { defaults.set(newValue, forKey: Constants.keyTotalSlaps) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Constants.keyLaunchAtLogin) }
        set { defaults.set(newValue, forKey: Constants.keyLaunchAtLogin) }
    }

    var chargeSoundEnabled: Bool {
        get { defaults.object(forKey: Constants.keyChargeSound) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Constants.keyChargeSound) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Constants.keyHasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Constants.keyHasCompletedOnboarding) }
    }

    /// Unique device identifier (persists across app launches)
    var deviceId: String {
        if let existing = defaults.string(forKey: "maclaque.deviceId") {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: "maclaque.deviceId")
        return newId
    }
}
