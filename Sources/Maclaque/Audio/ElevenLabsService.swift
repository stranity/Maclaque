import Foundation

/// Generates speech audio via proxy server (ElevenLabs TTS behind Cloudflare Worker)
final class ElevenLabsService {
    static let shared = ElevenLabsService()

    static let voices: [(id: String, name: String, description: String)] = [
        ("IKne3meq5aSn9XLyUdCD", "Charlie", "Homme jeune, énergique"),
        ("N2lVS1w4EtoT3dr4eOWO", "Callum", "Homme, voix rauque"),
        ("pFZP5JQG7iQjIQuC4Bku", "Lily", "Femme, voix douce"),
        ("TX3LPaxmHKxFdv7VOQHJ", "Liam", "Homme, voix grave"),
        ("XB0fDUnXU5powFXDhCwa", "Charlotte", "Femme, voix claire"),
    ]

    func generateSpeech(
        text: String,
        voiceId: String,
        saveTo directory: URL,
        filename: String
    ) async throws -> URL {
        let url = URL(string: "\(Constants.proxyBaseURL)/v1/generate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.proxyAppSecret, forHTTPHeaderField: "X-App-Secret")
        request.setValue(Preferences.shared.deviceId, forHTTPHeaderField: "X-Device-Id")

        let body: [String: Any] = [
            "text": text,
            "voice_id": voiceId,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsError.apiError(0, "No HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw ElevenLabsError.generationLimitReached
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(httpResponse.statusCode, errorBody)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL
    }
}

enum ElevenLabsError: LocalizedError {
    case apiError(Int, String)
    case generationLimitReached

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg):
            return "API error \(code): \(msg)"
        case .generationLimitReached:
            return "Tu as atteint la limite de sons générés."
        }
    }
}
