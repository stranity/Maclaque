import Foundation

/// Event emitted when a slap is detected
struct SlapEvent {
    /// Normalized intensity 0.0 (light tap) to 1.0 (hard slap)
    let intensity: Float
    let timestamp: Date
}

/// Detects slaps using consecutive-sample counting.
///
/// Strategy: count how many consecutive samples exceed a magnitude threshold.
/// Keyboard/trackpad: chassis rings for 5-20 samples (~6-25ms at 800Hz).
/// Real slap: chassis rings for 40-100+ samples (~50-125ms).
/// We require a minimum consecutive count to trigger.
final class SlapDetector {
    typealias SlapHandler = (SlapEvent) -> Void

    // ── Configuration ──────────────────────────────────────────────────
    var sensitivity: Float = 0.5 {
        didSet { recalcThresholds() }
    }
    var cooldown: Double = 0.5

    // ── Internal state ─────────────────────────────────────────────────
    private var onSlap: SlapHandler?
    private var lastSlapTime: Date = .distantPast

    // Gravity removal
    private var gravityX: Double = 0
    private var gravityY: Double = 0
    private var gravityZ: Double = 0
    private let gravityAlpha: Double = 0.99
    private var samplesSinceStart: Int = 0
    private let warmupSamples: Int = 400

    // Consecutive hot-sample counting
    private var hotCount: Int = 0           // Consecutive samples above hotThreshold
    private var hotThreshold: Double = 1.0  // Magnitude to count as "hot"
    private var minHotCount: Int = 30       // Minimum consecutive hot samples to trigger (~37ms)
    private var peakInBurst: Double = 0     // Track peak during current burst
    private var triggered: Bool = false     // Already triggered for this burst?

    // Intensity scaling
    private let minMagnitude: Double = 2.0
    private let maxMagnitude: Double = 8.0

    init(onSlap: @escaping SlapHandler) {
        self.onSlap = onSlap
        recalcThresholds()
    }

    func processSample(x: Double, y: Double, z: Double) {
        // High-pass filter: remove gravity
        if samplesSinceStart == 0 {
            gravityX = x; gravityY = y; gravityZ = z
        }
        gravityX = gravityAlpha * gravityX + (1 - gravityAlpha) * x
        gravityY = gravityAlpha * gravityY + (1 - gravityAlpha) * y
        gravityZ = gravityAlpha * gravityZ + (1 - gravityAlpha) * z

        samplesSinceStart += 1
        guard samplesSinceStart > warmupSamples else { return }

        let linearX = x - gravityX
        let linearY = y - gravityY
        let linearZ = z - gravityZ
        let absMag = sqrt(linearX * linearX + linearY * linearY + linearZ * linearZ)

        if absMag >= hotThreshold {
            hotCount += 1
            if absMag > peakInBurst { peakInBurst = absMag }

            // Trigger once we have enough consecutive hot samples
            if hotCount >= minHotCount && !triggered {
                let now = Date()
                guard now.timeIntervalSince(lastSlapTime) >= cooldown else { return }

                lastSlapTime = now
                triggered = true

                let rawIntensity = (peakInBurst - minMagnitude) / (maxMagnitude - minMagnitude)
                let clampedIntensity = Float(min(max(rawIntensity, 0.0), 1.0))

                print("[Slap] intensity=\(String(format: "%.2f", clampedIntensity)) peak=\(String(format: "%.1f", peakInBurst)) hotCount=\(hotCount)")
                onSlap?(SlapEvent(intensity: clampedIntensity, timestamp: now))
            }
        } else {
            // Burst ended — reset
            if hotCount > 10 {
                print("[SlapDetector] burst ended: hotCount=\(hotCount) peak=\(String(format: "%.2f", peakInBurst)) needed=\(minHotCount)")
            }
            hotCount = 0
            peakInBurst = 0
            triggered = false
        }
    }

    private func recalcThresholds() {
        // hotThreshold: how strong a sample must be to count
        // sensitivity 0.0 → 2.0g (only strong vibrations)
        // sensitivity 1.0 → 1.0g
        hotThreshold = max(1.0, Double(2.0 - (sensitivity * 1.0)))

        // minHotCount: how many consecutive hot samples needed
        // Keyboard: 11-16 hot samples → must be above this
        // Side slap: 18-25 hot samples → must be at or below this
        // sensitivity 0.0 → 20 samples (25ms)
        // sensitivity 1.0 → 12 samples (15ms)
        minHotCount = max(12, Int(20 - sensitivity * 8))
    }
}
