import Foundation
import IOKit.pwr_mgt

// IOKit power message constants (not bridged to Swift)
private let kIOMessageSystemWillSleep: UInt32 = 0xE0000280
private let kIOMessageSystemHasPoweredOn: UInt32 = 0xE0000300
private let kIOMessageCanSystemSleep: UInt32 = 0xE0000270

/// Monitors lid open/close via macOS sleep/wake power notifications.
/// Works on ALL Macs (no ALS dependency).
final class LidMonitor {
    enum LidAction: String {
        case opened
        case closed
    }

    typealias LidHandler = (LidAction) -> Void

    private var onEvent: LidHandler?
    private var notifyPortRef: IONotificationPortRef?
    private var notifierObject: io_object_t = 0
    private var rootPort: io_connect_t = 0

    func start(onEvent: @escaping LidHandler) {
        self.onEvent = onEvent

        rootPort = IORegisterForSystemPower(
            Unmanaged.passUnretained(self).toOpaque(),
            &notifyPortRef,
            sleepWakeCallback,
            &notifierObject
        )

        guard rootPort != 0, let port = notifyPortRef else {
            print("[LidMonitor] ⚠ Could not register for power notifications")
            return
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
            .defaultMode
        )

        print("[LidMonitor] Sleep/wake monitor started ✓")
    }

    /// No-op — kept for API compatibility with main.swift
    func processSample(z: Double) {}

    func stop() {
        if notifierObject != 0 {
            IODeregisterForSystemPower(&notifierObject)
            notifierObject = 0
        }
        if rootPort != 0 {
            IOServiceClose(rootPort)
            rootPort = 0
        }
        if let port = notifyPortRef {
            IONotificationPortDestroy(port)
            notifyPortRef = nil
        }
    }

    deinit { stop() }

    /// Bridge: called from the C callback to deliver events
    fileprivate func handlePowerEvent(_ messageType: UInt32) {
        switch messageType {
        case kIOMessageSystemWillSleep:
            print("[Lid] closed (system going to sleep)")
            onEvent?(.closed)
            IOAllowPowerChange(rootPort, Int(messageType))
        case kIOMessageSystemHasPoweredOn:
            print("[Lid] opened (system woke up)")
            onEvent?(.opened)
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange(rootPort, Int(messageType))
        default:
            break
        }
    }
}

/// C callback for IOKit power notifications
private func sleepWakeCallback(
    _ refCon: UnsafeMutableRawPointer?,
    _ service: io_service_t,
    _ messageType: UInt32,
    _ messageArgument: UnsafeMutableRawPointer?
) {
    guard let refCon = refCon else { return }
    let monitor = Unmanaged<LidMonitor>.fromOpaque(refCon).takeUnretainedValue()
    monitor.handlePowerEvent(messageType)
}
