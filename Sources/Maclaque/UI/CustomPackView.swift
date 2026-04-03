import SwiftUI

/// Simple view for creating custom sound packs — no API key needed, uses built-in key
struct CustomPackView: View {
    @EnvironmentObject var appState: AppState
    @State private var packName = ""
    @State private var selectedVoiceIndex = 0
    @State private var clips: [CustomClipEntry] = [
        CustomClipEntry(text: ""),
        CustomClipEntry(text: ""),
        CustomClipEntry(text: ""),
    ]
    @State private var isGenerating = false
    @State private var progress = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let voices = ElevenLabsService.voices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Crée ton pack")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FF2A1F"))

                Text("Tape ce que ton Mac doit dire quand tu le gifles.\nMax 3 packs, 5 phrases chacun.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8888AA"))

                // Pack name
                TextField("Nom du pack", text: $packName)
                    .textFieldStyle(.roundedBorder)

                // Voice
                Picker("Voix", selection: $selectedVoiceIndex) {
                    ForEach(0..<voices.count, id: \.self) { i in
                        Text("\(voices[i].name) — \(voices[i].description)")
                            .tag(i)
                    }
                }

                Divider()

                // Clips — just text fields, dead simple
                Text("Phrases (\(clips.filter { !$0.text.isEmpty }.count))")
                    .font(.system(size: 14, weight: .semibold))

                ForEach(clips.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(Color(hex: "8888AA"))
                            .frame(width: 20)

                        TextField("Ex: Aïe ! Mais t'es malade ?!", text: $clips[index].text)
                            .textFieldStyle(.roundedBorder)

                        if clips.count > 1 {
                            Button(action: { clips.remove(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if clips.count < 5 {
                    Button(action: { clips.append(CustomClipEntry(text: "")) }) {
                        Label("Ajouter une phrase", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Generate
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(progress), total: Double(validClips.count))
                        Text("Génération \(progress)/\(validClips.count)...")
                            .font(.caption)
                            .foregroundColor(Color(hex: "8888AA"))
                    }
                } else {
                    Button(action: generatePack) {
                        Text("Générer le pack")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canGenerate ? Color(hex: "FF2A1F") : Color(hex: "2A2A42"))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGenerate)
                }

                if let error = errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }
                if let success = successMessage {
                    Text(success).font(.caption).foregroundColor(.green)
                }
            }
            .padding(16)
        }
        .frame(width: 420, height: 480)
    }

    private var validClips: [CustomClipEntry] {
        clips.filter { !$0.text.isEmpty }
    }

    private var canGenerate: Bool {
        !packName.isEmpty && !validClips.isEmpty
    }

    private func generatePack() {
        guard appState.isLicensed else {
            errorMessage = "Achète Maclaque pour créer des packs custom."
            return
        }

        // Limit: 3 custom packs max
        let customDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Maclaque/CustomSounds", isDirectory: true)
        let existingPacks = (try? FileManager.default.contentsOfDirectory(at: customDir, includingPropertiesForKeys: nil))?.filter { $0.hasDirectoryPath }.count ?? 0
        guard existingPacks < 3 else {
            errorMessage = "Maximum 3 packs custom atteint. Supprime un pack existant pour en créer un nouveau."
            return
        }

        // Limit: max 5 phrases per pack
        guard validClips.count <= 5 else {
            errorMessage = "Maximum 5 phrases par pack."
            return
        }

        isGenerating = true
        progress = 0
        errorMessage = nil
        successMessage = nil

        let voiceId = voices[selectedVoiceIndex].id
        let packId = packName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        let clipsToGenerate = validClips

        Task {
            do {
                let customDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Maclaque/CustomSounds/\(packId)", isDirectory: true)

                var manifestClips: [[String: String]] = []

                for (index, clip) in clipsToGenerate.enumerated() {
                    let filename = "slap_\(String(format: "%02d", index + 1)).mp3"

                    _ = try await ElevenLabsService.shared.generateSpeech(
                        text: clip.text,
                        voiceId: voiceId,
                        apiKey: Secrets.elevenLabsAPIKey,
                        saveTo: customDir,
                        filename: filename
                    )

                    manifestClips.append([
                        "file": filename,
                        "intensity": "medium"
                    ])

                    await MainActor.run { progress = index + 1 }
                }

                // Write pack.json
                let manifest: [String: Any] = [
                    "id": packId,
                    "name": packName,
                    "description": "Pack custom — \(voices[selectedVoiceIndex].name)",
                    "icon": "wand.and.stars",
                    "emoji": "🎤",
                    "clips": manifestClips
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
                try jsonData.write(to: customDir.appendingPathComponent("pack.json"))

                await MainActor.run {
                    isGenerating = false
                    successMessage = "Pack \"\(packName)\" créé !"
                    appState.soundPackManager?.loadPacks()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = "Erreur : \(error.localizedDescription)"
                }
            }
        }
    }
}

struct CustomClipEntry {
    var text: String
}
