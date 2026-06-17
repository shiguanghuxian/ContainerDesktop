import AppKit
import SwiftUI

@main
enum ContainerDesktopMain {
    @MainActor private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        if DockerCommandShimCLI.runIfNeeded() {
            return
        }
        if DockerCompatibilityTerminalApplication.runIfNeeded() {
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private static let mainWindowTitle = AppBranding.displayName

    private let runtimeStore = RuntimeStore()
    private let composeStore = ComposeProjectStore()
    private let systemConfigStore = SystemConfigStore()
    private let operationStore = AppOperationStore()
    private let appUpdateStore = AppUpdateStore()
    private let statsHistoryStore = ContainerStatsHistoryStore()

    private var mainWindow: NSWindow?
    private var mainHostingController: NSHostingController<AnyView>?
    private var settingsWindow: NSWindow?
    private var settingsHostingController: NSHostingController<AnyView>?
    private var dockerCompatibilityTerminalWindow: NSWindow?
    private var dockerCompatibilityTerminalHostingController: NSHostingController<AnyView>?
    private var dockerCompatibilityTerminalTabsStore: DockerCompatibilityTerminalTabsStore?
    private var dockerCompatibilityTerminalStyleSettingsWindow: NSWindow?
    private var dockerCompatibilityTerminalStyleSettingsHostingController: NSHostingController<AnyView>?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var statusPopoverEventMonitor: Any?
    private var userDefaultsObserver: NSObjectProtocol?
    private var lastChromePreferences: AppChromePreferences?

    private var appearance: AppearancePreference {
        let rawValue = UserDefaults.containerDesktopShared.string(forKey: "containerdesktop.appearance")
            ?? AppearancePreference.system.rawValue
        return AppearancePreference(rawValue: rawValue) ?? .system
    }

    private var language: AppLanguage {
        let rawValue = UserDefaults.containerDesktopShared.string(forKey: "containerdesktop.language")
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
        NSApp.servicesProvider = self
        ContainerDesktopMainWindow.configureOpenAction { [weak self] in
            self?.openMainWindow()
        }
        ContainerDesktopWindowRouter.configure(
            openSettings: { [weak self] in
                self?.openSettingsWindow()
            },
            openDockerCompatibilityTerminal: { [weak self] in
                self?.openDockerCompatibilityTerminalAppOrWindow()
            },
            openDockerCompatibilityTerminalStyleSettings: { [weak self] in
                self?.openDockerCompatibilityTerminalStyleSettingsWindow()
            }
        )
        lastChromePreferences = currentChromePreferences
        observeUserDefaults()
        configureStatusItem()
        openMainWindow()
        loadInitialData()
        NSUpdateDynamicServices()
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
        statsHistoryStore.shutdown()
        dockerCompatibilityTerminalTabsStore?.stopAll()
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

    private func openDockerCompatibilityTerminalAppOrWindow(
        workingDirectory: URL = AppPaths.homeDirectory,
        addTabIfWindowExists: Bool = false
    ) {
        if DockerCompatibilityTerminalEmbeddedApp.open(workingDirectory: workingDirectory) {
            return
        }
        openDockerCompatibilityTerminalWindow(
            workingDirectory: workingDirectory,
            addTabIfWindowExists: addTabIfWindowExists
        )
    }

    private func openDockerCompatibilityTerminalWindow(
        workingDirectory: URL = AppPaths.homeDirectory,
        addTabIfWindowExists: Bool = false
    ) {
        if let dockerCompatibilityTerminalWindow {
            if let tabsStore = dockerCompatibilityTerminalTabsStore {
                if addTabIfWindowExists || tabsStore.tabs.isEmpty {
                    tabsStore.newTab(workingDirectory: workingDirectory)
                }
            } else {
                let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: workingDirectory)
                dockerCompatibilityTerminalTabsStore = tabsStore
                dockerCompatibilityTerminalHostingController?.rootView = dockerCompatibilityTerminalRootView(tabsStore: tabsStore)
            }
            refreshDockerCompatibilityTerminalWindow()
            NSApp.activate(ignoringOtherApps: true)
            dockerCompatibilityTerminalWindow.makeKeyAndOrderFront(nil)
            dockerCompatibilityTerminalWindow.orderFrontRegardless()
            return
        }

        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: workingDirectory)
        dockerCompatibilityTerminalTabsStore = tabsStore
        let hostingController = NSHostingController(rootView: dockerCompatibilityTerminalRootView(tabsStore: tabsStore))
        hostingController.sizingOptions = []
        let window = DockerCompatibilityTerminalWindow(contentViewController: hostingController)
        window.title = dockerCompatibilityTerminalWindowTitle
        window.identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.docker-compatibility-terminal-window")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 560)
        window.setContentSize(NSSize(width: 1180, height: 720))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        dockerCompatibilityTerminalWindow = window
        dockerCompatibilityTerminalHostingController = hostingController
        configureDockerCompatibilityTerminalTabKeyCommands(on: window)
        applyAppearance(to: window)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func openDockerCompatibilityTerminalStyleSettingsWindow() {
        if let dockerCompatibilityTerminalStyleSettingsWindow {
            refreshDockerCompatibilityTerminalStyleSettingsWindow()
            NSApp.activate(ignoringOtherApps: true)
            dockerCompatibilityTerminalStyleSettingsWindow.makeKeyAndOrderFront(nil)
            dockerCompatibilityTerminalStyleSettingsWindow.orderFrontRegardless()
            return
        }

        let hostingController = NSHostingController(rootView: dockerCompatibilityTerminalStyleSettingsRootView())
        hostingController.sizingOptions = []
        let window = NSWindow(contentViewController: hostingController)
        window.title = dockerCompatibilityTerminalStyleSettingsWindowTitle
        window.identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.docker-compatibility-terminal-style-settings-window")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 820, height: 520)
        window.setContentSize(NSSize(width: 860, height: 560))
        window.center()
        window.isReleasedWhenClosed = false

        dockerCompatibilityTerminalStyleSettingsWindow = window
        dockerCompatibilityTerminalStyleSettingsHostingController = hostingController
        applyAppearance(to: window)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(toggleStatusPopover(_:))
        refreshStatusItem()
    }

    private func loadInitialData() {
        Task {
            operationStore.load()
            statsHistoryStore.load()
            await runtimeStore.bootstrap()
            if runtimeStore.isReady {
                statsHistoryStore.startMonitoring(interval: 10)
            }
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
        refreshDockerCompatibilityTerminalWindow()
        refreshDockerCompatibilityTerminalStyleSettingsWindow()
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
                openDockerCompatibilityTerminal: {
                    self.openDockerCompatibilityTerminalAppOrWindow()
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

    private func refreshDockerCompatibilityTerminalWindow() {
        dockerCompatibilityTerminalWindow?.title = dockerCompatibilityTerminalWindowTitle
        if let tabsStore = dockerCompatibilityTerminalTabsStore {
            dockerCompatibilityTerminalHostingController?.rootView = dockerCompatibilityTerminalRootView(tabsStore: tabsStore)
        }
        applyAppearance(to: dockerCompatibilityTerminalWindow)
    }

    private func refreshDockerCompatibilityTerminalStyleSettingsWindow() {
        dockerCompatibilityTerminalStyleSettingsWindow?.title = dockerCompatibilityTerminalStyleSettingsWindowTitle
        dockerCompatibilityTerminalStyleSettingsHostingController?.rootView = dockerCompatibilityTerminalStyleSettingsRootView()
        applyAppearance(to: dockerCompatibilityTerminalStyleSettingsWindow)
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        statusItem?.length = NSStatusItem.squareLength
        let description = statusItemDescription
        let configuration = NSImage.SymbolConfiguration(pointSize: 18.5, weight: .semibold)
        let image = NSImage(systemSymbolName: runtimeStore.menuBarIcon, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.toolTip = description
        button.setAccessibilityLabel(description)
    }

    private func refreshStatusPopover() {
        statusPopover?.contentViewController = NSHostingController(rootView: statusPopoverRootView())
    }

    private var statusItemDescription: String {
        let name = AppBranding.displayName
        if !runtimeStore.environment.containerAvailable {
            return language.resolved == .zhHans ? "\(name)：container CLI 缺失" : "\(name): container CLI missing"
        }
        if !runtimeStore.environment.systemRunning {
            return language.resolved == .zhHans ? "\(name)：container system 未运行" : "\(name): container system stopped"
        }
        if operationStore.activeCount > 0 {
            return language.resolved == .zhHans ? "\(name)：\(operationStore.activeCount) 个任务运行中" : "\(name): \(operationStore.activeCount) tasks running"
        }
        let runningContainers = runtimeStore.containers.filter { $0.state == "running" }.count
        return language.resolved == .zhHans ? "\(name)：\(runningContainers) 个容器运行中" : "\(name): \(runningContainers) containers running"
    }

    private func mainRootView() -> AnyView {
        AnyView(
            ContentView(
                runtimeStore: runtimeStore,
                composeStore: composeStore,
                systemConfigStore: systemConfigStore,
                operationStore: operationStore,
                appUpdateStore: appUpdateStore,
                statsHistoryStore: statsHistoryStore
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

    private func dockerCompatibilityTerminalRootView(tabsStore: DockerCompatibilityTerminalTabsStore) -> AnyView {
        AnyView(
            DockerCompatibilityTerminalTabsView(
                tabsStore: tabsStore,
                onOpenStyleSettings: {
                    ContainerDesktopWindowRouter.openDockerCompatibilityTerminalStyleSettings()
                },
                onCloseWindow: { [weak self] in
                    self?.dockerCompatibilityTerminalWindow?.performClose(nil)
                }
            )
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        )
    }

    private var dockerCompatibilityTerminalWindowTitle: String {
        DockerCompatibilityTerminalStrings.windowTitle(language)
    }

    private func dockerCompatibilityTerminalStyleSettingsRootView() -> AnyView {
        AnyView(
            DockerCompatibilityTerminalSettingsView()
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        )
    }

    private var dockerCompatibilityTerminalStyleSettingsWindowTitle: String {
        DockerCompatibilityTerminalStrings.settingsWindowTitle(language)
    }

    private func configureDockerCompatibilityTerminalTabKeyCommands(on window: DockerCompatibilityTerminalWindow) {
        window.onNewTab = { [weak self] in
            self?.newDockerCompatibilityTerminalTab()
        }
        window.onCloseTab = { [weak self] in
            self?.closeSelectedDockerCompatibilityTerminalTab()
        }
        window.onSelectNextTab = { [weak self] in
            self?.dockerCompatibilityTerminalTabsStore?.selectNextTab()
        }
        window.onSelectPreviousTab = { [weak self] in
            self?.dockerCompatibilityTerminalTabsStore?.selectPreviousTab()
        }
    }

    private func newDockerCompatibilityTerminalTab() {
        if let tabsStore = dockerCompatibilityTerminalTabsStore {
            tabsStore.newTab()
            return
        }
        openDockerCompatibilityTerminalWindow()
    }

    private func closeSelectedDockerCompatibilityTerminalTab() {
        guard let tabsStore = dockerCompatibilityTerminalTabsStore else {
            dockerCompatibilityTerminalWindow?.performClose(nil)
            return
        }
        if tabsStore.closeSelectedTab() == .closedLastTab {
            dockerCompatibilityTerminalWindow?.performClose(nil)
        }
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
        popover.contentSize = NSSize(width: 380, height: 460)
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

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === dockerCompatibilityTerminalWindow
        else {
            return
        }
        dockerCompatibilityTerminalTabsStore?.stopAll()
        dockerCompatibilityTerminalTabsStore = nil
        dockerCompatibilityTerminalHostingController = nil
        dockerCompatibilityTerminalWindow = nil
    }

    @objc func openDockerCompatibilityTerminal(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let workingDirectory = DockerCompatibilityTerminalServiceRequest.workingDirectory(from: pasteboard) else {
            error.pointee = DockerCompatibilityTerminalStrings.invalidServiceSelection(language) as NSString
            return
        }
        openDockerCompatibilityTerminalAppOrWindow(
            workingDirectory: workingDirectory,
            addTabIfWindowExists: true
        )
    }
}

private struct AppChromePreferences: Equatable {
    var language: AppLanguage
    var appearance: AppearancePreference
}
