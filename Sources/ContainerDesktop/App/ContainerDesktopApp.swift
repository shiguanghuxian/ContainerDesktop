import AppKit
import SwiftUI

@main
enum ContainerDesktopMain {
    @MainActor private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private static let mainWindowTitle = "ContainerDesktop"

    private let runtimeStore = RuntimeStore()
    private let composeStore = ComposeProjectStore()
    private let systemConfigStore = SystemConfigStore()
    private let operationStore = AppOperationStore()
    private let appUpdateStore = AppUpdateStore()

    private var mainWindow: NSWindow?
    private var mainHostingController: NSHostingController<AnyView>?
    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<AnyView>?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusPopoverEventMonitor: Any?
    private var userDefaultsObserver: NSObjectProtocol?
    private var lastChromePreferences: AppChromePreferences?

    private var appearance: AppearancePreference {
        let rawValue = UserDefaults.standard.string(forKey: "containerdesktop.appearance")
            ?? AppearancePreference.system.rawValue
        return AppearancePreference(rawValue: rawValue) ?? .system
    }

    private var language: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: "containerdesktop.language")
            ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    private var selectedSection: AppSection {
        let rawValue = UserDefaults.standard.string(forKey: "containerdesktop.selected.section")
            ?? AppSection.dashboard.rawValue
        return AppSection(rawValue: rawValue) ?? .dashboard
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        configureMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ContainerDesktopMainWindow.configureOpenAction { [weak self] in
            self?.openMainWindow()
        }
        ContainerDesktopWindowRouter.configure(openSettings: { [weak self] in
            self?.openSettingsWindow()
        })
        lastChromePreferences = currentChromePreferences
        observeUserDefaults()
        configureStatusItem()
        openMainWindow()
        loadInitialData()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        ContainerDesktopMainMenuController.shared.reinstallMenuIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag == false else { return false }
        openMainWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        removeStatusPopoverEventMonitor()
    }

    private func openMainWindow() {
        if let mainWindow {
            refreshMainWindow()
            NSApp.activate(ignoringOtherApps: true)
            mainWindow.makeKeyAndOrderFront(nil)
            mainWindow.orderFrontRegardless()
            return
        }

        let hostingController = NSHostingController(rootView: mainRootView())
        hostingController.sizingOptions = []
        let window = NSWindow(contentViewController: hostingController)
        window.title = Self.mainWindowTitle
        window.identifier = ContainerDesktopMainWindow.identifier
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 1160, height: 760)
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.center()
        window.isReleasedWhenClosed = false
        applyMainWindowChrome(window)

        mainWindow = window
        mainHostingController = hostingController

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func openSettingsWindow() {
        if let settingsWindow {
            refreshSettingsWindow()
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            return
        }

        let hostingController = NSHostingController(rootView: settingsRootView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = language.t(.settings)
        window.identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.settings-window")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 1040, height: 720)
        window.setContentSize(NSSize(width: 1120, height: 780))
        window.center()
        window.isReleasedWhenClosed = false

        settingsWindow = window
        settingsHostingController = hostingController

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(toggleStatusPopover(_:))
        refreshStatusItem()
    }

    private func loadInitialData() {
        Task {
            operationStore.load()
            await runtimeStore.bootstrap()
            await composeStore.load()
            await composeStore.refreshVersion()
            await systemConfigStore.load()
            await appUpdateStore.checkForUpdatesIfNeededOnLaunch()
            refreshStatusItem()
        }
    }

    private func observeUserDefaults() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAppChromeIfNeeded()
            }
        }
    }

    private var currentChromePreferences: AppChromePreferences {
        AppChromePreferences(language: language, appearance: appearance)
    }

    private func refreshAppChromeIfNeeded() {
        let preferences = currentChromePreferences
        guard preferences != lastChromePreferences else { return }
        lastChromePreferences = preferences
        refreshAppChrome()
    }

    private func refreshAppChrome() {
        configureMainMenu()
        refreshMainWindow()
        refreshSettingsWindow()
        refreshStatusItem()
        if statusPopover?.isShown == true {
            refreshStatusPopover()
        }
    }

    private func configureMainMenu() {
        let snapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: language,
            selectedSection: selectedSection
        )
        ContainerDesktopMainMenuController.shared.configure(
            snapshot: snapshot,
            actions: ContainerDesktopMainMenuActions(
                openMain: { section in
                    UserDefaults.standard.set(section.rawValue, forKey: "containerdesktop.selected.section")
                    ContainerDesktopMainWindow.activateOrOpen()
                },
                openSettings: {
                    ContainerDesktopWindowRouter.openSettings()
                },
                checkForUpdates: {
                    UserDefaults.standard.set(AppSection.about.rawValue, forKey: "containerdesktop.selected.section")
                    ContainerDesktopMainWindow.activateOrOpen()
                    Task {
                        await self.appUpdateStore.checkForUpdates(isAutomatic: false)
                    }
                },
                reload: {
                    Task {
                        await self.runtimeStore.refreshAll()
                        await self.composeStore.reloadProjects()
                    }
                }
            )
        )
    }

    private func refreshMainWindow() {
        mainHostingController?.sizingOptions = []
        mainHostingController?.rootView = mainRootView()
        applyMainWindowChrome(mainWindow)
        applyAppearance(to: mainWindow)
    }

    private func refreshSettingsWindow() {
        settingsWindow?.title = language.t(.settings)
        settingsHostingController?.rootView = settingsRootView()
        applyAppearance(to: settingsWindow)
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: runtimeStore.menuBarIcon, accessibilityDescription: nil)
        button.title = statusItemTitle
    }

    private func refreshStatusPopover() {
        statusPopover?.contentViewController = NSHostingController(rootView: statusPopoverRootView())
    }

    private var statusItemTitle: String {
        if !runtimeStore.environment.containerAvailable {
            return language.resolved == .zhHans ? "CD 缺失" : "CD !"
        }
        if !runtimeStore.environment.systemRunning {
            return language.resolved == .zhHans ? "CD 停止" : "CD off"
        }
        if operationStore.activeCount > 0 {
            return "CD \(operationStore.activeCount)"
        }
        let runningContainers = runtimeStore.containers.filter { $0.state == "running" }.count
        return runningContainers > 0 ? "CD \(runningContainers)" : "CD"
    }

    private func mainRootView() -> AnyView {
        AnyView(
            ContentView(
                runtimeStore: runtimeStore,
                composeStore: composeStore,
                systemConfigStore: systemConfigStore,
                operationStore: operationStore,
                appUpdateStore: appUpdateStore
            )
            .environment(\.appLanguage, language)
            .preferredColorScheme(appearance.colorScheme)
        )
    }

    private func settingsRootView() -> AnyView {
        AnyView(
            SettingsView(systemConfigStore: systemConfigStore)
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        )
    }

    private func statusPopoverRootView() -> AnyView {
        AnyView(
            MenuBarStatusView(
                runtimeStore: runtimeStore,
                composeStore: composeStore,
                operationStore: operationStore
            )
            .environment(\.appLanguage, language)
            .preferredColorScheme(appearance.colorScheme)
        )
    }

    private func applyAppearance(to window: NSWindow?) {
        switch appearance {
        case .system:
            window?.appearance = nil
        case .light:
            window?.appearance = NSAppearance(named: .aqua)
        case .dark:
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func applyMainWindowChrome(_ window: NSWindow?) {
        guard let window else { return }
        window.title = ""
        window.setAccessibilityTitle(Self.mainWindowTitle)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.titlebarSeparatorStyle = .none
        window.toolbar = nil
    }

    @objc private func toggleStatusPopover(_ sender: NSStatusBarButton) {
        if statusPopover?.isShown == true {
            closeStatusPopover()
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 430, height: 640)
        popover.contentViewController = NSHostingController(rootView: statusPopoverRootView())
        statusPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        installStatusPopoverEventMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        removeStatusPopoverEventMonitor()
    }

    private func closeStatusPopover() {
        statusPopover?.performClose(nil)
        removeStatusPopoverEventMonitor()
    }

    private func installStatusPopoverEventMonitor() {
        removeStatusPopoverEventMonitor()
        statusPopoverEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.statusPopover?.isShown == true else { return }
                self?.closeStatusPopover()
            }
        }
    }

    private func removeStatusPopoverEventMonitor() {
        if let statusPopoverEventMonitor {
            NSEvent.removeMonitor(statusPopoverEventMonitor)
            self.statusPopoverEventMonitor = nil
        }
    }
}

private struct AppChromePreferences: Equatable {
    var language: AppLanguage
    var appearance: AppearancePreference
}
