import Foundation
import CHIDAccelerometer

/// Manages the IOKit HID accelerometer on a dedicated thread.
/// Delivers AccelSample values via a callback on the accelerometer thread.
final class AccelerometerManager {
    typealias SampleHandler = (Double, Double, Double) -> Void

    private var handle: OpaquePointer?
    private var thread: Thread?
    private var onSample: SampleHandler?

    var isRunning: Bool { handle != nil }

    func start(onSample: @escaping SampleHandler) {
        guard handle == nil else { return }
        self.onSample = onSample

        guard let accel = accelerometer_open() else {
            fputs("[MaclaqueDaemon] Failed to open accelerometer. Ensure sudo and Apple Silicon.\n", stderr)
            return
        }
        handle = accel

        // Register C callback that bridges to Swift closure
        let ctx = Unmanaged.passRetained(self).toOpaque()
        accelerometer_set_callback(accel, { sample, context in
            guard let context = context else { return }
            let mgr = Unmanaged<AccelerometerManager>.fromOpaque(context).takeUnretainedValue()
            mgr.onSample?(sample.x, sample.y, sample.z)
        }, ctx)

        // Run on dedicated thread (CFRunLoop must stay on same thread)
        let accelHandle = accel
        thread = Thread {
            accelerometer_run(accelHandle)
        }
        thread?.name = "com.maclaque.accelerometer"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    func stop() {
        guard let accel = handle else { return }
        accelerometer_stop(accel)
        accelerometer_close(accel)
        handle = nil
        thread = nil
        onSample = nil
    }

    deinit {
        stop()
    }
}
