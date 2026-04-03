import Foundation

/// Generates speech audio via ElevenLabs TTS API
final class ElevenLabsService {
    static let shared = ElevenLabsService()

    private let baseURL = "https://api.elevenlabs.io/v1"

    // Default voices (ElevenLabs premade, free tier)
    static let voices: [(id: String, name: String, description: String)] = [
        ("IKne3meq5aSn9XLyUdCD", "Charlie", "Homme jeune, énergique"),
        ("N2lVS1w4EtoT3dr4eOWO", "Callum", "Homme, voix rauque"),
        ("pFZP5JQG7iQjIQuC4Bku", "Lily", "Femme, voix douce"),
        ("TX3LPaxmHKxFdv7VOQHJ", "Liam", "Homme, voix grave"),
        ("XB0fDUnXU5powFXDhCwa", "Charlotte", "Femme, voix claire"),
    ]

    /// Generate speech from text and save as MP3
    /// - Returns: URL of saved file, or nil on failure
    func generateSpeech(
        text: String,
        voiceId: String,
        apiKey: String,
        saveTo directory: URL,
        filename: String
    ) async throws -> URL {
        let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.35,
                "similarity_boost": 0.75,
                "style": 0.6,
                "use_speaker_boost": true
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError(statusCode, errorBody)
        }

        // Save MP3 file
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL)

        return fileURL
    }
}

enum ElevenLabsError: LocalizedError {
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg):
            return "ElevenLabs API error \(code): \(msg)"
        }
    }
}
