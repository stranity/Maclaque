import Foundation
import IOKit

/// Monitors lid movement by reading the Ambient Light Sensor (ALS).
/// When the lid starts closing, light drops rapidly → "closed".
/// When it opens again, light rises → "opened".
final class LidMonitor {
    enum LidAction: String {
        case opened
        case closed
    }

    typealias LidHandler = (LidAction) -> Void

    private var onEvent: LidHandler?
    private var timer: DispatchSourceTimer?
    private var lastTriggerTime: Date = .distantPast
    private let cooldown: Double = 3.0

    // ALS state
    private var baselineLux: Double?
    private var previousLux: Double?
    private var darkSamples: Int = 0
    private var brightSamples: Int = 0
    private let darkThreshold: Int = 3    // consecutive dark readings to trigger
    private let brightThreshold: Int = 3  // consecutive bright readings to trigger
    private var lidIsClosed = false

    // Connection to ALS
    private var alsConnection: io_connect_t = 0

    func start(onEvent: @escaping LidHandler) {
        self.onEvent = onEvent

        // Open ALS
        guard openALS() else {
            print("[LidMonitor] ⚠ Could not open ALS — lid detection disabled")
            return
        }
        print("[LidMonitor] ALS opened — monitoring light changes")

        // Poll ALS at 10 Hz
        timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer?.schedule(deadline: .now() + 0.5, repeating: 0.1)
        timer?.setEventHandler { [weak self] in
            self?.checkALS()
        }
        timer?.resume()
    }

    private func openALS() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleLMUController")
        )
        guard service != 0 else {
            print("[LidMonitor] AppleLMUController not found")
            return false
        }
        defer { IOObjectRelease(service) }

        let kr = IOServiceOpen(service, mach_task_self_, 0, &alsConnection)
        guard kr == KERN_SUCCESS else {
            print("[LidMonitor] IOServiceOpen failed: \(kr)")
            return false
        }
        return true
    }

    private func readALS() -> Double? {
        var outputCount: UInt32 = 2
        var values = [UInt64](repeating: 0, count: 2)
        let kr = IOConnectCallMethod(
            alsConnection,
            0, // selector for reading ALS
            nil, 0,
            nil, 0,
            &values, &outputCount,
            nil, nil
        )
        guard kr == KERN_SUCCESS else { return nil }
        // Average of left and right sensor
        return Double(values[0] + values[1]) / 2.0
    }

    private func checkALS() {
        guard let lux = readALS() else { return }

        // Initialize baseline
        if baselineLux == nil {
            baselineLux = lux
            previousLux = lux
            print("[LidMonitor] ALS baseline: \(String(format: "%.0f", lux))")
            return
        }

        let now = Date()

        // Debug every second
        if Int(now.timeIntervalSince1970) % 2 == 0 {
            print("[LidMonitor] lux=\(String(format: "%.0f", lux)) baseline=\(String(format: "%.0f", baselineLux!))")
        }

        // Check cooldown
        guard now.timeIntervalSince(lastTriggerTime) >= cooldown else {
            baselineLux = lux
            previousLux = lux
            darkSamples = 0
            brightSamples = 0
            return
        }

        let ratio = baselineLux! > 0 ? lux / baselineLux! : 0

        if !lidIsClosed {
            // Detect closing: light drops significantly (< 30% of baseline)
            if ratio < 0.3 && baselineLux! > 5 {
                darkSamples += 1
                brightSamples = 0
                if darkSamples >= darkThreshold {
                    print("[Lid] closed (lux=\(String(format: "%.0f", lux)) was=\(String(format: "%.0f", baselineLux!)))")
                    onEvent?(.closed)
                    lastTriggerTime = now
                    lidIsClosed = true
                    darkSamples = 0
                }
            } else {
                darkSamples = 0
                // Slowly adapt baseline
                baselineLux = baselineLux! * 0.95 + lux * 0.05
            }
        } else {
            // Detect opening: light returns (> 3x current dark level or absolute threshold)
            if lux > max(previousLux ?? 0 * 3, 10) {
                brightSamples += 1
                darkSamples = 0
                if brightSamples >= brightThreshold {
                    print("[Lid] opened (lux=\(String(format: "%.0f", lux)))")
                    onEvent?(.opened)
                    lastTriggerTime = now
                    lidIsClosed = false
                    brightSamples = 0
                    baselineLux = lux
                }
            } else {
                brightSamples = 0
            }
        }

        previousLux = lux
    }

    /// No longer needed — ALS-based, not accelerometer-based
    func processSample(z: Double) {
        // No-op: kept for API compatibility with main.swift
    }

    func stop() {
        timer?.cancel()
        timer = nil
        if alsConnection != 0 {
            IOServiceClose(alsConnection)
            alsConnection = 0
        }
    }

    deinit { stop() }
}
