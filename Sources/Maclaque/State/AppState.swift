import Foundation
import Combine

func debugLog(_ msg: String) {
    #if DEBUG
    let line = "[\(Date())] \(msg)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: "/tmp/maclaque_debug.log") {
            if let fh = FileHandle(forWritingAtPath: "/tmp/maclaque_debug.log") {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: "/tmp/maclaque_debug.log", contents: data)
        }
    }
    #endif
}

/// Central app state — ObservableObject for SwiftUI binding
final class AppState: ObservableObject {
    @Published var isActive: Bool {
        didSet { Preferences.shared.isActive = isActive }
    }
    @Published var currentPackId: String {
        didSet {
            Preferences.shared.currentPackId = currentPackId
            soundPackManager?.selectPack(currentPackId)
        }
    }
    @Published var sensitivity: Double {
        didSet {
            Preferences.shared.sensitivity = sensitivity
            sendConfigToDaemon()
        }
    }
    @Published var cooldown: Double {
        didSet {
            Preferences.shared.cooldown = cooldown
            sendConfigToDaemon()
        }
    }
    @Published var masterVolume: Double {
        didSet {
            Preferences.shared.masterVolume = masterVolume
            audioEngine.setMasterVolume(Float(masterVolume))
        }
    }
    @Published var totalSlaps: Int {
        didSet { Preferences.shared.totalSlaps = totalSlaps }
    }
    @Published var freeSlapsRemaining: Int {
        didSet { Preferences.shared.freeSlapsRemaining = freeSlapsRemaining }
    }
    @Published var isLicensed: Bool = false
    @Published var chargeSoundEnabled: Bool {
        didSet { Preferences.shared.chargeSoundEnabled = chargeSoundEnabled }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { Preferences.shared.hasCompletedOnboarding = hasCompletedOnboarding }
    }
    @Published var isDaemonConnected: Bool = false

    let audioEngine: AudioEngine
    var soundPackManager: SoundPackManager?
    private var socketClient: SocketClient?
    private let licenseManager = LicenseManager()

    init() {
        let prefs = Preferences.shared
        self.isActive = prefs.isActive
        self.currentPackId = prefs.currentPackId
        self.sensitivity = prefs.sensitivity
        self.cooldown = prefs.cooldown
        self.masterVolume = prefs.masterVolume
        self.totalSlaps = prefs.totalSlaps
        self.freeSlapsRemaining = prefs.freeSlapsRemaining
        self.chargeSoundEnabled = prefs.chargeSoundEnabled
        self.hasCompletedOnboarding = prefs.hasCompletedOnboarding

        self.audioEngine = AudioEngine()
        self.audioEngine.setMasterVolume(Float(masterVolume))

        let packManager = SoundPackManager(audioEngine: audioEngine)
        packManager.currentPackId = currentPackId
        self.soundPackManager = packManager

        // Check license
        self.isLicensed = licenseManager.isActivated

        // Connect to daemon
        connectToDaemon()
    }

    func connectToDaemon() {
        debugLog("[AppState] connectToDaemon called, socketPath=\(Constants.socketPath)")
        socketClient = SocketClient(socketPath: Constants.socketPath)
        socketClient?.onEvent = { [weak self] event in
            debugLog("[AppState] onEvent fired: \(event.type)")
            DispatchQueue.main.async {
                self?.handleDaemonEvent(event)
            }
        }
        socketClient?.onConnected = { [weak self] connected in
            debugLog("[AppState] onConnected: \(connected)")
            DispatchQueue.main.async {
                self?.isDaemonConnected = connected
                if connected {
                    self?.sendConfigToDaemon()
                }
            }
        }
        socketClient?.connect()
    }

    private func handleDaemonEvent(_ event: DaemonEvent) {
        debugLog("[AppState] Event received: type=\(event.type) intensity=\(event.intensity ?? -1) action=\(event.action ?? "nil")")
        guard isActive else { debugLog("[AppState] Not active, ignoring"); return }

        switch event.type {
        case "slap":
            guard let intensity = event.intensity else { debugLog("[AppState] No intensity"); return }

            // Check trial
            if !isLicensed {
                guard freeSlapsRemaining > 0 else { print("[AppState] No free slaps remaining"); return }
                freeSlapsRemaining -= 1
            }

            totalSlaps += 1
            debugLog("[AppState] Playing slap sound, intensity=\(intensity), pack=\(currentPackId), packs loaded=\(soundPackManager?.packs.count ?? 0)")
            soundPackManager?.playRandom(intensity: intensity)

        case "usb":
            guard chargeSoundEnabled else { return }
            let trigger = (event.action == "plug") ? "charge_plug" : "charge_unplug"
            let usbIntensity: Float = (event.action == "plug") ? 0.6 : 0.4
            soundPackManager?.playForEvent(trigger: trigger, intensity: usbIntensity)

        case "lid":
            let trigger = (event.action == "closed") ? "lid_close" : "lid_open"
            soundPackManager?.playForEvent(trigger: trigger, intensity: 0.5)

        default:
            break
        }
    }

    /// Push current sensitivity & cooldown to the daemon
    private func sendConfigToDaemon() {
        socketClient?.sendConfig(
            sensitivity: Float(sensitivity),
            cooldown: cooldown
        )
    }

    func activateLicense(_ key: String) async -> Bool {
        let success = await licenseManager.validate(licenseKey: key)
        await MainActor.run {
            isLicensed = success
        }
        return success
    }
}

/// Daemon event received via socket (mirrors daemon-side DaemonEvent)
struct DaemonEvent: Codable {
    let type: String
    let intensity: Float?
    let action: String?
}
