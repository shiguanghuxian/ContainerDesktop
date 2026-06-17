import AppKit
import SwiftUI

struct DockerCompatibilityTerminalLaunchOptions: Equatable {
    var workingDirectory: URL
}

@MainActor
enum DockerCompatibilityTerminalApplication {
    static let argumentFlag = "--docker-compatibility-terminal-app"
    static let workingDirectoryFlag = "--working-directory"
    static let bundleIdentifier = "\(AppPaths.bundleIdentifier).DockerCompatibilityTerminal"
    static let executableName = "DockerCompatibilityTerminal"

    private static var appDelegate: DockerCompatibilityTerminalAppDelegate?

    static func runIfNeeded(arguments: [String] = CommandLine.arguments) -> Bool {
        guard let options = launchOptions(arguments: arguments, isStandaloneApp: isStandaloneLaunch(arguments: arguments)) else {
            return false
        }

        let app = NSApplication.shared
        let delegate = DockerCompatibilityTerminalAppDelegate(options: options)
        appDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        return true
    }

    static func launchOptions(arguments: [String]) -> DockerCompatibilityTerminalLaunchOptions? {
        launchOptions(arguments: arguments, isStandaloneApp: false)
    }

    nonisolated static func embeddedMainApplicationURL(for terminalBundleURL: URL) -> URL? {
        let appURL = terminalBundleURL.standardizedFileURL
        guard appURL.pathExtension == "app" else { return nil }

        let applicationsURL = appURL.deletingLastPathComponent()
        guard applicationsURL.lastPathComponent == "Applications" else { return nil }

        let contentsURL = applicationsURL.deletingLastPathComponent()
        guard contentsURL.lastPathComponent == "Contents" else { return nil }

        let mainAppURL = contentsURL.deletingLastPathComponent()
        guard mainAppURL.pathExtension == "app" else { return nil }
        return mainAppURL
    }

    static func launchOptions(
        arguments: [String],
        isStandaloneApp: Bool
    ) -> DockerCompatibilityTerminalLaunchOptions? {
        let startIndex: Int
        if let flagIndex = arguments.firstIndex(of: argumentFlag) {
            startIndex = flagIndex + 1
        } else if isStandaloneApp {
            startIndex = 1
        } else {
            return nil
        }

        var workingDirectory = AppPaths.homeDirectory
        var index = startIndex
        while index < arguments.count {
            let argument = arguments[index]
            if argument == workingDirectoryFlag {
                let valueIndex = index + 1
                if valueIndex < arguments.count,
                   let directory = DockerCompatibilityTerminalServiceRequest.workingDirectory(fromPath: arguments[valueIndex]) {
                    workingDirectory = directory
                }
                index += 2
                continue
            }

            if !argument.hasPrefix("-"),
               let directory = DockerCompatibilityTerminalServiceRequest.workingDirectory(fromPath: argument) {
                workingDirectory = directory
            }
            index += 1
        }

        return DockerCompatibilityTerminalLaunchOptions(workingDirectory: workingDirectory)
    }

    private static func isStandaloneLaunch(arguments: [String]) -> Bool {
        if Bundle.main.bundleIdentifier == bundleIdentifier {
            return true
        }
        guard let executablePath = arguments.first else {
            return false
        }
        return URL(fileURLWithPath: executablePath).lastPathComponent == executableName
    }
}

