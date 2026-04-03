import SwiftUI

@main
struct MaclaqueApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Menu bar app — no dock icon
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    if !appState.hasCompletedOnboarding {
                        openWindow(id: "onboarding")
                    }
                }
        } label: {
            Image(systemName: "hand.raised.fill")
        }
        .menuBarExtraStyle(.window)

        // Onboarding window
        WindowGroup("Maclaque", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 560)

        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
