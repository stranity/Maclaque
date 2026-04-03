import Foundation

// ── MaclaqueDaemon ─────────────────────────────────────────────────────
// Root-level daemon that reads the Apple Silicon accelerometer,
// detects slaps, monitors USB and lid events, and sends them
// to the Maclaque app via a Unix domain socket.
// Usage: sudo ./MaclaqueDaemon

print("╔═══════════════════════════════════════╗")
print("║  MaclaqueDaemon v1.0                  ║")
print("║  Maclaque. Il te répond en français.   ║")
print("╚═══════════════════════════════════════╝")

// ── Check root ─────────────────────────────────────────────────────────
guard getuid() == 0 else {
    fputs("[MaclaqueDaemon] Erreur : ce daemon doit tourner en root (sudo).\n", stderr)
    exit(1)
}

// ── Socket server ──────────────────────────────────────────────────────
let socketServer = SocketServer()
do {
    try socketServer.start()
} catch {
    fputs("[MaclaqueDaemon] Erreur socket : \(error.localizedDescription)\n", stderr)
    exit(1)
}

// ── Slap detector ──────────────────────────────────────────────────────
let slapDetector = SlapDetector { event in
    print("[Slap] intensity=\(String(format: "%.2f", event.intensity))")
    socketServer.send(event: DaemonEvent(
        type: "slap",
        intensity: event.intensity,
        action: nil
    ))
}

// ── Config from app (sensitivity / cooldown) ─────────────────────────
socketServer.onConfig = { sensitivity, cooldown in
    // UI scale 1-10 → internal 0.0-1.0
    let internalSensitivity = (sensitivity - 1) / 9.0
    slapDetector.sensitivity = Float(internalSensitivity)
    slapDetector.cooldown = Double(cooldown)
    print("[MaclaqueDaemon] Config updated: sensitivity=\(sensitivity) (internal=\(String(format: "%.2f", internalSensitivity))) cooldown=\(cooldown)")
}

// ── USB monitor ────────────────────────────────────────────────────────
let usbMonitor = USBMonitor()
usbMonitor.start { action in
    print("[USB] \(action.rawValue) — sending to app")
    socketServer.send(event: DaemonEvent(
        type: "usb",
        intensity: nil,
        action: action.rawValue
    ))
}
print("[MaclaqueDaemon] USBMonitor (power) started")

// ── Lid monitor ────────────────────────────────────────────────────────
let lidMonitor = LidMonitor()
lidMonitor.start { action in
    print("[Lid] \(action.rawValue) — sending to app")
    socketServer.send(event: DaemonEvent(
        type: "lid",
        intensity: nil,
        action: action.rawValue
    ))
}
print("[MaclaqueDaemon] LidMonitor started")

// ── Accelerometer ──────────────────────────────────────────────────────
let accelerometer = AccelerometerManager()

// ── Signal handling (graceful shutdown) ─────────────────────────────────
let sigSources: [DispatchSourceSignal] = [SIGTERM, SIGINT].map { sig in
    signal(sig, SIG_IGN) // Ignore default handler
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler {
        print("\n[MaclaqueDaemon] Signal reçu, arrêt propre...")
        accelerometer.stop()
        usbMonitor.stop()
        lidMonitor.stop()
        socketServer.stop()
        exit(0)
    }
    src.resume()
    return src
}

// Start accelerometer (feeds SlapDetector + LidMonitor)
var sampleCount = 0
accelerometer.start { x, y, z in
    slapDetector.processSample(x: x, y: y, z: z)
    lidMonitor.processSample(z: z)
    sampleCount += 1
    if sampleCount % 400 == 0 {
        print("[Accel] x=\(String(format: "%.6f", x)) y=\(String(format: "%.6f", y)) z=\(String(format: "%.6f", z))")
    }
}

if accelerometer.isRunning {
    print("[MaclaqueDaemon] Accéléromètre OK ✓")
} else {
    print("[MaclaqueDaemon] ⚠ Accéléromètre NON détecté !")
}

print("[MaclaqueDaemon] En écoute. Giflez votre Mac !")

// Keep main thread alive
dispatchMain()