@MainActor
final class DockerCompatibilityTerminalAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?
    private var styleSettingsWindow: NSWindow?
    private var styleSettingsHostingController: NSHostingController<AnyView>?
    private var tabsStore: DockerCompatibilityTerminalTabsStore?
    private var launchOptions: DockerCompatibilityTerminalLaunchOptions
    private var userDefaultsObserver: NSObjectProtocol?
    private var openWorkingDirectoryObserver: NSObjectProtocol?
    private var lastChromePreferences: DockerCompatibilityTerminalChromePreferences?

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

    init(options: DockerCompatibilityTerminalLaunchOptions) {
        launchOptions = options
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        configureMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        lastChromePreferences = currentChromePreferences
        observeUserDefaults()
        observeOpenWorkingDirectoryRequests()
        openTerminalWindow(workingDirectory: launchOptions.workingDirectory)
        NSUpdateDynamicServices()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let workingDirectory = urls.compactMap(DockerCompatibilityTerminalServiceRequest.workingDirectory(fromFileURL:)).first else {
            return
        }
        openTerminalWindow(workingDirectory: workingDirectory, addTabIfWindowExists: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let userDefaultsObserver {
            NotificationCenter.default.removeObserver(userDefaultsObserver)
        }
        if let openWorkingDirectoryObserver {
            DistributedNotificationCenter.default().removeObserver(openWorkingDirectoryObserver)
        }
        tabsStore?.stopAll()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === window
        else {
            return
        }
        tabsStore?.stopAll()
        tabsStore = nil
        hostingController = nil
        window = nil
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
        openTerminalWindow(workingDirectory: workingDirectory, addTabIfWindowExists: true)
    }

    private func observeUserDefaults() {
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshChromeIfNeeded()
            }
        }
    }

    private func observeOpenWorkingDirectoryRequests() {
        openWorkingDirectoryObserver = DistributedNotificationCenter.default().addObserver(
            forName: DockerCompatibilityTerminalEmbeddedApp.openWorkingDirectoryNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let path = notification.userInfo?[DockerCompatibilityTerminalEmbeddedApp.workingDirectoryUserInfoKey] as? String
            Task { @MainActor [weak self, path] in
                guard let path,
                      let workingDirectory = DockerCompatibilityTerminalServiceRequest.workingDirectory(fromPath: path)
                else {
                    return
                }
                self?.openTerminalWindow(workingDirectory: workingDirectory, addTabIfWindowExists: true)
            }
        }
    }

    private var currentChromePreferences: DockerCompatibilityTerminalChromePreferences {
        DockerCompatibilityTerminalChromePreferences(language: language, appearance: appearance)
    }

    private func refreshChromeIfNeeded() {
        let preferences = currentChromePreferences
        guard preferences != lastChromePreferences else { return }
        lastChromePreferences = preferences
        configureMainMenu()
        refreshWindow()
    }

    private func openTerminalWindow(workingDirectory: URL, addTabIfWindowExists: Bool = false) {
        if let window {
            if let tabsStore {
                if addTabIfWindowExists || tabsStore.tabs.isEmpty {
                    tabsStore.newTab(workingDirectory: workingDirectory)
                }
            } else {
                let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: workingDirectory)
                self.tabsStore = tabsStore
                hostingController?.rootView = rootView(tabsStore: tabsStore)
            }
            refreshWindow()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: workingDirectory)
        self.tabsStore = tabsStore
        let hostingController = NSHostingController(rootView: rootView(tabsStore: tabsStore))
        hostingController.sizingOptions = []
        let window = DockerCompatibilityTerminalWindow(contentViewController: hostingController)
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.docker-compatibility-terminal-standalone-window")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 900, height: 560)
        window.setContentSize(NSSize(width: 1180, height: 720))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        self.window = window
        self.hostingController = hostingController
        configureTabKeyCommands(on: window)
        applyAppearance(to: window)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func refreshWindow() {
        window?.title = title
        if let tabsStore {
            hostingController?.rootView = rootView(tabsStore: tabsStore)
        }
        applyAppearance(to: window)
        refreshStyleSettingsWindow()
    }

    private func rootView(tabsStore: DockerCompatibilityTerminalTabsStore) -> AnyView {
        AnyView(
            DockerCompatibilityTerminalTabsView(
                tabsStore: tabsStore,
                onOpenStyleSettings: { [weak self] in
                    self?.openStyleSettingsWindow()
                },
                onCloseWindow: { [weak self] in
                    self?.window?.performClose(nil)
                }
            )
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        )
    }

    private func configureTabKeyCommands(on window: DockerCompatibilityTerminalWindow) {
        window.onNewTab = { [weak self] in
            self?.newDockerCompatibilityTerminalTab(nil)
        }
        window.onCloseTab = { [weak self] in
            self?.closeSelectedDockerCompatibilityTerminalTab(nil)
        }
        window.onSelectNextTab = { [weak self] in
            self?.selectNextDockerCompatibilityTerminalTab(nil)
        }
        window.onSelectPreviousTab = { [weak self] in
            self?.selectPreviousDockerCompatibilityTerminalTab(nil)
        }
    }

    @objc private func newDockerCompatibilityTerminalTab(_ sender: Any?) {
        if let tabsStore {
            tabsStore.newTab()
            return
        }
        openTerminalWindow(workingDirectory: AppPaths.homeDirectory)
    }

    @objc private func closeSelectedDockerCompatibilityTerminalTab(_ sender: Any?) {
        guard let tabsStore else {
            window?.performClose(sender)
            return
        }
        if tabsStore.closeSelectedTab() == .closedLastTab {
            window?.performClose(sender)
        }
    }

    @objc private func selectNextDockerCompatibilityTerminalTab(_ sender: Any?) {
        tabsStore?.selectNextTab()
    }

    @objc private func selectPreviousDockerCompatibilityTerminalTab(_ sender: Any?) {
        tabsStore?.selectPreviousTab()
    }

    private var title: String {
        DockerCompatibilityTerminalStrings.windowTitle(language)
    }

    private var styleSettingsTitle: String {
        DockerCompatibilityTerminalStrings.settingsWindowTitle(language)
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

    @objc private func openMainApplication(_ sender: NSMenuItem) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        if let embeddedMainAppURL = DockerCompatibilityTerminalApplication.embeddedMainApplicationURL(for: Bundle.main.bundleURL),
           FileManager.default.fileExists(atPath: embeddedMainAppURL.path) {
            NSWorkspace.shared.openApplication(at: embeddedMainAppURL, configuration: configuration)
            return
        }

        if let installedMainAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppPaths.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: installedMainAppURL, configuration: configuration)
        }
    }

    @objc private func openStyleSettingsWindow(_ sender: NSMenuItem) {
        openStyleSettingsWindow()
    }

    private func openStyleSettingsWindow() {
        if let styleSettingsWindow {
            refreshStyleSettingsWindow()
            NSApp.activate(ignoringOtherApps: true)
            styleSettingsWindow.makeKeyAndOrderFront(nil)
            styleSettingsWindow.orderFrontRegardless()
            return
        }

        let hostingController = NSHostingController(rootView: styleSettingsRootView())
        hostingController.sizingOptions = []
        let window = NSWindow(contentViewController: hostingController)
        window.title = styleSettingsTitle
        window.identifier = NSUserInterfaceItemIdentifier("io.shiguanghuxian.containerdesktop.docker-compatibility-terminal-standalone-style-settings-window")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 820, height: 520)
        window.setContentSize(NSSize(width: 860, height: 560))
        window.center()
        window.isReleasedWhenClosed = false

        styleSettingsWindow = window
        styleSettingsHostingController = hostingController
        applyAppearance(to: window)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func refreshStyleSettingsWindow() {
        styleSettingsWindow?.title = styleSettingsTitle
        styleSettingsHostingController?.rootView = styleSettingsRootView()
        applyAppearance(to: styleSettingsWindow)
    }

    private func styleSettingsRootView() -> AnyView {
        AnyView(
            DockerCompatibilityTerminalSettingsView()
                .environment(\.appLanguage, language)
                .preferredColorScheme(appearance.colorScheme)
        )
    }

    private func configureMainMenu() {
        let menu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let openMainItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.openMainApp(language),
            action: #selector(openMainApplication(_:)),
            keyEquivalent: ""
        )
        openMainItem.target = self
        appMenu.addItem(openMainItem)

        let styleSettingsItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.settingsMenuTitle(language),
            action: #selector(openStyleSettingsWindow(_:)),
            keyEquivalent: ","
        )
        styleSettingsItem.target = self
        appMenu.addItem(styleSettingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            NSMenuItem(
                title: DockerCompatibilityTerminalStrings.quitTitle(language),
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        menu.addItem(appMenuItem)

        let shellMenuItem = NSMenuItem()
        let shellMenu = NSMenu(title: DockerCompatibilityTerminalStrings.shellMenuTitle(language))
        let newTabItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.newTab(language),
            action: #selector(newDockerCompatibilityTerminalTab(_:)),
            keyEquivalent: "t"
        )
        newTabItem.target = self
        shellMenu.addItem(newTabItem)

        let closeTabItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.closeTab(language),
            action: #selector(closeSelectedDockerCompatibilityTerminalTab(_:)),
            keyEquivalent: "w"
        )
        closeTabItem.target = self
        shellMenu.addItem(closeTabItem)
        shellMenu.addItem(.separator())

        let nextTabItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.nextTab(language),
            action: #selector(selectNextDockerCompatibilityTerminalTab(_:)),
            keyEquivalent: "]"
        )
        nextTabItem.target = self
        nextTabItem.keyEquivalentModifierMask = [.command, .shift]
        shellMenu.addItem(nextTabItem)

        let previousTabItem = NSMenuItem(
            title: DockerCompatibilityTerminalStrings.previousTab(language),
            action: #selector(selectPreviousDockerCompatibilityTerminalTab(_:)),
            keyEquivalent: "["
        )
        previousTabItem.target = self
        previousTabItem.keyEquivalentModifierMask = [.command, .shift]
        shellMenu.addItem(previousTabItem)
        shellMenuItem.submenu = shellMenu
        menu.addItem(shellMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: DockerCompatibilityTerminalStrings.editMenuTitle(language))
        editMenu.addItem(NSMenuItem(title: DockerCompatibilityTerminalStrings.copy(language), action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: DockerCompatibilityTerminalStrings.paste(language), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: DockerCompatibilityTerminalStrings.selectAll(language), action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        menu.addItem(editMenuItem)

        NSApp.mainMenu = menu
    }
}

private struct DockerCompatibilityTerminalChromePreferences: Equatable {
    var language: AppLanguage
    var appearance: AppearancePreference
}
