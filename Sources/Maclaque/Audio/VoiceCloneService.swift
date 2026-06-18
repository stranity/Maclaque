import Foundation

/// Handles voice cloning and tier management via the proxy server.
final class VoiceCloneService {
    static let shared = VoiceCloneService()

    /// Clone a voice from an audio file. Returns the new voice ID.
    func cloneVoice(name: String, audioData: Data, filename: String) async throws -> CustomVoice {
        let url = URL(string: "\(Constants.proxyBaseURL)/v1/voices/clone")!

        // Build multipart form
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.proxyAppSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(Preferences.shared.deviceId, forHTTPHeaderField: "X-Device-Id")

        var body = Data()
        // Name field
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n")
        body.append("\(name)\r\n")
        // Audio file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: audio/mpeg\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloneError.networkError("No HTTP response")
        }

        if httpResponse.statusCode == 429 {
            let result = try? JSONDecoder().decode(CloneLimitResponse.self, from: data)
            if result?.upgrade == true {
                throw VoiceCloneError.needsUpgrade
            }
            throw VoiceCloneError.cloneLimitReached
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoiceCloneError.apiError(httpResponse.statusCode, errorBody)
        }

        let result = try JSONDecoder().decode(CloneSuccessResponse.self, from: data)

        let voice = CustomVoice(
            voiceId: result.voice_id,
            name: result.name,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        // Store locally
        var voices = Preferences.shared.customVoices
        voices.append(voice)
        Preferences.shared.customVoices = voices

        return voice
    }

    /// Fetch the device's cloned voices and tier info from the proxy.
    func fetchVoiceList() async throws -> VoiceListResponse {
        let url = URL(string: "\(Constants.proxyBaseURL)/v1/voices/list")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Constants.proxyAppSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(Preferences.shared.deviceId, forHTTPHeaderField: "X-Device-Id")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw VoiceCloneError.networkError("Failed to fetch voice list")
        }

        let result = try JSONDecoder().decode(VoiceListResponse.self, from: data)

        // Sync local storage with server
        Preferences.shared.tier = result.tier

        return result
    }

    /// Activate Maclaque+ with an activation code.
    func activatePlus(code: String) async throws {
        let url = URL(string: "\(Constants.proxyBaseURL)/v1/tier/activate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.proxyAppSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(Preferences.shared.deviceId, forHTTPHeaderField: "X-Device-Id")

        let body = ["code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceCloneError.networkError("No HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VoiceCloneError.activationFailed(errorBody)
        }

        Preferences.shared.tier = "plus"
        Preferences.shared.activationCode = code
    }
}

// ── Response types ────────────────────────────────────────────────────
struct CloneSuccessResponse: Codable {
    let voice_id: String
    let name: String
    let clones_remaining: Int
}

struct CloneLimitResponse: Codable {
    let error: String
    let upgrade: Bool?
}

struct VoiceListResponse: Codable {
    let tier: String
    let clones: [VoiceListClone]
    let clones_limit: Int
    let clones_remaining: Int
    let packs_limit: Int
}

struct VoiceListClone: Codable {
    let voiceId: String
    let name: String
    let createdAt: String
}

// ── Errors ────────────────────────────────────────────────────────────
enum VoiceCloneError: LocalizedError {
    case cloneLimitReached
    case needsUpgrade
    case apiError(Int, String)
    case networkError(String)
    case activationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cloneLimitReached:
            return L10n.errorCloneLimitReached
        case .needsUpgrade:
            return L10n.errorNeedsUpgrade
        case .apiError(let code, let msg):
            return L10n.errorApi(code, msg)
        case .networkError(let msg):
            return L10n.errorNetwork(msg)
        case .activationFailed(let msg):
            return L10n.errorActivation(msg)
        }
    }
}

// ── Data extension for multipart building ─────────────────────────────
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
