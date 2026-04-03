import SwiftUI

/// View for creating custom sound packs via ElevenLabs TTS
struct CustomPackView: View {
    @EnvironmentObject var appState: AppState
    @State private var packName = ""
    @State private var apiKey = ""
    @State private var selectedVoiceIndex = 0
    @State private var clips: [CustomClipEntry] = [
        CustomClipEntry(text: "", trigger: "slap"),
    ]
    @State private var isGenerating = false
    @State private var progress = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let voices = ElevenLabsService.voices
    private let triggers = ["slap", "charge_plug", "charge_unplug", "lid_open", "lid_close"]
    private let triggerLabels = ["Gifle", "Branchement", "Débranchement", "Ouverture", "Fermeture"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Créer un pack custom")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FF2A1F"))

                Text("Utilise l'IA pour générer tes propres sons. Tu as besoin d'une clé API ElevenLabs (gratuit jusqu'à 10 000 caractères/mois).")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8888AA"))

                // API Key
                SecureField("Clé API ElevenLabs", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                // Pack name
                TextField("Nom du pack (ex: Mon Pack)", text: $packName)
                    .textFieldStyle(.roundedBorder)

                // Voice
                Picker("Voix", selection: $selectedVoiceIndex) {
                    ForEach(0..<voices.count, id: \.self) { i in
                        Text("\(voices[i].name) — \(voices[i].description)")
                            .tag(i)
                    }
                }

                Divider()

                // Clips
                Text("Sons (\(clips.count))")
                    .font(.system(size: 14, weight: .semibold))

                ForEach(clips.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Picker("", selection: $clips[index].trigger) {
                            ForEach(0..<triggers.count, id: \.self) { i in
                                Text(triggerLabels[i]).tag(triggers[i])
                            }
                        }
                        .frame(width: 120)

                        TextField("Texte à dire...", text: $clips[index].text)
                            .textFieldStyle(.roundedBorder)

                        Button(action: { clips.remove(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(clips.count <= 1)
                    }
                }

                Button(action: { clips.append(CustomClipEntry(text: "", trigger: "slap")) }) {
                    Label("Ajouter un son", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Divider()

                // Generate button
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(progress), total: Double(clips.count))
                        Text("Génération \(progress)/\(clips.count)...")
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

                // Messages
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if let success = successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(16)
        }
        .frame(width: 420, height: 500)
    }

    private var canGenerate: Bool {
        !apiKey.isEmpty && !packName.isEmpty && clips.allSatisfy { !$0.text.isEmpty }
    }

    private func generatePack() {
        isGenerating = true
        progress = 0
        errorMessage = nil
        successMessage = nil

        let voiceId = voices[selectedVoiceIndex].id
        let packId = packName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        Task {
            do {
                let customDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("Maclaque/CustomSounds/\(packId)", isDirectory: true)

                var manifestClips: [[String: String]] = []

                for (index, clip) in clips.enumerated() {
                    let filename = "\(clip.trigger)_\(String(format: "%02d", index + 1)).mp3"

                    _ = try await ElevenLabsService.shared.generateSpeech(
                        text: clip.text,
                        voiceId: voiceId,
                        apiKey: apiKey,
                        saveTo: customDir,
                        filename: filename
                    )

                    manifestClips.append([
                        "file": filename,
                        "intensity": "medium",
                        "trigger": clip.trigger
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
                    successMessage = "Pack \"\(packName)\" créé avec \(clips.count) sons !"
                    appState.soundPackManager?.loadPacks()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CustomClipEntry {
    var text: String
    var trigger: String
}
