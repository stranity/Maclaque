import Foundation
import Security

/// Installs MaclaqueDaemon as a LaunchDaemon using a system password prompt.
/// No Terminal needed — the user sees a standard macOS authorization dialog.
enum DaemonInstaller {

    static let daemonLabel = Constants.daemonLabel
    static let installPath = "/usr/local/bin/MaclaqueDaemon"
    static let plistInstallPath = "/Library/LaunchDaemons/\(Constants.daemonLabel).plist"

    /// Whether the daemon appears to be installed
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installPath) &&
        FileManager.default.fileExists(atPath: plistInstallPath)
    }

    /// Whether the daemon is currently loaded in launchd
    static var isLoaded: Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", daemonLabel]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Install and load the daemon. Shows a system password dialog.
    /// Returns nil on success, or an error message on failure.
    static func install() -> String? {
        // Find the daemon binary bundled with the app or in the build directory
        guard let daemonSource = findDaemonBinary() else {
            return "Impossible de trouver le daemon. Réinstallez Maclaque."
        }

        // Create the install script
        let plistContent = makePlistContent()
        let scriptPath = NSTemporaryDirectory() + "maclaque_install.sh"
        let script = """
        #!/bin/bash
        set -e

        # Stop existing daemon if running
        launchctl bootout system/\(daemonLabel) 2>/dev/null || true

        # Create /usr/local/bin if needed
        mkdir -p /usr/local/bin

        # Copy daemon binary
        cp "\(daemonSource)" "\(installPath)"
        chmod 755 "\(installPath)"

        # Write plist
        cat > "\(plistInstallPath)" << 'PLIST'
        \(plistContent)
        PLIST
        chmod 644 "\(plistInstallPath)"

        # Load daemon
        launchctl bootstrap system "\(plistInstallPath)"

        exit 0
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)
        } catch {
            return "Erreur d'écriture du script: \(error.localizedDescription)"
        }

        // Run with admin privileges via system authorization prompt
        return executeWithPrivileges(scriptPath)
    }

    /// Uninstall the daemon
    static func uninstall() -> String? {
        let scriptPath = NSTemporaryDirectory() + "maclaque_uninstall.sh"
        let script = """
        #!/bin/bash
        launchctl bootout system/\(daemonLabel) 2>/dev/null || true
        rm -f "\(installPath)"
        rm -f "\(plistInstallPath)"
        exit 0
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)
        } catch {
            return "Erreur: \(error.localizedDescription)"
        }

        return executeWithPrivileges(scriptPath)
    }

    // MARK: - Private

    private static func findDaemonBinary() -> String? {
        // 1. Check inside app bundle
        if let bundled = Bundle.main.path(forAuxiliaryExecutable: "MaclaqueDaemon") {
            return bundled
        }

        // 2. Check next to the app binary
        let appDir = Bundle.main.bundlePath
        let siblingPath = (appDir as NSString).deletingLastPathComponent + "/MaclaqueDaemon"
        if FileManager.default.fileExists(atPath: siblingPath) {
            return siblingPath
        }

        // 3. Check .build/debug (development)
        let execURL = Bundle.main.executableURL
        if let buildDir = execURL?.deletingLastPathComponent() {
            let debugPath = buildDir.appendingPathComponent("MaclaqueDaemon").path
            if FileManager.default.fileExists(atPath: debugPath) {
                return debugPath
            }
        }

        // 4. Already installed
        if FileManager.default.fileExists(atPath: installPath) {
            return installPath
        }

        return nil
    }

    private static func makePlistContent() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(installPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/var/log/maclaque.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/maclaque.log</string>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """
    }

    private static func executeWithPrivileges(_ scriptPath: String) -> String? {
        // Use osascript to trigger the system password dialog
        let escapedPath = scriptPath.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\\\"\(escapedPath)\\\"\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? FileManager.default.removeItem(atPath: scriptPath)
            return "Impossible de lancer l'autorisation: \(error.localizedDescription)"
        }

        // Clean up
        try? FileManager.default.removeItem(atPath: scriptPath)

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "Erreur inconnue"
            if errorMsg.contains("User canceled") || errorMsg.contains("-128") {
                return "Installation annulée."
            }
            return errorMsg.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil // success
    }
}
