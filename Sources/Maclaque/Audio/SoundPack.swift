import Foundation

/// A single audio clip within a pack
struct SoundClip: Codable {
    let file: String
    let intensity: String   // "light", "medium", "hard"
    let trigger: String?    // "slap", "charge_plug", "charge_unplug", "lid_open", "lid_close"
                            // nil or absent = "slap" (backward compatible)

    /// Resolved trigger type (defaults to "slap" if not specified)
    var resolvedTrigger: String {
        trigger ?? "slap"
    }
}

/// Sound pack manifest (matches pack.json)
struct SoundPack: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String       // SF Symbol name
    let emoji: String
    let clips: [SoundClip]

    /// Filter clips by trigger type, then by intensity bracket
    func clips(for triggerType: String, intensity: Float) -> [SoundClip] {
        // Filter by trigger
        let triggerClips = clips.filter { $0.resolvedTrigger == triggerType }

        // For slap triggers, use all clips regardless of intensity bracket
        // (real-world intensity values vary by hardware)
        if !triggerClips.isEmpty { return triggerClips }

        // Ultimate fallback: slap clips, then all clips
        let slapClips = clips.filter { $0.resolvedTrigger == "slap" }
        return slapClips.isEmpty ? clips : slapClips
    }

    /// Legacy convenience — filter slap clips by intensity
    func clips(for intensityValue: Float) -> [SoundClip] {
        clips(for: "slap", intensity: intensityValue)
    }
}
