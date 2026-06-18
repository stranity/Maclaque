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

    var language: String {
        get { defaults.string(forKey: "maclaque.language") ?? "fr" }
        set { defaults.set(newValue, forKey: "maclaque.language") }
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

    /// Current tier: "basic" or "plus"
    var tier: String {
        get { defaults.string(forKey: Constants.keyTier) ?? "free" }
        set { defaults.set(newValue, forKey: Constants.keyTier) }
    }

    /// Stored activation code (if Plus activated)
    var activationCode: String? {
        get { defaults.string(forKey: Constants.keyActivationCode) }
        set { defaults.set(newValue, forKey: Constants.keyActivationCode) }
    }

    /// Custom cloned voices: [{voiceId, name, createdAt}]
    var customVoices: [CustomVoice] {
        get {
            guard let data = defaults.data(forKey: Constants.keyCustomVoices),
                  let voices = try? JSONDecoder().decode([CustomVoice].self, from: data) else {
                return []
            }
            return voices
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Constants.keyCustomVoices)
            }
        }
    }
}

/// A cloned voice stored locally
struct CustomVoice: Codable, Identifiable {
    let voiceId: String
    let name: String
    let createdAt: String

    var id: String { voiceId }
}
