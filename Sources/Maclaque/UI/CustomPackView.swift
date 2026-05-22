import SwiftUI

/// Simple view for creating custom sound packs with different triggers
struct CustomPackView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var packName = ""
    @State private var selectedVoiceIndex = 0
    @State private var slapTexts: [String] = ["", "", ""]
    @State private var chargePlugText = ""
    @State private var chargeUnplugText = ""
    @State private var isGenerating = false
    @State private var progress = 0
    @State private var totalToGenerate = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let voices = ElevenLabsService.voices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Crée ton pack")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "FF2A1F"))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("Max 3 packs, 5 sons de gifle + 4 événements.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "8888AA"))

                TextField("Nom du pack", text: $packName)
                    .textFieldStyle(.roundedBorder)

                Picker("Voix", selection: $selectedVoiceIndex) {
                    ForEach(0..<voices.count, id: \.self) { i in
                        Text("\(voices[i].name) — \(voices[i].description)").tag(i)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                // ── Gifles ──
                sectionHeader("Gifles", icon: "hand.raised.fill", count: slapTexts.filter { !$0.isEmpty }.count, max: 5)
                ForEach(slapTexts.indices, id: \.self) { i in
                    HStack(spacing: 6) {
                        Text("\(i+1).")
                            .font(.caption).foregroundColor(Color(hex: "8888AA")).frame(width: 16)
                        TextField("Ex: Aïe ! Mais arrête !", text: $slapTexts[i])
                            .textFieldStyle(.roundedBorder)
                        if slapTexts.count > 1 {
                            Button(action: { slapTexts.remove(at: i) }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if slapTexts.count < 5 {
                    Button(action: { slapTexts.append("") }) {
                        Label("Ajouter", systemImage: "plus.circle.fill").font(.caption)
                    }.buttonStyle(.plain)
                }

                Divider()

                // ── Événements ──
                sectionHeader("Branchement", icon: "bolt.fill", count: chargePlugText.isEmpty ? 0 : 1, max: 1)
                TextField("Ex: Mmh enfin du jus !", text: $chargePlugText)
                    .textFieldStyle(.roundedBorder)

                sectionHeader("Débranchement", icon: "bolt.slash.fill", count: chargeUnplugText.isEmpty ? 0 : 1, max: 1)
                TextField("Ex: Hé ! Remets ça !", text: $chargeUnplugText)
                    .textFieldStyle(.roundedBorder)


                Divider()

                // ── Générer ──
                if isGenerating {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(progress), total: Double(totalToGenerate))
                        Text("Génération \(progress)/\(totalToGenerate)...")
                            .font(.caption).foregroundColor(Color(hex: "8888AA"))
                    }
                } else {
                    Button(action: generatePack) {
                        Text("Générer le pack (\(allClips.count) sons)")
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
        .frame(width: 420, height: 520)
    }

    private func sectionHeader(_ title: String, icon: String, count: Int, max: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "FFD60A"))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(count)/\(max)")
                .font(.caption)
                .foregroundColor(Color(hex: "8888AA"))
        }
    }

    private var allClips: [(text: String, trigger: String)] {
        var clips: [(String, String)] = []
        for t in slapTexts where !t.isEmpty { clips.append((t, "slap")) }
        if !chargePlugText.isEmpty { clips.append((chargePlugText, "charge_plug")) }
        if !chargeUnplugText.isEmpty { clips.append((chargeUnplugText, "charge_unplug")) }
        return clips
    }

    private var canGenerate: Bool {
        !packName.isEmpty && !allClips.isEmpty
    }

    private func generatePack() {
        let customBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Maclaque/CustomSounds", isDirectory: true)
        let existingPacks = (try? FileManager.default.contentsOfDirectory(at: customBase, includingPropertiesForKeys: nil))?.filter { $0.hasDirectoryPath }.count ?? 0
        guard existingPacks < 3 else {
            errorMessage = "Maximum 3 packs custom. Supprime-en un pour en créer un nouveau."
            return
        }

        let clips = allClips
        isGenerating = true
        progress = 0
        totalToGenerate = clips.count
        errorMessage = nil
        successMessage = nil

        let voiceId = voices[selectedVoiceIndex].id
        let packId = packName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        Task {
            do {
                let packDir = customBase.appendingPathComponent(packId, isDirectory: true)
                var manifestClips: [[String: String]] = []

                for (index, clip) in clips.enumerated() {
                    let filename = "\(clip.trigger)_\(String(format: "%02d", index + 1)).mp3"

                    _ = try await ElevenLabsService.shared.generateSpeech(
                        text: clip.text,
                        voiceId: voiceId,
                        saveTo: packDir,
                        filename: filename
                    )

                    manifestClips.append([
                        "file": filename,
                        "intensity": "medium",
                        "trigger": clip.trigger
                    ])

                    await MainActor.run { progress = index + 1 }
                }

                let manifest: [String: Any] = [
                    "id": packId,
                    "name": packName,
                    "description": "Pack custom — \(voices[selectedVoiceIndex].name)",
                    "icon": "wand.and.stars",
                    "emoji": "🎤",
                    "clips": manifestClips
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
                try jsonData.write(to: packDir.appendingPathComponent("pack.json"))

                await MainActor.run {
                    isGenerating = false
                    successMessage = "Pack \"\(packName)\" créé avec \(clips.count) sons !"
                    appState.soundPackManager?.loadPacks()
                }
            } catch let error as ElevenLabsError {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
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
