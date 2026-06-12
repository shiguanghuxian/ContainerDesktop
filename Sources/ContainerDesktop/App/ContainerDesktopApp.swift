import AppKit
import SwiftUI

@main
struct ContainerDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    @State private var runtimeStore = RuntimeStore()
    @State private var composeStore = ComposeProjectStore()
    @State private var systemConfigStore = SystemConfigStore()
    @AppStorage("containerdesktop.appearance") private var appearanceRaw = AppearancePreference.system.rawValue
    @AppStorage("containerdesktop.language") private var languageRaw = AppLanguage.system.rawValue

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup("ContainerDesktop", id: "main") {
            ContentView(
                runtimeStore: runtimeStore,
                composeStore: composeStore,
                systemConfigStore: systemConfigStore
            )
            .environment(\.appLanguage, language)
            .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: 1440, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(language.t(.settings)) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window(language.t(.settings), id: "settings") {
            SettingsView(systemConfigStore: systemConfigStore)
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: 1120, height: 780)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            MenuBarStatusView(
                runtimeStore: runtimeStore,
                composeStore: composeStore
            )
            .environment(\.appLanguage, language)
        } label: {
            Label(runtimeStore.menuBarTitle, systemImage: runtimeStore.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
