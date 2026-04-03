import Foundation
import IOKit.ps

/// Monitors power/charging state changes (plug/unplug charger).
/// Works with MagSafe and USB-C power on Apple Silicon Macs.
final class USBMonitor {
    enum USBAction: String {
        case plug
        case unplug
    }

    typealias USBHandler = (USBAction) -> Void

    private var onEvent: USBHandler?
    private var timer: DispatchSourceTimer?
    private var wasCharging: Bool?

    func start(onEvent: @escaping USBHandler) {
        self.onEvent = onEvent

        // Get initial state
        wasCharging = isCharging()

        // Poll every 1 second for power source changes
        timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer?.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer?.setEventHandler { [weak self] in
            self?.checkPowerState()
        }
        timer?.resume()
    }

    private func checkPowerState() {
        let charging = isCharging()
        guard let previous = wasCharging, charging != previous else {
            if wasCharging == nil { wasCharging = charging }
            return
        }
        wasCharging = charging

        if charging {
            onEvent?(.plug)
        } else {
            onEvent?(.unplug)
        }
    }

    private func isCharging() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [Any],
              let first = sources.first else {
            return false
        }
        guard let desc = IOPSGetPowerSourceDescription(info, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else {
            return false
        }
        let state = desc[kIOPSPowerSourceStateKey] as? String
        return state == kIOPSACPowerValue
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    deinit { stop() }
}
