import ServiceManagement
import Foundation

/// Manages launch-at-login registration via SMAppService (macOS 13+)
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                debugLog("[LaunchAtLogin] Error: \(error)")
            }
        }
    }
}
