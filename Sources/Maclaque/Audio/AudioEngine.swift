import AVFoundation
import Foundation

/// Plays sound files with dynamic volume based on slap intensity.
/// Uses AVAudioPlayer for reliable WAV playback.
final class AudioEngine {
    private var player: AVAudioPlayer?
    private var masterVolume: Float = 1.0

    /// Play a sound file at given intensity (0.0-1.0)
    func play(fileURL: URL, intensity: Float) {
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: fileURL)
            // Volume: ensure minimum audible level, scale with intensity
            let scaledVolume = (0.4 + intensity * 0.6) * masterVolume
            newPlayer.volume = min(scaledVolume, 1.0)
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            debugLog("[AudioEngine] Error playing \(fileURL.lastPathComponent): \(error)")
        }
    }

    /// Update the master volume (0.0-1.0)
    func setMasterVolume(_ volume: Float) {
        masterVolume = max(0, min(volume, 1.0))
    }

    func stop() {
        player?.stop()
    }

    deinit {
        stop()
    }
}
