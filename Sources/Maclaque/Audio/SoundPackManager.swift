import Foundation

/// Manages loading and selecting sound packs.
/// Looks for packs in the app bundle and in ~/Library/Application Support/Maclaque/CustomSounds/
final class SoundPackManager: ObservableObject {
    @Published var packs: [SoundPack] = []
    @Published var currentPackId: String = "aie"

    private let audioEngine: AudioEngine
    private var packDirectories: [String: URL] = [:]

    /// Custom sounds directory
    private var customSoundsDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Maclaque/CustomSounds", isDirectory: true)
    }

    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
        loadPacks()
    }

    func loadPacks() {
        var allPacks: [SoundPack] = []

        // Load from app bundle
        if let bundlePacksURL = Bundle.main.resourceURL?.appendingPathComponent("Packs") {
            allPacks.append(contentsOf: loadPacks(from: bundlePacksURL))
        }

        #if DEBUG
        // Development fallback: look for Resources/Packs relative to the executable
        if allPacks.isEmpty, let execURL = Bundle.main.executableURL {
            let projectRoot = execURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let devPacksURL = projectRoot.appendingPathComponent("Resources/Packs")
            allPacks.append(contentsOf: loadPacks(from: devPacksURL))
        }
        #endif

        // Load from custom sounds directory
        allPacks.append(contentsOf: loadPacks(from: customSoundsDir))

        packs = allPacks

        // Default to first pack if current is not found
        if !packs.contains(where: { $0.id == currentPackId }), let first = packs.first {
            currentPackId = first.id
        }
    }

    private func loadPacks(from directory: URL) -> [SoundPack] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        var loaded: [SoundPack] = []
        for entry in entries where entry.hasDirectoryPath {
            let manifestURL = entry.appendingPathComponent("pack.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let pack = try? JSONDecoder().decode(SoundPack.self, from: data) else {
                continue
            }
            packDirectories[pack.id] = entry
            loaded.append(pack)
        }
        return loaded
    }

    /// Play a random clip for a specific event trigger, matched to intensity
    func playForEvent(trigger: String, intensity: Float) {
        guard let pack = packs.first(where: { $0.id == currentPackId }) else {
            debugLog("[SoundPackManager] No pack found for id=\(currentPackId)")
            return
        }
        guard let packDir = packDirectories[pack.id] else {
            debugLog("[SoundPackManager] No directory for pack=\(pack.id)")
            return
        }

        let candidates = pack.clips(for: trigger, intensity: intensity)
        guard let clip = candidates.randomElement() else {
            debugLog("[SoundPackManager] No clips for trigger=\(trigger) intensity=\(intensity)")
            return
        }

        let fileURL = packDir.appendingPathComponent(clip.file)
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        debugLog("[SoundPackManager] Playing \(clip.file) exists=\(exists) url=\(fileURL.path)")
        audioEngine.play(fileURL: fileURL, intensity: intensity)
    }

    /// Play a random slap clip from the current pack, matched to intensity
    func playRandom(intensity: Float) {
        playForEvent(trigger: "slap", intensity: intensity)
    }

    /// Select a pack by ID
    func selectPack(_ id: String) {
        guard packs.contains(where: { $0.id == id }) else { return }
        currentPackId = id
    }
}
