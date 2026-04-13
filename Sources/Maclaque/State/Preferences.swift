import Foundation
import Security

/// Persisted user preferences via UserDefaults
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard
    private let keychainService = "com.maclaque.trial"
    private let keychainAccount = "freeSlapsRemaining"

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

    var freeSlapsRemaining: Int {
        get {
            // Read from Keychain (persists across reinstalls)
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: keychainService,
                kSecAttrAccount: keychainAccount,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess,
               let data = result as? Data,
               let str = String(data: data, encoding: .utf8),
               let value = Int(str) {
                return value
            }
            // First launch ever — no Keychain entry yet
            return Constants.maxFreeSlaps
        }
        set {
            let data = "\(newValue)".data(using: .utf8)!
            // Try update first
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: keychainService,
                kSecAttrAccount: keychainAccount,
            ]
            let update: [CFString: Any] = [kSecValueData: data]
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            if status == errSecItemNotFound {
                // First write — add to Keychain
                var addQuery = query
                addQuery[kSecValueData] = data
                addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
                SecItemAdd(addQuery as CFDictionary, nil)
            }
        }
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
}
