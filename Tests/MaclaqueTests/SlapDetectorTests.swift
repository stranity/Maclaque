import XCTest
@testable import MaclaqueDaemon

final class SlapDetectorTests: XCTestCase {

    private func feedBaseline(_ detector: SlapDetector, count: Int = 500) {
        for _ in 0..<count {
            detector.processSample(x: 0.001, y: 0.002, z: 0.0)
        }
    }

    func testKeyboardDoesNotTrigger() {
        var events: [SlapEvent] = []
        let detector = SlapDetector { events.append($0) }
        detector.sensitivity = 1.0  // Max sensitivity
        detector.cooldown = 0.1
        feedBaseline(detector)

        // Keyboard: 8 hot samples (10ms) then quiet — too brief
        for _ in 0..<8 { detector.processSample(x: 3.0, y: 2.0, z: 2.0) }
        for _ in 0..<50 { detector.processSample(x: 0.01, y: 0.01, z: 0.0) }

        XCTAssertTrue(events.isEmpty, "Brief keyboard burst should NOT trigger")
    }

    func testSlapTriggers() {
        var events: [SlapEvent] = []
        let detector = SlapDetector { events.append($0) }
        detector.sensitivity = 1.0  // minHotCount=20
        detector.cooldown = 0.1
        feedBaseline(detector)

        // Slap: 30 sustained hot samples (~37ms)
        for _ in 0..<30 { detector.processSample(x: 2.0, y: 1.5, z: 2.0) }

        XCTAssertFalse(events.isEmpty, "Sustained slap should trigger")
    }

    func testHardSlapHighIntensity() {
        var events: [SlapEvent] = []
        let detector = SlapDetector { events.append($0) }
        detector.sensitivity = 0.5
        detector.cooldown = 0.1
        feedBaseline(detector)

        // Hard slap: 40 samples at ~5g
        for _ in 0..<40 { detector.processSample(x: 3.0, y: 2.5, z: 3.0) }

        if let event = events.first {
            XCTAssertGreaterThan(event.intensity, 0.3, "Hard slap should have decent intensity")
        } else {
            XCTFail("Hard slap should trigger")
        }
    }

    func testCooldownPreventsRapidFiring() {
        var events: [SlapEvent] = []
        let detector = SlapDetector { events.append($0) }
        detector.sensitivity = 1.0
        detector.cooldown = 1.0
        feedBaseline(detector)

        // Two slap bursts with brief gap
        for _ in 0..<30 { detector.processSample(x: 2.0, y: 1.5, z: 2.0) }
        for _ in 0..<5 { detector.processSample(x: 0.01, y: 0.01, z: 0.0) }
        for _ in 0..<30 { detector.processSample(x: 2.0, y: 1.5, z: 2.0) }

        XCTAssertEqual(events.count, 1, "Cooldown should prevent second event")
    }

    func testGravityRemoval() {
        var events: [SlapEvent] = []
        let detector = SlapDetector { events.append($0) }
        detector.sensitivity = 1.0
        detector.cooldown = 0.1

        // Baseline with gravity
        for _ in 0..<500 {
            detector.processSample(x: -0.004, y: -0.005, z: -0.989)
        }
        XCTAssertTrue(events.isEmpty, "Gravity alone should not trigger")

        // Slap on top of gravity
        for _ in 0..<30 {
            detector.processSample(x: 2.0, y: 1.5, z: 1.511)
        }
        XCTAssertFalse(events.isEmpty, "Slap on top of gravity should be detected")
    }
}
