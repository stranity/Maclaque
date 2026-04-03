import Foundation
import Security

/// Manages license validation and storage via LemonSqueezy API + Keychain.
final class LicenseManager {
    private let keychainService = "com.maclaque.license"
    private let keychainAccount = "license_key"

    /// Whether a valid license is stored
    var isActivated: Bool {
        storedLicenseKey != nil
    }

    /// The stored license key (from Keychain)
    var storedLicenseKey: String? {
        readFromKeychain()
    }

    /// Validate a license key with LemonSqueezy API
    func validate(licenseKey: String) async -> Bool {
        guard let url = URL(string: Constants.lemonSqueezyValidateURL) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "license_key": licenseKey,
            "instance_name": Host.current().localizedName ?? "Mac"
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let valid = json["valid"] as? Bool, valid {
                saveToKeychain(licenseKey)
                return true
            }
        } catch {
            debugLog("[LicenseManager] Validation error: \(error)")
        }
        return false
    }

    /// Remove stored license (for device transfer)
    func deactivate() {
        deleteFromKeychain()
    }

    // ── Keychain helpers ───────────────────────────────────────────────

    private func saveToKeychain(_ key: String) {
        deleteFromKeychain() // Remove old key first

        let data = key.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
