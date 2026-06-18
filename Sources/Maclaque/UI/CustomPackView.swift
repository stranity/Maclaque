import SwiftUI
import UniformTypeIdentifiers

/// View for creating custom sound packs — with voice cloning support
struct CustomPackView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var packName = ""
    @State private var selectedVoiceId: String = ElevenLabsService.voices.first?.id ?? ""
    @State private var slapTexts: [String] = ["", "", ""]
    @State private var chargePlugText = ""
    @State private var chargeUnplugText = ""
    @State private var lidOpenText = ""
    @State private var lidCloseText = ""
    @State private var isGenerating = false
    @State private var progress = 0
    @State private var totalToGenerate = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Voice cloning
    @State private var showVoiceClone = false
    @State private var cloneVoiceName = ""
    @State private var isCloning = false
    @State private var customVoices: [CustomVoice] = Preferences.shared.customVoices

    // Activation
    @State private var showActivation = false
    @State private var activationCode = ""
    @State private var isActivating = false

    private let presetVoices = ElevenLabsService.voices

    var body: some View {
        if Preferences.shared.tier == "free" {
            freePaywall
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    packNameField
                    voicePicker
                    Divider()
                    slapSection
                    Divider()
                    eventSections
                    Divider()
                    generateSection
                    feedbackSection
                }
                .padding(16)
            }
            .frame(width: 420, height: 560)
            .sheet(isPresented: $showVoiceClone) { voiceCloneSheet }
            .sheet(isPresented: $showActivation) { activationSheet }
        }
    }

    // ── Free tier paywall ─────────────────────────────────────────────
    private var freePaywall: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "FF2A1F"))

            Text(L10n.customPackLocked)
                .font(.system(size: 16, weight: .bold))

            Text(L10n.customPackLockedMessage)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Link(destination: URL(string: "https://maclaque.com")!) {
                Text(L10n.unlockMaclaque)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FF2A1F"))
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .frame(width: 420, height: 300)
    }

    // ── Header ────────────────────────────────────────────────────────
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.createYourPack)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "FF2A1F"))
                Spacer()
                if Preferences.shared.tier == "plus" {
                    Text("PLUS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "FFD60A"))
                        .cornerRadius(4)
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            let tier = Preferences.shared.tier
            let maxPacks = tier == "plus" ? 10 : 3
            Text(L10n.packLimitDescription(maxPacks: maxPacks))
                .font(.caption)
                .foregroundColor(Color(hex: "8888AA"))
        }
    }

    // ── Pack name ─────────────────────────────────────────────────────
    private var packNameField: some View {
        TextField(L10n.packName, text: $packName)
            .textFieldStyle(.roundedBorder)
    }

    // ── Voice picker (preset + custom) ────────────────────────────────
    private var voicePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.voice, selection: $selectedVoiceId) {
                // Preset voices
                ForEach(presetVoices, id: \.id) { voice in
                    Text("\(voice.name) — \(voice.description)").tag(voice.id)
                }
                // Custom cloned voices
                if !customVoices.isEmpty {
                    Divider()
                    ForEach(customVoices) { voice in
                        HStack {
                            Text("🎙 \(voice.name)")
                        }.tag(voice.voiceId)
                    }
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                Button(action: { showVoiceClone = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.badge.plus")
                            .foregroundColor(Color(hex: "FFD60A"))
                        Text(L10n.cloneAVoice)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.plain)

                if Preferences.shared.tier == "basic" {
                    Button(action: { showActivation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color(hex: "FFD60A"))
                            Text(L10n.activateMaclaquePlus)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "FFD60A"))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // ── Slaps ─────────────────────────────────────────────────────────
    private var slapSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(L10n.slaps, icon: "hand.raised.fill", count: slapTexts.filter { !$0.isEmpty }.count, max: 5)
            ForEach(slapTexts.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Text("\(i+1).")
                        .font(.caption).foregroundColor(Color(hex: "8888AA")).frame(width: 16)
                    TextField(L10n.slapPlaceholder, text: $slapTexts[i])
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
                    Label(L10n.add, systemImage: "plus.circle.fill").font(.caption)
                }.buttonStyle(.plain)
            }
        }
    }

    // ── Events ────────────────────────────────────────────────────────
    private var eventSections: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(L10n.plugIn, icon: "bolt.fill", count: chargePlugText.isEmpty ? 0 : 1, max: 1)
            TextField(L10n.plugInPlaceholder, text: $chargePlugText)
                .textFieldStyle(.roundedBorder)

            sectionHeader(L10n.unplug, icon: "bolt.slash.fill", count: chargeUnplugText.isEmpty ? 0 : 1, max: 1)
            TextField(L10n.unplugPlaceholder, text: $chargeUnplugText)
                .textFieldStyle(.roundedBorder)

            Divider()

            sectionHeader(L10n.lidOpen, icon: "laptopcomputer", count: lidOpenText.isEmpty ? 0 : 1, max: 1)
            TextField(L10n.lidOpenPlaceholder, text: $lidOpenText)
                .textFieldStyle(.roundedBorder)

            sectionHeader(L10n.lidClose, icon: "sleep", count: lidCloseText.isEmpty ? 0 : 1, max: 1)
            TextField(L10n.lidClosePlaceholder, text: $lidCloseText)
                .textFieldStyle(.roundedBorder)
        }
    }

    // ── Generate button ───────────────────────────────────────────────
    private var generateSection: some View {
        Group {
            if isGenerating {
                VStack(spacing: 8) {
                    ProgressView(value: Double(progress), total: Double(totalToGenerate))
                    Text(L10n.generatingProgress(progress, totalToGenerate))
                        .font(.caption).foregroundColor(Color(hex: "8888AA"))
                }
            } else {
                Button(action: generatePack) {
                    Text(L10n.generatePack(allClips.count))
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
        }
    }

    // ── Feedback ──────────────────────────────────────────────────────
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }
            if let success = successMessage {
                Text(success).font(.caption).foregroundColor(.green)
            }
        }
    }

    // ── Voice Clone Sheet ─────────────────────────────────────────────
    private var voiceCloneSheet: some View {
        VStack(spacing: 16) {
            Text(L10n.cloneAVoiceTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "FF2A1F"))

            let tier = Preferences.shared.tier
            let maxClones = tier == "plus" ? 10 : 3
            Text(L10n.cloneDescription(used: customVoices.count, max: maxClones))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField(L10n.voiceNamePlaceholder, text: $cloneVoiceName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)

            Button(action: pickAndCloneVoice) {
                HStack(spacing: 8) {
                    if isCloning {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "doc.badge.plus")
                    }
                    Text(isCloning ? L10n.cloningInProgress : L10n.chooseMP3)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(cloneVoiceName.isEmpty || isCloning ? Color(hex: "2A2A42") : Color(hex: "FF2A1F"))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(cloneVoiceName.isEmpty || isCloning)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }

            // List existing cloned voices
            if !customVoices.isEmpty {
                Divider()
                Text(L10n.yourClonedVoices)
                    .font(.system(size: 13, weight: .semibold))
                ForEach(customVoices) { voice in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(Color(hex: "FFD60A"))
                        Text(voice.name)
                            .font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            Spacer()

            Button(L10n.close) { showVoiceClone = false }
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 380, height: 400)
    }

    // ── Activation Sheet ──────────────────────────────────────────────
    private var activationSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "FFD60A"))

            Text("Maclaque+")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(hex: "FF2A1F"))

            Text(L10n.maclaquePlusFeatures)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField(L10n.activationCode, text: $activationCode)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Button(action: activatePlus) {
                HStack(spacing: 8) {
                    if isActivating {
                        ProgressView().scaleEffect(0.7)
                    }
                    Text(isActivating ? L10n.activating : L10n.activate)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(activationCode.isEmpty || isActivating ? Color(hex: "2A2A42") : Color(hex: "FFD60A"))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(activationCode.isEmpty || isActivating)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundColor(.red)
            }

            Spacer()

            Button(L10n.close) { showActivation = false }
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 340, height: 320)
    }

    // ── Helpers ────────────────────────────────────────────────────────
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
        if !lidOpenText.isEmpty { clips.append((lidOpenText, "lid_open")) }
        if !lidCloseText.isEmpty { clips.append((lidCloseText, "lid_close")) }
        return clips
    }

    private var canGenerate: Bool {
        !packName.isEmpty && !allClips.isEmpty
    }

    // ── Voice clone action ────────────────────────────────────────────
    private func pickAndCloneVoice() {
        let panel = NSOpenPanel()
        panel.title = L10n.chooseAudioFile
        panel.allowedContentTypes = [UTType.mp3, UTType.audio]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }

        isCloning = true
        errorMessage = nil

        Task {
            do {
                let audioData = try Data(contentsOf: fileURL)
                let voice = try await VoiceCloneService.shared.cloneVoice(
                    name: cloneVoiceName,
                    audioData: audioData,
                    filename: fileURL.lastPathComponent
                )
                await MainActor.run {
                    isCloning = false
                    customVoices = Preferences.shared.customVoices
                    selectedVoiceId = voice.voiceId
                    cloneVoiceName = ""
                    showVoiceClone = false
                    successMessage = L10n.voiceCloned(voice.name)
                }
            } catch {
                await MainActor.run {
                    isCloning = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // ── Activation action ─────────────────────────────────────────────
    private func activatePlus() {
        isActivating = true
        errorMessage = nil

        Task {
            do {
                try await VoiceCloneService.shared.activatePlus(code: activationCode)
                await MainActor.run {
                    isActivating = false
                    showActivation = false
                    successMessage = L10n.maclaquePlusActivated
                }
            } catch {
                await MainActor.run {
                    isActivating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // ── Generate pack ─────────────────────────────────────────────────
    private func generatePack() {
        let customBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Maclaque/CustomSounds", isDirectory: true)
        let existingPacks = (try? FileManager.default.contentsOfDirectory(at: customBase, includingPropertiesForKeys: nil))?.filter { $0.hasDirectoryPath }.count ?? 0
        let maxPacks = Preferences.shared.tier == "plus" ? 10 : 3
        guard existingPacks < maxPacks else {
            errorMessage = L10n.maxPacksReached(maxPacks)
            return
        }

        let clips = allClips
        isGenerating = true
        progress = 0
        totalToGenerate = clips.count
        errorMessage = nil
        successMessage = nil

        let voiceId = selectedVoiceId
        let voiceName = presetVoices.first(where: { $0.id == voiceId })?.name
            ?? customVoices.first(where: { $0.voiceId == voiceId })?.name
            ?? "Custom"
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
                    "description": "Pack custom — \(voiceName)",
                    "icon": "wand.and.stars",
                    "emoji": "🎤",
                    "clips": manifestClips
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted)
                try jsonData.write(to: packDir.appendingPathComponent("pack.json"))

                await MainActor.run {
                    isGenerating = false
                    successMessage = L10n.packCreated(name: packName, count: clips.count)
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
