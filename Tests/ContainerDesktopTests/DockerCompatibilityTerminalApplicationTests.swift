import AppKit
import Foundation
import SwiftTerm
import Testing
@testable import ContainerDesktop

@Suite("Docker compatibility terminal app", .serialized)
struct DockerCompatibilityTerminalApplicationTests {
    @MainActor
    @Test("launch options resolve file arguments to their parent directory")
    func launchOptionsResolveWorkingDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let projectDirectory = directory.appending(path: "Project", directoryHint: .isDirectory)
        let scriptURL = projectDirectory.appending(path: "build.sh")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: scriptURL, atomically: true, encoding: .utf8)

        let options = DockerCompatibilityTerminalApplication.launchOptions(arguments: [
            "ContainerDesktop",
            DockerCompatibilityTerminalApplication.argumentFlag,
            DockerCompatibilityTerminalApplication.workingDirectoryFlag,
            scriptURL.path,
        ])

        #expect(options?.workingDirectory == projectDirectory.standardizedFileURL)
    }

    @MainActor
    @Test("standalone app launch accepts working directory without compatibility flag")
    func standaloneLaunchAcceptsWorkingDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let options = DockerCompatibilityTerminalApplication.launchOptions(
            arguments: [
                "/Applications/Docker Compatibility Terminal.app/Contents/MacOS/DockerCompatibilityTerminal",
                DockerCompatibilityTerminalApplication.workingDirectoryFlag,
                directory.path,
            ],
            isStandaloneApp: true
        )

        #expect(options?.workingDirectory == directory.standardizedFileURL)
    }

    @MainActor
    @Test("launch options resolve structured shell targets")
    func launchOptionsResolveStructuredShellTargets() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let options = DockerCompatibilityTerminalApplication.launchOptions(arguments: [
            "ContainerDesktop",
            DockerCompatibilityTerminalApplication.argumentFlag,
            DockerCompatibilityTerminalApplication.workingDirectoryFlag,
            directory.path,
            DockerCompatibilityTerminalApplication.shellTargetKindFlag,
            "container",
            DockerCompatibilityTerminalApplication.shellTargetIDFlag,
            "web-1",
        ])

        #expect(options?.workingDirectory == directory.standardizedFileURL)
        #expect(options?.shellTarget == .container(id: "web-1"))
        #expect(DockerCompatibilityTerminalApplication.launchArguments(for: DockerCompatibilityTerminalOpenRequest(
            workingDirectory: directory,
            shellTarget: .machine(id: "dev-machine")
        )) == [
            DockerCompatibilityTerminalApplication.workingDirectoryFlag,
            directory.standardizedFileURL.path,
            DockerCompatibilityTerminalApplication.shellTargetKindFlag,
            "machine",
            DockerCompatibilityTerminalApplication.shellTargetIDFlag,
            "dev-machine",
        ])
    }

    @MainActor
    @Test("embedded app notifications carry structured shell targets")
    func embeddedAppNotificationsCarryStructuredShellTargets() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let request = DockerCompatibilityTerminalEmbeddedApp.openRequest(from: [
            DockerCompatibilityTerminalEmbeddedApp.workingDirectoryUserInfoKey: directory.path,
            DockerCompatibilityTerminalEmbeddedApp.shellTargetKindUserInfoKey: "machine",
            DockerCompatibilityTerminalEmbeddedApp.shellTargetIDUserInfoKey: "dev-machine",
        ])

        #expect(request?.workingDirectory == directory.standardizedFileURL)
        #expect(request?.shellTarget == .machine(id: "dev-machine"))
    }

    @Test("terminal style preference falls back to default")
    func terminalStylePreferenceFallsBackToDefault() {
        let suiteName = "ContainerDesktopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(DockerCompatibilityTerminalStyle.stored(in: defaults) == .defaultStyle)

        defaults.set(DockerCompatibilityTerminalStyle.amber.rawValue, forKey: DockerCompatibilityTerminalStyle.defaultsKey)
        #expect(DockerCompatibilityTerminalStyle.stored(in: defaults) == .amber)

        defaults.set("missing-style", forKey: DockerCompatibilityTerminalStyle.defaultsKey)
        #expect(DockerCompatibilityTerminalStyle.stored(in: defaults) == .defaultStyle)
    }

    @Test("terminal history settings default and clamp output event limit")
    func terminalHistorySettingsDefaultAndClampOutputEventLimit() {
        let suiteName = "ContainerDesktopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(DockerCompatibilityTerminalHistorySettings.storedOutputEventLimit(in: defaults) == 8_000)

        defaults.set(500, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        #expect(DockerCompatibilityTerminalHistorySettings.storedOutputEventLimit(in: defaults) == 1_000)

        defaults.set(80_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        #expect(DockerCompatibilityTerminalHistorySettings.storedOutputEventLimit(in: defaults) == 50_000)

        defaults.set(12_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        #expect(DockerCompatibilityTerminalHistorySettings.storedOutputEventLimit(in: defaults) == 12_000)
    }

    @Test("terminal current directory resolver parses OSC 7 file URLs")
    func terminalCurrentDirectoryResolverParsesOSC7FileURLs() {
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: "file:///Users/a/frontend")?.path == "/Users/a/frontend")
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: "file://host/Users/a/My%20Project")?.path == "/Users/a/My Project")
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: nil) == nil)
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: "") == nil)
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: "https://example.com/Users/a/frontend") == nil)
        #expect(TerminalCurrentDirectoryResolver.localDirectoryURL(from: "not a url") == nil)
    }

    @Test("standalone terminal resolves containing main application")
    func standaloneTerminalResolvesContainingMainApplication() {
        let terminalURL = URL(fileURLWithPath: "/tmp/ContainerDesktop.app/Contents/Applications/Docker Compatibility Terminal.app")
        let mainURL = DockerCompatibilityTerminalApplication.embeddedMainApplicationURL(for: terminalURL)

        #expect(mainURL?.path == "/tmp/ContainerDesktop.app")
    }

    @MainActor
    @Test("standalone app menu exposes main app terminal settings and tab commands")
    func standaloneAppMenuExposesMainAppTerminalSettingsAndTabCommands() {
        let application = NSApplication.shared
        let originalMainMenu = application.mainMenu
        let originalLanguage = UserDefaults.containerDesktopShared.string(forKey: "containerdesktop.language")
        UserDefaults.containerDesktopShared.set(AppLanguage.zhHans.rawValue, forKey: "containerdesktop.language")
        let delegate = DockerCompatibilityTerminalAppDelegate(
            options: DockerCompatibilityTerminalLaunchOptions(workingDirectory: AppPaths.homeDirectory)
        )

        defer {
            if let originalLanguage {
                UserDefaults.containerDesktopShared.set(originalLanguage, forKey: "containerdesktop.language")
            } else {
                UserDefaults.containerDesktopShared.removeObject(forKey: "containerdesktop.language")
            }
            application.mainMenu = originalMainMenu
        }

        delegate.applicationWillFinishLaunching(
            Notification(name: NSApplication.willFinishLaunchingNotification)
        )

        let appMenuTitles = application.mainMenu?.items.first?.submenu?.items.map(\.title)
        #expect(appMenuTitles?.contains("打开主应用") == true)
        #expect(appMenuTitles?.contains("终端设置…") == true)
        #expect(application.mainMenu?.items.first?.submenu?.items.first { $0.title == "打开主应用" }?.target === delegate)
        #expect(application.mainMenu?.items.first?.submenu?.items.first { $0.title == "终端设置…" }?.target === delegate)
        #expect(application.mainMenu?.items.count == 3)
        #expect(application.mainMenu?.items[1].submenu?.title == "Shell")
        #expect(application.mainMenu?.items[2].submenu?.title == "编辑")

        let shellMenuItems = application.mainMenu?.items[1].submenu?.items
        #expect(shellMenuItems?.filter { !$0.isSeparatorItem }.map(\.title) == ["新建 Tab", "关闭 Tab", "下一个 Tab", "上一个 Tab"])
        #expect(shellMenuItems?.first { $0.title == "新建 Tab" }?.keyEquivalent == "t")
        #expect(shellMenuItems?.first { $0.title == "关闭 Tab" }?.keyEquivalent == "w")
        #expect(shellMenuItems?.first { $0.title == "下一个 Tab" }?.keyEquivalent == "]")
        #expect(shellMenuItems?.first { $0.title == "下一个 Tab" }?.keyEquivalentModifierMask == [.command, .shift])
        #expect(shellMenuItems?.first { $0.title == "上一个 Tab" }?.keyEquivalent == "[")
        #expect(shellMenuItems?.first { $0.title == "上一个 Tab" }?.keyEquivalentModifierMask == [.command, .shift])

        UserDefaults.containerDesktopShared.set(AppLanguage.en.rawValue, forKey: "containerdesktop.language")
        delegate.applicationWillFinishLaunching(
            Notification(name: NSApplication.willFinishLaunchingNotification)
        )

        let englishAppMenuTitles = application.mainMenu?.items.first?.submenu?.items.map(\.title)
        #expect(englishAppMenuTitles?.contains("Open Main App") == true)
        #expect(englishAppMenuTitles?.contains("Terminal Settings...") == true)
        #expect(application.mainMenu?.items.first?.submenu?.items.first { $0.title == "Terminal Settings..." }?.target === delegate)
        #expect(application.mainMenu?.items[1].submenu?.title == "Shell")
        #expect(application.mainMenu?.items[1].submenu?.items.filter { !$0.isSeparatorItem }.map(\.title) == ["New Tab", "Close Tab", "Next Tab", "Previous Tab"])
        #expect(application.mainMenu?.items[2].submenu?.title == "Edit")
    }

    @MainActor
    @Test("terminal strings localize for both languages")
    func terminalStringsLocalizeForBothLanguages() {
        #expect(DockerCompatibilityTerminalStrings.settingsWindowTitle(.zhHans) == "终端设置")
        #expect(DockerCompatibilityTerminalStrings.settingsWindowTitle(.en) == "Terminal Settings")
        #expect(DockerCompatibilityTerminalStrings.settingsHeaderSubtitle(.zhHans) == "调整终端语言、系统终端打开方式、输出缓存和外观。")
        #expect(DockerCompatibilityTerminalStrings.settingsHeaderSubtitle(.en) == "Adjust the terminal language, system terminal app, output buffer, and appearance.")
        #expect(DockerCompatibilityTerminalStrings.settingsMenuTitle(.zhHans) == "终端设置…")
        #expect(DockerCompatibilityTerminalStrings.settingsMenuTitle(.en) == "Terminal Settings...")
        #expect(DockerCompatibilityTerminalStrings.openTerminalHelp(.zhHans) == "打开 Docker 兼容终端")
        #expect(DockerCompatibilityTerminalStrings.openTerminalHelp(.en) == "Open Docker compatibility terminal")
        #expect(DockerCompatibilityTerminalStrings.openTerminalMenu(.zhHans) == "打开终端")
        #expect(DockerCompatibilityTerminalStrings.openTerminalMenu(.en) == "Open terminal")
        #expect(DockerCompatibilityTerminalStrings.systemTerminalTitle(.zhHans) == "系统终端")
        #expect(DockerCompatibilityTerminalStrings.compatibleSystemTerminalTitle(.zhHans) == "兼容系统终端")
        #expect(DockerCompatibilityTerminalStrings.compatibleSystemTerminalTitle(.en) == "Compatible System Terminal")
        #expect(DockerCompatibilityTerminalStrings.systemTerminalOpenWith(.zhHans) == "打开方式")
        #expect(DockerCompatibilityTerminalStrings.systemDefaultTerminalApp(.en) == "System Default Terminal")
        #expect(DockerCompatibilityTerminalStrings.refreshTerminalApps(.zhHans) == "刷新终端列表")
        #expect(DockerCompatibilityTerminalStrings.noOtherTerminalAppsFound(.en).contains("No other terminal apps"))
        #expect(DockerCompatibilityTerminalStrings.openCompatibleSystemTerminal(.en) == "Open Compatible System Terminal")
        #expect(DockerCompatibilityTerminalStrings.outputBufferLinesTitle(.zhHans) == "输出缓存行数")
        #expect(DockerCompatibilityTerminalStrings.outputBufferLinesTitle(.en) == "Output buffer lines")
        #expect(DockerCompatibilityTerminalStrings.newTab(.zhHans) == "新建 Tab")
        #expect(DockerCompatibilityTerminalStrings.newTab(.en) == "New Tab")
        #expect(DockerCompatibilityTerminalStrings.closeTab(.zhHans) == "关闭 Tab")
        #expect(DockerCompatibilityTerminalStrings.closeTab(.en) == "Close Tab")
        #expect(ExternalTerminalDestination.systemTerminal.title(language: .zhHans) == "系统终端")
        #expect(ExternalTerminalDestination.dockerCompatibilityTerminal.title(language: .en) == "Docker Compatibility Terminal")
    }

    @MainActor
    @Test("terminal context menu localizes")
    func terminalContextMenuLocalizes() {
        let view = FocusableTerminalView(frame: .zero)
        let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!

        view.language = .zhHans
        let chineseMenu = view.menu(for: event)
        #expect(chineseMenu?.items.map(\.title) == ["复制", "粘贴", "全选"])

        view.language = .en
        let englishMenu = view.menu(for: event)
        #expect(englishMenu?.items.map(\.title) == ["Copy", "Paste", "Select All"])
    }

    @MainActor
    @Test("terminal context menu supports optional docker terminal actions")
    func terminalContextMenuSupportsOptionalDockerTerminalActions() {
        let event = NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
        var actionCount = 0
        let view = FocusableTerminalView(frame: .zero)

        #expect(view.menu(for: event)?.items.map(\.title).contains("New Tab") == false)

        view.language = .en
        view.contextMenuActions = [
            TerminalContextMenuAction(title: DockerCompatibilityTerminalStrings.newTab(.en)) {
                actionCount += 1
            },
        ]

        let menu = view.menu(for: event)
        #expect(menu?.items.filter { !$0.isSeparatorItem }.map(\.title) == ["New Tab", "Copy", "Paste", "Select All"])
        if let newTabItem = menu?.items.first(where: { $0.title == "New Tab" }),
           let action = newTabItem.action {
            NSApp.sendAction(action, to: newTabItem.target, from: newTabItem)
        }
        #expect(actionCount == 1)
    }

    @MainActor
    @Test("terminal control key mapper sends standard bytes")
    func terminalControlKeyMapperSendsStandardBytes() {
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("c", modifiers: .control)) == [0x03])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("D", modifiers: [.control, .shift])) == [0x04])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("z", modifiers: .control)) == [0x1A])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("\\", modifiers: .control)) == [0x1C])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("l", modifiers: .control)) == [0x0C])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("[", modifiers: .control)) == [0x1B])
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent(" ", modifiers: .control)) == [0x00])
        #expect(TerminalControlKeyMapper.isInterrupt(keyEvent("c", modifiers: .control)))
    }

    @MainActor
    @Test("terminal control key mapper leaves system shortcuts alone")
    func terminalControlKeyMapperLeavesSystemShortcutsAlone() {
        let leftArrow = String(UnicodeScalar(UInt32(NSLeftArrowFunctionKey))!)
        let rightArrow = String(UnicodeScalar(UInt32(NSRightArrowFunctionKey))!)

        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("c", modifiers: .command)) == nil)
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("c", modifiers: [.command, .control])) == nil)
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent("c", modifiers: [.option, .control])) == nil)
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent(leftArrow, modifiers: .control)) == nil)
        #expect(TerminalControlKeyMapper.controlBytes(for: keyEvent(rightArrow, modifiers: .control)) == nil)
    }

    @MainActor
    @Test("terminal view key equivalent sends Control-C byte")
    func terminalViewKeyEquivalentSendsControlCByte() {
        let view = FocusableTerminalView(frame: .zero)
        let delegate = RecordingTerminalDelegate()
        view.terminalDelegate = delegate

        #expect(view.performKeyEquivalent(with: keyEvent("c", modifiers: .control)))

        #expect(delegate.sentData == [Data([0x03])])
    }

    @MainActor
    @Test("terminal view coordinator reports current directory changes")
    func terminalViewCoordinatorReportsCurrentDirectoryChanges() {
        let terminalView = FocusableTerminalView(frame: .zero)
        var reportedDirectories: [String?] = []
        let coordinator = SwiftTermTerminalView.Coordinator(
            onInput: { _ in },
            onSizeChange: { _, _ in },
            onCurrentDirectoryChange: { directory in
                reportedDirectories.append(directory)
            }
        )

        coordinator.hostCurrentDirectoryUpdate(source: terminalView, directory: "file:///tmp")
        coordinator.hostCurrentDirectoryUpdate(source: terminalView, directory: nil)

        #expect(reportedDirectories == ["file:///tmp", nil])
    }

    @Test("terminal settings view exposes output buffer controls")
    func terminalSettingsViewExposesOutputBufferControls() throws {
        let source = try String(contentsOfFile: "Sources/ContainerDesktop/Views/DockerCompatibilityTerminal/DockerCompatibilityTerminalStyleSettingsView.swift", encoding: .utf8)
        let systemTerminalPanelSource = try String(contentsOfFile: "Sources/ContainerDesktop/Views/Common/SystemTerminalSettingsPanel.swift", encoding: .utf8)
        let preferencesSource = try String(contentsOfFile: "Sources/ContainerDesktop/Support/AppPreferences.swift", encoding: .utf8)

        #expect(source.contains("DockerCompatibilityTerminalSettingsSection"))
        #expect(source.contains("case language"))
        #expect(source.contains("case systemTerminal"))
        #expect(source.contains("case outputBuffer"))
        #expect(source.contains("case appearance"))
        #expect(source.contains("@State private var selectedSection"))
        #expect(source.contains("settingsSidebar"))
        #expect(source.contains("selectedSectionContent"))
        #expect(source.contains("SystemTerminalSettingsPanel()"))
        #expect(!source.contains("private var systemTerminalSettings"))
        #expect(systemTerminalPanelSource.contains("struct SystemTerminalSettingsPanel"))
        #expect(systemTerminalPanelSource.contains("systemTerminalAppSelection"))
        #expect(systemTerminalPanelSource.contains("SystemTerminalAppDiscovery"))
        #expect(systemTerminalPanelSource.contains("selectedSystemTerminalAppBundleID"))
        #expect(systemTerminalPanelSource.contains("SystemTerminalAppPreference.setSelectedBundleIdentifier"))
        #expect(systemTerminalPanelSource.contains("Picker("))
        #expect(systemTerminalPanelSource.contains("refreshSystemTerminalApps"))
        #expect(systemTerminalPanelSource.contains("DockerCompatibilitySystemTerminalIntegration"))
        #expect(systemTerminalPanelSource.contains("openCompatibleSystemTerminal"))
        #expect(systemTerminalPanelSource.contains("installSystemTerminalIntegration"))
        #expect(systemTerminalPanelSource.contains("uninstallSystemTerminalIntegration"))
        #expect(systemTerminalPanelSource.contains("copySystemTerminalShimPath"))
        #expect(source.contains("DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey"))
        #expect(source.contains("TextField("))
        #expect(source.contains("Stepper("))
        #expect(source.contains("outputBufferSettings"))
        #expect(preferencesSource.contains("containerdesktop.dockerCompatibilityTerminal.outputEventLimit"))
        #expect(preferencesSource.contains("containerdesktop.dockerCompatibilityTerminal.systemTerminalAppBundleID"))
    }

    @Test("system terminal compatibility script injects shim after user zshrc")
    func systemTerminalCompatibilityScriptInjectsShimAfterUserZshrc() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let shimDirectory = directory.appending(path: "bin", directoryHint: .isDirectory)
        let shellDirectory = directory.appending(path: "shell", directoryHint: .isDirectory)
        let workingDirectory = directory.appending(path: "Project", directoryHint: .isDirectory)
        let environment = DockerCompatibilityTerminalEnvironment(
            shimBinDirectory: shimDirectory,
            shellConfigDirectory: shellDirectory,
            shellPath: "/bin/zsh"
        )

        let script = SystemTerminalLauncher.dockerCompatibilityShellScript(
            workingDirectory: workingDirectory,
            environment: environment
        )

        #expect(script.contains("source \"$HOME/.zshrc\""))
        #expect(script.contains("CONTAINERDESKTOP_DOCKER_SHIM_BIN"))
        #expect(script.contains(shimDirectory.path))
        #expect(script.contains("export PATH=\"$CONTAINERDESKTOP_DOCKER_SHIM_BIN:$PATH\""))
        #expect(script.contains("cd \(ShellEscaper.singleQuoted(workingDirectory.standardizedFileURL.path))"))
        #expect(script.contains("ZDOTDIR=\"$session_zdotdir\" /bin/zsh -i"))
        #expect(script.contains("rm -rf \"$session_zdotdir\""))
    }

    @Test("system terminal app discovery includes default and sorts unique apps")
    func systemTerminalAppDiscoveryIncludesDefaultAndSortsUniqueApps() {
        let terminal = SystemTerminalApp(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal",
            appURL: URL(fileURLWithPath: "/Applications/Terminal.app"),
            isSystemDefault: false,
            isAvailable: true
        )
        let duplicateTerminal = SystemTerminalApp(
            bundleIdentifier: "com.apple.Terminal",
            displayName: "Terminal Duplicate",
            appURL: URL(fileURLWithPath: "/Applications/Utilities/Terminal.app"),
            isSystemDefault: false,
            isAvailable: true
        )
        let warp = SystemTerminalApp(
            bundleIdentifier: "dev.warp.Warp-Stable",
            displayName: "Warp",
            appURL: URL(fileURLWithPath: "/Applications/Warp.app"),
            isSystemDefault: false,
            isAvailable: true
        )
        let custom = SystemTerminalApp(
            bundleIdentifier: "com.example.Terminal",
            displayName: "Custom Terminal",
            appURL: URL(fileURLWithPath: "/Applications/Custom Terminal.app"),
            isSystemDefault: false,
            isAvailable: true
        )

        let apps = SystemTerminalAppDiscovery.normalized([custom, warp, duplicateTerminal, terminal])
        let terminalBundleCount = apps
            .compactMap(\.bundleIdentifier)
            .filter { $0 == "com.apple.Terminal" }
            .count
        let orderedBundleIdentifiers = apps.dropFirst().compactMap(\.bundleIdentifier)

        #expect(apps.first?.isSystemDefault == true)
        #expect(terminalBundleCount == 1)
        #expect(orderedBundleIdentifiers == ["com.apple.Terminal", "dev.warp.Warp-Stable", "com.example.Terminal"])
    }

    @Test("system terminal app preference stores and clears bundle identifier")
    func systemTerminalAppPreferenceStoresAndClearsBundleIdentifier() {
        let suiteName = "ContainerDesktopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        SystemTerminalAppPreference.setSelectedBundleIdentifier("com.googlecode.iterm2", in: defaults)
        #expect(SystemTerminalAppPreference.selectedBundleIdentifier(in: defaults) == "com.googlecode.iterm2")

        SystemTerminalAppPreference.setSelectedBundleIdentifier("", in: defaults)
        #expect(SystemTerminalAppPreference.selectedBundleIdentifier(in: defaults) == nil)
        #expect(defaults.object(forKey: SystemTerminalAppPreference.defaultsKey) == nil)
    }

    @Test("system terminal launcher and resource entries support selected app")
    func systemTerminalLauncherAndResourceEntriesSupportSelectedApp() throws {
        let launcherSource = try String(contentsOfFile: "Sources/ContainerDesktop/Support/SystemTerminalLauncher.swift", encoding: .utf8)
        let externalSource = try String(contentsOfFile: "Sources/ContainerDesktop/Support/ExternalTerminalLauncher.swift", encoding: .utf8)
        let appSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(launcherSource.contains("terminalApp: SystemTerminalApp? = nil"))
        #expect(launcherSource.contains("withApplicationAt: appURL"))
        #expect(launcherSource.contains("selectedTerminalUnavailable"))
        #expect(externalSource.contains("SystemTerminalAppPreference.selectedTerminalApp()"))
        #expect(appSource.contains("SystemTerminalAppPreference.selectedTerminalApp()"))
    }

    @Test("system terminal integration installs updates and uninstalls marker block")
    func systemTerminalIntegrationInstallsUpdatesAndUninstallsMarkerBlock() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let zshrcURL = directory.appending(path: ".zshrc")
        let backupURL = directory.appending(path: ".zshrc.backup")
        let integrationScriptURL = directory.appending(path: "shell-integration.zsh")
        let shimDirectory = directory.appending(path: "bin", directoryHint: .isDirectory)
        try "export USER_SETTING=1\n".write(to: zshrcURL, atomically: true, encoding: .utf8)

        let integration = DockerCompatibilitySystemTerminalIntegration(
            zshrcURL: zshrcURL,
            integrationScriptURL: integrationScriptURL,
            backupURL: backupURL
        )

        try integration.install(shimDirectory: shimDirectory)
        try integration.install(shimDirectory: shimDirectory)

        let zshrcText = try String(contentsOf: zshrcURL, encoding: .utf8)
        let integrationScript = try String(contentsOf: integrationScriptURL, encoding: .utf8)
        let backupText = try String(contentsOf: backupURL, encoding: .utf8)

        #expect(integration.isInstalled)
        #expect(zshrcText.contains("export USER_SETTING=1"))
        #expect(zshrcText.contains(DockerCompatibilitySystemTerminalIntegration.beginMarker))
        #expect(zshrcText.contains(integrationScriptURL.path))
        #expect(zshrcText.components(separatedBy: DockerCompatibilitySystemTerminalIntegration.beginMarker).count == 2)
        #expect(integrationScript.contains("CONTAINERDESKTOP_DOCKER_SHIM_BIN"))
        #expect(integrationScript.contains(shimDirectory.path))
        #expect(integrationScript.contains("export PATH=\"$CONTAINERDESKTOP_DOCKER_SHIM_BIN:$PATH\""))
        #expect(backupText == "export USER_SETTING=1\n")

        try integration.uninstall()

        let uninstalledText = try String(contentsOf: zshrcURL, encoding: .utf8)
        #expect(!integration.isInstalled)
        #expect(uninstalledText.contains("export USER_SETTING=1"))
        #expect(!uninstalledText.contains(DockerCompatibilitySystemTerminalIntegration.beginMarker))
        #expect(!uninstalledText.contains(DockerCompatibilitySystemTerminalIntegration.endMarker))
    }

    @MainActor
    @Test("docker terminal store tracks reported current directory")
    func dockerTerminalStoreTracksReportedCurrentDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDirectory = directory.appending(path: "frontend", directoryHint: .isDirectory)
        let secondDirectory = directory.appending(path: "backend", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

        let store = DockerCompatibilityTerminalStore(workingDirectory: firstDirectory)
        store.updateCurrentDirectory(fromTerminalDirectory: "file://localhost\(secondDirectory.path)")

        #expect(store.workingDirectory == secondDirectory.standardizedFileURL)
        #expect(store.workingDirectoryText == secondDirectory.standardizedFileURL.path)

        store.updateCurrentDirectory(fromTerminalDirectory: "https://example.com/ignored")
        #expect(store.workingDirectory == secondDirectory.standardizedFileURL)

        let targetStore = DockerCompatibilityTerminalStore(
            openRequest: DockerCompatibilityTerminalOpenRequest(
                workingDirectory: firstDirectory,
                shellTarget: .container(id: "web-1")
            )
        )
        targetStore.updateCurrentDirectory(fromTerminalDirectory: "file://localhost\(secondDirectory.path)")
        #expect(targetStore.workingDirectory == firstDirectory.standardizedFileURL)
    }

    @MainActor
    @Test("docker terminal tabs store manages independent sessions")
    func dockerTerminalTabsStoreManagesIndependentSessions() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDirectory = directory.appending(path: "frontend", directoryHint: .isDirectory)
        let secondDirectory = directory.appending(path: "backend", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: firstDirectory)

        #expect(tabsStore.tabs.count == 1)
        #expect(tabsStore.selectedTab?.workingDirectory == firstDirectory.standardizedFileURL)
        #expect(tabsStore.selectedTab?.title == "frontend")

        let inheritedTab = tabsStore.newTab()
        #expect(inheritedTab.workingDirectory == firstDirectory.standardizedFileURL)
        #expect(tabsStore.selectedTabID == inheritedTab.id)

        let externalTab = tabsStore.newTab(workingDirectory: secondDirectory)
        #expect(externalTab.workingDirectory == secondDirectory.standardizedFileURL)
        #expect(tabsStore.tabs.count == 3)
        #expect(tabsStore.selectedTabID == externalTab.id)

        tabsStore.selectPreviousTab()
        #expect(tabsStore.selectedTabID == inheritedTab.id)

        inheritedTab.store.terminalState = .connected
        #expect(tabsStore.closeSelectedTab() == .closedTab)
        #expect(inheritedTab.store.terminalState == .disconnected)
        #expect(tabsStore.tabs.count == 2)
        #expect(tabsStore.selectedTabID == externalTab.id)
    }

    @MainActor
    @Test("docker terminal tab title follows current directory")
    func dockerTerminalTabTitleFollowsCurrentDirectory() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstDirectory = directory.appending(path: "frontend", directoryHint: .isDirectory)
        let secondDirectory = directory.appending(path: "backend", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: firstDirectory)
        let firstTab = try #require(tabsStore.selectedTab)

        #expect(firstTab.title == "frontend")
        firstTab.store.updateCurrentDirectory(fromTerminalDirectory: "file://localhost\(secondDirectory.path)")
        #expect(firstTab.title == "backend")

        let inheritedTab = tabsStore.newTab()
        #expect(inheritedTab.workingDirectory == secondDirectory.standardizedFileURL)
        #expect(inheritedTab.title == "backend")
    }

    @MainActor
    @Test("docker terminal tabs support structured shell targets")
    func dockerTerminalTabsSupportStructuredShellTargets() {
        let tabsStore = DockerCompatibilityTerminalTabsStore(
            initialRequest: DockerCompatibilityTerminalOpenRequest(shellTarget: .container(id: "web-1"))
        )
        let firstTab = try! #require(tabsStore.selectedTab)

        #expect(firstTab.title == "Container web-1")
        #expect(firstTab.shellTarget == .container(id: "web-1"))
        #expect(firstTab.store.openRequest.shellTarget == .container(id: "web-1"))
        firstTab.store.updateCurrentDirectory(fromTerminalDirectory: "file:///tmp")
        #expect(firstTab.title == "Container web-1")

        let machineTab = tabsStore.newTab(request: DockerCompatibilityTerminalOpenRequest(shellTarget: .machine(id: "dev-machine")))
        #expect(machineTab.title == "Machine dev-machine")
        #expect(machineTab.shellTarget == .machine(id: "dev-machine"))
        #expect(tabsStore.selectedTabID == machineTab.id)
    }

    @MainActor
    @Test("closing final docker terminal tab replaces it without closing window")
    func closingFinalDockerTerminalTabReplacesItWithoutClosingWindow() {
        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: AppPaths.homeDirectory)
        let originalTab = try! #require(tabsStore.selectedTab)

        originalTab.store.terminalState = .connected

        #expect(tabsStore.closeSelectedTab() == .replacedLastTab)
        #expect(originalTab.store.terminalState == .disconnected)
        #expect(tabsStore.tabs.count == 1)
        #expect(tabsStore.selectedTabID == tabsStore.selectedTab?.id)
        #expect(tabsStore.selectedTab?.id != originalTab.id)
        #expect(tabsStore.selectedTab?.workingDirectory == AppPaths.homeDirectory.standardizedFileURL)
    }

    @MainActor
    @Test("docker terminal tab key commands are scoped")
    func dockerTerminalTabKeyCommandsAreScoped() {
        #expect(DockerCompatibilityTerminalTabKeyCommand.command(for: keyEvent("t", modifiers: .command)) == .newTab)
        #expect(DockerCompatibilityTerminalTabKeyCommand.command(for: keyEvent("w", modifiers: .command)) == .closeTab)
        #expect(DockerCompatibilityTerminalTabKeyCommand.command(for: keyEvent("]", modifiers: [.command, .shift])) == .nextTab)
        #expect(DockerCompatibilityTerminalTabKeyCommand.command(for: keyEvent("[", modifiers: [.command, .shift])) == .previousTab)
        #expect(DockerCompatibilityTerminalTabKeyCommand.command(for: keyEvent("t", modifiers: [.command, .option])) == nil)
    }

    @MainActor
    @Test("docker terminal window interrupts from chrome focus")
    func dockerTerminalWindowInterruptsFromChromeFocus() {
        let window = DockerCompatibilityTerminalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        defer {
            window.orderOut(nil)
            window.contentView = nil
            window.onSendInterrupt = nil
        }
        var interruptCount = 0
        window.onSendInterrupt = {
            interruptCount += 1
        }

        #expect(window.performKeyEquivalent(with: keyEvent("c", modifiers: .control)))
        #expect(interruptCount == 1)

        _ = window.performKeyEquivalent(with: keyEvent("c", modifiers: .command))
        #expect(interruptCount == 1)

        let terminalView = FocusableTerminalView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        window.contentView = terminalView
        #expect(window.makeFirstResponder(terminalView))

        _ = window.performKeyEquivalent(with: keyEvent("c", modifiers: .control))
        #expect(interruptCount == 1)
    }

    @MainActor
    @Test("docker terminal top chrome double click zoom hit testing")
    func dockerTerminalTopChromeDoubleClickZoomHitTesting() {
        let size = NSSize(width: 900, height: 560)

        #expect(DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 450, y: 559),
            in: size
        ))
        #expect(DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 450, y: 516),
            in: size
        ))
        #expect(!DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 450, y: 515),
            in: size
        ))
        #expect(!DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 40, y: 548),
            in: size
        ))
        #expect(!DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 870, y: 548),
            in: size
        ))
        #expect(!DockerCompatibilityTerminalWindow.shouldPerformTopChromeDoubleClickZoom(
            at: NSPoint(x: 450, y: 580),
            in: size
        ))
    }

    @Test("docker terminal window handles top chrome double click zoom")
    func dockerTerminalWindowHandlesTopChromeDoubleClickZoom() throws {
        let source = try String(
            contentsOfFile: "Sources/ContainerDesktop/App/DockerCompatibilityTerminalWindow.swift",
            encoding: .utf8
        )

        #expect(source.contains("static let topChromeDoubleClickHeight: CGFloat = 44"))
        #expect(source.contains("static let trailingChromeControlReservedWidth: CGFloat = 52"))
        #expect(source.contains("override func sendEvent(_ event: NSEvent)"))
        #expect(source.contains("event.type == .leftMouseDown"))
        #expect(source.contains("event.clickCount == 2"))
        #expect(source.contains("performZoom(nil)"))
        #expect(source.contains("shouldPerformTopChromeDoubleClickZoom(at: event.locationInWindow)"))
    }

    @Test("main app fallback uses terminal window for scoped tab shortcuts")
    func mainAppFallbackUsesTerminalWindowForScopedTabShortcuts() throws {
        let source = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(source.contains("DockerCompatibilityTerminalWindow(contentViewController: hostingController)"))
        #expect(source.contains("configureDockerCompatibilityTerminalTabKeyCommands(on: window)"))
        #expect(source.contains("addTabIfWindowExists: true"))
        #expect(source.contains("openDockerCompatibilityTerminalRequest"))
        #expect(source.contains("tabsStore.newTab(request: request)"))
    }

    @Test("terminal interrupt is wired in standalone and fallback windows")
    func terminalInterruptIsWiredInStandaloneAndFallbackWindows() throws {
        let standaloneSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/DockerCompatibilityTerminalApplication.swift", encoding: .utf8)
        let mainSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(standaloneSource.contains("window.onSendInterrupt"))
        #expect(standaloneSource.contains("tabsStore?.selectedTab?.store.sendTerminalInputData"))
        #expect(mainSource.contains("window.onSendInterrupt"))
        #expect(mainSource.contains("dockerCompatibilityTerminalTabsStore?.selectedTab?.store.sendTerminalInputData"))
    }

    @Test("external terminal targets build container cli arguments")
    func externalTerminalTargetsBuildContainerCLIArguments() throws {
        #expect(TerminalShellTarget.container(id: "web-1").containerCLIArguments == [
            "container", "exec", "-it", "web-1", "sh",
        ])
        #expect(TerminalShellTarget.machine(id: "dev-machine").containerCLIArguments == [
            "container", "machine", "run", "-n", "dev-machine", "-i", "-t", "--", "sh",
        ])
        #expect(TerminalShellTarget.container(id: "1234567890abcdef").tabTitle == "Container 1234567890abcdef")
        #expect(TerminalShellTarget.container(id: "1234567890abcdef-extra").tabTitle == "Container 1234567890ab")

        let serviceSource = try String(contentsOfFile: "Sources/ContainerDesktop/Services/DockerCompatibilityTerminalService.swift", encoding: .utf8)
        #expect(serviceSource.contains("executable: \"/usr/bin/env\""))
        #expect(serviceSource.contains("arguments: shellTarget.containerCLIArguments"))
    }

    @Test("resource terminal menus expose both destinations")
    func resourceTerminalMenusExposeBothDestinations() throws {
        let files = [
            "Sources/ContainerDesktop/Views/Resources/ContainersView.swift",
            "Sources/ContainerDesktop/Views/Resources/MachinesView.swift",
            "Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerExecTabView.swift",
            "Sources/ContainerDesktop/Views/Resources/MachineDetail/MachineExecTabView.swift",
            "Sources/ContainerDesktop/Views/Compose/ComposeServiceRuntimeMenu.swift",
        ]

        for file in files {
            let source = try String(contentsOfFile: file, encoding: .utf8)
            #expect(source.contains("ExternalTerminalDestinationMenuItems"))
        }

        let commonSource = try String(contentsOfFile: "Sources/ContainerDesktop/Views/Common/ResourcePageParts.swift", encoding: .utf8)
        #expect(commonSource.contains("struct RowActionMenuButton"))
        #expect(commonSource.contains("ExternalTerminalDestination.allCases"))
    }

    @Test("docker terminal tab item uses full chip selection hit area")
    func dockerTerminalTabItemUsesFullChipSelectionHitArea() throws {
        let source = try String(contentsOfFile: "Sources/ContainerDesktop/Views/DockerCompatibilityTerminal/DockerCompatibilityTerminalTabsView.swift", encoding: .utf8)
        let tabItemStart = try #require(source.range(of: "private func tabItem"))
        let tabBackgroundStart = try #require(source.range(of: "private func tabBackground"))
        let tabItemSource = String(source[tabItemStart.lowerBound..<tabBackgroundStart.lowerBound])

        #expect(tabItemSource.contains("ZStack(alignment: .trailing)"))
        #expect(tabItemSource.contains("tabsStore.selectTab(id: tab.id)"))
        #expect(tabItemSource.contains(".padding(.trailing, 28)"))
        #expect(tabItemSource.contains(".contentShape(RoundedRectangle(cornerRadius: 6))"))
        #expect(tabItemSource.contains("closeTab(tab.id)"))
        #expect(tabItemSource.contains("Image(systemName: \"xmark\")"))
    }

    @MainActor
    @Test("terminal window chrome follows terminal style")
    func terminalWindowChromeFollowsTerminalStyle() {
        let window = NSWindow()
        defer { window.orderOut(nil) }

        DockerCompatibilityTerminalWindowChrome.apply(
            to: window,
            title: "Docker 兼容终端",
            style: .containerDark
        )

        #expect(window.title == "Docker 兼容终端")
        #expect(window.styleMask.contains(.fullSizeContentView))
        #expect(window.titleVisibility == .hidden)
        #expect(window.titlebarAppearsTransparent)
        #expect(window.titlebarSeparatorStyle == .none)
        #expect(window.toolbar == nil)
        #expect(window.appearance?.name == .darkAqua)
        #expect(nsColorsMatch(window.backgroundColor, DockerCompatibilityTerminalWindowChrome.palette(for: .containerDark).windowBackgroundColor))

        DockerCompatibilityTerminalWindowChrome.apply(
            to: window,
            title: "Docker Compatibility Terminal",
            style: .paper
        )

        #expect(window.title == "Docker Compatibility Terminal")
        #expect(window.appearance?.name == .aqua)
        #expect(nsColorsMatch(window.backgroundColor, DockerCompatibilityTerminalWindowChrome.palette(for: .paper).windowBackgroundColor))
        #expect(DockerCompatibilityTerminalWindowChrome.palette(for: .paper).preferredColorScheme == .light)
        #expect(DockerCompatibilityTerminalWindowChrome.palette(for: .graphite).preferredColorScheme == .dark)
    }

    @Test("terminal windows hide instead of closing")
    func terminalWindowsHideInsteadOfClosing() throws {
        let standaloneSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/DockerCompatibilityTerminalApplication.swift", encoding: .utf8)
        let mainSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(standaloneSource.contains("func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {\n        false\n    }"))
        #expect(standaloneSource.contains("func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool"))
        #expect(standaloneSource.contains("func windowShouldClose(_ sender: NSWindow) -> Bool"))
        #expect(standaloneSource.contains("sender.orderOut(nil)"))
        #expect(mainSource.contains("func windowShouldClose(_ sender: NSWindow) -> Bool"))
        #expect(mainSource.contains("sender.orderOut(nil)"))

        let standaloneShouldClose = try #require(standaloneSource.range(of: "func windowShouldClose(_ sender: NSWindow) -> Bool"))
        let standaloneSnippet = String(standaloneSource[standaloneShouldClose.lowerBound...].prefix(220))
        #expect(!standaloneSnippet.contains("stopAll()"))

        let mainShouldClose = try #require(mainSource.range(of: "func windowShouldClose(_ sender: NSWindow) -> Bool"))
        let mainSnippet = String(mainSource[mainShouldClose.lowerBound...].prefix(220))
        #expect(!mainSnippet.contains("stopAll()"))
    }

    @Test("terminal style participates in chrome refresh")
    func terminalStyleParticipatesInChromeRefresh() throws {
        let standaloneSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/DockerCompatibilityTerminalApplication.swift", encoding: .utf8)
        let mainSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(standaloneSource.contains("terminalStyle: terminalStyle"))
        #expect(mainSource.contains("terminalStyle: dockerCompatibilityTerminalStyle"))
        #expect(standaloneSource.contains("applyTerminalWindowChrome(to: window)"))
        #expect(mainSource.contains("applyDockerCompatibilityTerminalWindowChrome(dockerCompatibilityTerminalWindow)"))
    }

    @MainActor
    @Test("docker terminal coalesces high frequency output")
    func dockerTerminalCoalescesHighFrequencyOutput() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        for index in 0..<200 {
            store.appendTerminalChunk("step-\(index)\r")
        }

        #expect(store.terminalOutputEvents.isEmpty)

        store.flushPendingTerminalOutput()

        #expect(store.terminalOutputSequence == 1)
        #expect(store.terminalOutputEvents.count == 1)
        #expect(store.terminalOutputEvents.last?.text.contains("step-199\r") == true)
        #expect(store.terminalText.contains("step-199"))
        #expect(!store.terminalText.contains("\r"))
        #expect(!store.terminalText.contains("step-0\r"))
    }

    @MainActor
    @Test("docker terminal replaces continuous carriage return progress cache")
    func dockerTerminalReplacesContinuousCarriageReturnProgressCache() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        for index in 0..<200 {
            store.appendTerminalChunk("progress-\(String(format: "%04d", index))\r", flushImmediately: true)
        }

        #expect(store.terminalOutputSequence == 200)
        #expect(store.terminalOutputEvents.count == 1)
        #expect(store.terminalOutputEvents.last?.sequence == 200)
        #expect(store.terminalOutputEvents.last?.text == "progress-0199\r")
        #expect(store.terminalText == "progress-0199")
        #expect(!store.terminalText.contains("progress-0000"))
    }

    @MainActor
    @Test("docker terminal replaces carriage return prompt redraw cache")
    func dockerTerminalReplacesCarriageReturnPromptRedrawCache() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        for _ in 0..<10 {
            store.appendTerminalChunk("\rzuoxiupeng➜~» ", flushImmediately: true)
        }

        #expect(store.terminalOutputSequence == 10)
        #expect(store.terminalOutputEvents.count == 1)
        #expect(store.terminalText == "zuoxiupeng➜~» ")
        #expect(!store.terminalText.contains("\r"))
    }

    @MainActor
    @Test("docker terminal replaces active command line redraw cache")
    func dockerTerminalReplacesActiveCommandLineRedrawCache() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        store.appendTerminalChunk("zuoxiupeng➜~» ", flushImmediately: true)
        store.appendTerminalChunk("ls", flushImmediately: true)
        store.appendTerminalChunk("\rzuoxiupeng➜~» ls", flushImmediately: true)

        #expect(store.terminalText == "zuoxiupeng➜~» ls")
        #expect(!store.terminalText.contains("lszuoxiupeng"))
    }

    @MainActor
    @Test("docker terminal replaces CSI prompt redraw cache")
    func dockerTerminalReplacesCSIPromptRedrawCache() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        store.appendTerminalChunk("zuoxiupeng➜~» ", flushImmediately: true)
        store.appendTerminalChunk("\u{1B}[1Gzuoxiupeng➜~» ", flushImmediately: true)
        store.appendTerminalChunk("\u{1B}[2K\u{1B}[1Gzuoxiupeng➜~» ", flushImmediately: true)
        store.appendTerminalChunk("\u{1B}[Kzuoxiupeng➜~» ", flushImmediately: true)

        #expect(store.terminalOutputEvents.last?.text == "\u{1B}[Kzuoxiupeng➜~» ")
        #expect(store.terminalText == "zuoxiupeng➜~» ")
        #expect(!store.terminalText.contains("\u{1B}[1G"))
        #expect(!store.terminalText.contains("\u{1B}[2K"))
        #expect(!store.terminalText.contains("\u{1B}[K"))
    }

    @MainActor
    @Test("docker terminal prompt redraw does not remove committed history")
    func dockerTerminalPromptRedrawDoesNotRemoveCommittedHistory() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        store.appendTerminalChunk("zuoxiupeng➜~» ls\n", flushImmediately: true)
        store.appendTerminalChunk("README.md\n", flushImmediately: true)
        store.appendTerminalChunk("\rzuoxiupeng➜~» ", flushImmediately: true)
        store.appendTerminalChunk("\rzuoxiupeng➜~» ", flushImmediately: true)

        #expect(store.terminalText == "zuoxiupeng➜~» ls\nREADME.md\nzuoxiupeng➜~» ")
    }

    @MainActor
    @Test("docker terminal progress does not evict normal cached logs")
    func dockerTerminalProgressDoesNotEvictNormalCachedLogs() {
        let suiteName = "ContainerDesktopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(1_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        let store = DockerCompatibilityTerminalStore(
            historyDefaults: defaults,
            workingDirectory: AppPaths.homeDirectory
        )

        for index in 1...900 {
            store.appendTerminalChunk("line-\(index)\n", flushImmediately: true)
        }
        for index in 1...10_000 {
            store.appendTerminalChunk("push-\(index)\r", flushImmediately: true)
        }
        for index in 901...910 {
            store.appendTerminalChunk("line-\(index)\n", flushImmediately: true)
        }

        #expect(store.terminalOutputSequence == 10_910)
        #expect(store.terminalOutputEvents.count == 911)
        #expect(store.terminalOutputEvents.first?.sequence == 1)
        #expect(store.terminalText.contains("line-1\n"))
        #expect(store.terminalText.contains("line-910\n"))
        #expect(store.terminalText.contains("push-10000"))
        #expect(!store.terminalText.contains("\r"))
        #expect(!store.terminalText.contains("push-1\rpush-2"))
    }

    @MainActor
    @Test("docker terminal compacts repeated carriage returns in one chunk")
    func dockerTerminalCompactsRepeatedCarriageReturnsInOneChunk() {
        let store = DockerCompatibilityTerminalStore(workingDirectory: AppPaths.homeDirectory)

        store.appendTerminalChunk("0%\r50%\r100%\n", flushImmediately: true)

        #expect(store.terminalOutputSequence == 1)
        #expect(store.terminalOutputEvents.count == 1)
        #expect(store.terminalOutputEvents.last?.text == "0%\r50%\r100%\n")
        #expect(store.terminalText == "100%\n")

        let clearLineFrame = TerminalOverwriteReplayCompactor.compact("old\r\u{1B}[2Knew\r")
        #expect(clearLineFrame.snapshotText == "new")
        #expect(clearLineFrame.replaceableSuffixCharacterCount == 3)

        let commandEchoFrame = TerminalOverwriteReplayCompactor.compact("ls\r\n")
        #expect(commandEchoFrame.snapshotText == "ls\n")

        let committedProgressFrame = TerminalOverwriteReplayCompactor.compact("0%\r50%\r100%\r\n")
        #expect(committedProgressFrame.snapshotText == "100%\n")

        let startupPromptFrame = TerminalOverwriteReplayCompactor.compact(
            "\u{1B}[1;36mContainer Desktop Docker compatibility terminal\u{1B}[0m\nshim: /tmp/docker-compatibility/bin\n\rzuoxiupeng➜~» "
        )
        #expect(startupPromptFrame.snapshotText.contains("\u{1B}[1;36mContainer Desktop"))
        #expect(startupPromptFrame.snapshotText.contains("shim: /tmp/docker-compatibility/bin\n"))
        #expect(startupPromptFrame.snapshotText.contains("zuoxiupeng➜~» "))
        #expect(!startupPromptFrame.snapshotText.contains("\r"))
        #expect(!startupPromptFrame.snapshotText.contains("\u{1B}[1G"))
    }

    @Test("terminal snapshot replay converts lone line feeds")
    func terminalSnapshotReplayConvertsLoneLineFeeds() throws {
        #expect(TerminalSnapshotReplayText.feedText(from: "a\nb\n") == "a\r\nb\r\n")
        #expect(TerminalSnapshotReplayText.feedText(from: "a\r\nb\r\n") == "a\r\nb\r\n")
        #expect(TerminalSnapshotReplayText.feedText(from: "zuoxiupeng➜~» ") == "zuoxiupeng➜~» ")

        let startupSnapshot = "title\nmapping\nshim\n\nzuoxiupeng➜~» "
        #expect(TerminalSnapshotReplayText.feedText(from: startupSnapshot) == "title\r\nmapping\r\nshim\r\n\r\nzuoxiupeng➜~» ")

        let terminalViewSource = try String(contentsOfFile: "Sources/ContainerDesktop/Views/Common/SwiftTermTerminalView.swift", encoding: .utf8)
        #expect(terminalViewSource.contains("TerminalSnapshotReplayText.feedText(from: textSnapshot)"))
    }

    @MainActor
    @Test("docker terminal trims output events using configured limit")
    func dockerTerminalTrimsOutputEventsUsingConfiguredLimit() {
        let suiteName = "ContainerDesktopTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(1_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        let store = DockerCompatibilityTerminalStore(
            historyDefaults: defaults,
            workingDirectory: AppPaths.homeDirectory
        )

        for index in 1...1_050 {
            store.appendTerminalChunk("line-\(index)\n", flushImmediately: true)
        }

        #expect(store.terminalOutputEvents.count == 1_000)
        #expect(store.terminalOutputEvents.first?.sequence == 51)
        #expect(store.terminalOutputEvents.last?.text == "line-1050\n")

        defaults.set(2_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        for index in 1_051...1_650 {
            store.appendTerminalChunk("line-\(index)\n", flushImmediately: true)
        }
        #expect(store.terminalOutputEvents.count == 1_600)
        #expect(store.terminalOutputEvents.first?.sequence == 51)

        defaults.set(1_000, forKey: DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey)
        store.appendTerminalChunk("line-1651\n", flushImmediately: true)
        #expect(store.terminalOutputEvents.count == 1_000)
        #expect(store.terminalOutputEvents.first?.sequence == 652)
        #expect(store.terminalOutputEvents.last?.text == "line-1651\n")
    }

    @MainActor
    @Test("terminal feed skips trimmed event gaps without reset")
    func terminalFeedSkipsTrimmedEventGapsWithoutReset() {
        let terminalView = FocusableTerminalView(frame: .zero)
        let coordinator = SwiftTermTerminalView.Coordinator(
            onInput: { _ in },
            onSizeChange: { _, _ in }
        )
        coordinator.sizeChanged(source: terminalView, newCols: 120, newRows: 30)

        coordinator.feed(
            terminalView,
            textSnapshot: "seed",
            outputEvents: [TerminalOutputEvent(sequence: 1, text: "seed")],
            outputSequence: 1,
            resetSequence: 1
        )
        #expect(coordinator.resetCount == 1)

        coordinator.feed(
            terminalView,
            textSnapshot: "seed-latest",
            outputEvents: [TerminalOutputEvent(sequence: 5, text: "latest")],
            outputSequence: 5,
            resetSequence: 1
        )

        #expect(coordinator.resetCount == 1)
        #expect(coordinator.skippedOutputGapCount == 1)
    }

    @MainActor
    @Test("terminal snapshot replay waits for usable size")
    func terminalSnapshotReplayWaitsForUsableSize() {
        let terminalView = FocusableTerminalView(frame: .zero)
        let coordinator = SwiftTermTerminalView.Coordinator(
            onInput: { _ in },
            onSizeChange: { _, _ in }
        )

        coordinator.feed(
            terminalView,
            textSnapshot: "web: booting\n",
            outputEvents: [TerminalOutputEvent(sequence: 1, text: "web: booting\n")],
            outputSequence: 1,
            resetSequence: 1
        )

        #expect(coordinator.resetCount == 0)
        #expect(coordinator.isSnapshotReplayPending)
        #expect(coordinator.pendingReplayCount == 1)

        coordinator.sizeChanged(source: terminalView, newCols: 2, newRows: 24)
        #expect(coordinator.resetCount == 0)
        #expect(coordinator.isSnapshotReplayPending)

        coordinator.sizeChanged(source: terminalView, newCols: 120, newRows: 30)
        #expect(coordinator.resetCount == 1)
        #expect(!coordinator.isSnapshotReplayPending)

        coordinator.feed(
            terminalView,
            textSnapshot: "web: booting\nready\n",
            outputEvents: [TerminalOutputEvent(sequence: 2, text: "ready\n")],
            outputSequence: 2,
            resetSequence: 1
        )
        #expect(coordinator.resetCount == 1)
    }

    @MainActor
    @Test("terminal reset sequence replay waits for usable size")
    func terminalResetSequenceReplayWaitsForUsableSize() {
        let terminalView = FocusableTerminalView(frame: .zero)
        let coordinator = SwiftTermTerminalView.Coordinator(
            onInput: { _ in },
            onSizeChange: { _, _ in }
        )

        coordinator.feed(
            terminalView,
            textSnapshot: "",
            outputEvents: [],
            outputSequence: 0,
            resetSequence: 1
        )
        #expect(coordinator.resetCount == 1)
        #expect(!coordinator.isSnapshotReplayPending)

        coordinator.feed(
            terminalView,
            textSnapshot: "after reset\n",
            outputEvents: [TerminalOutputEvent(sequence: 1, text: "after reset\n")],
            outputSequence: 1,
            resetSequence: 2
        )
        #expect(coordinator.resetCount == 1)
        #expect(coordinator.isSnapshotReplayPending)

        coordinator.sizeChanged(source: terminalView, newCols: 120, newRows: 30)
        #expect(coordinator.resetCount == 2)
        #expect(!coordinator.isSnapshotReplayPending)
    }

    @MainActor
    @Test("terminal style apply skips unchanged style")
    func terminalStyleApplySkipsUnchangedStyle() {
        let view = FocusableTerminalView(frame: .zero)

        view.apply(style: .containerDefault)
        view.apply(style: .containerDefault)
        #expect(view.styleApplicationCount == 1)

        view.apply(style: DockerCompatibilityTerminalStyle.graphite.configuration)
        #expect(view.styleApplicationCount == 2)
    }

    @Test("build scripts use dedicated terminal icon")
    func buildScriptsUseDedicatedTerminalIcon() throws {
        let buildScript = try String(contentsOfFile: "script/build_and_run.sh", encoding: .utf8)
        let releaseScript = try String(contentsOfFile: "script/package_release.sh", encoding: .utf8)
        let bundleScript = try String(contentsOfFile: "script/lib/macos_bundle.sh", encoding: .utf8)

        #expect(buildScript.contains("DockerCompatibilityTerminalIcon.icns"))
        #expect(buildScript.contains("<string>DockerCompatibilityTerminalIcon</string>"))
        #expect(releaseScript.contains("TERMINAL_ICON_SOURCE"))
        #expect(bundleScript.contains("create_docker_compatibility_terminal_app_bundle"))
        #expect(bundleScript.contains("<string>DockerCompatibilityTerminalIcon</string>"))
    }

    @Test("docker terminal zsh configuration reports current directory")
    func dockerTerminalZshConfigurationReportsCurrentDirectory() throws {
        let serviceSource = try String(contentsOfFile: "Sources/ContainerDesktop/Services/DockerCompatibilityTerminalService.swift", encoding: .utf8)

        #expect(serviceSource.contains("containerdesktop_report_cwd()"))
        #expect(serviceSource.contains("printf '\\\\033]7;file://%s%s\\\\007'"))
        #expect(serviceSource.contains("autoload -Uz add-zsh-hook"))
        #expect(serviceSource.contains("add-zsh-hook precmd containerdesktop_report_cwd"))
        #expect(serviceSource.contains("add-zsh-hook chpwd containerdesktop_report_cwd"))
        #expect(serviceSource.contains("containerdesktop_report_cwd"))
    }

    @Test("finder services registration opens docker compatibility terminal")
    func finderServicesRegistrationOpensDockerCompatibilityTerminal() throws {
        let buildScript = try String(contentsOfFile: "script/build_and_run.sh", encoding: .utf8)
        let bundleScript = try String(contentsOfFile: "script/lib/macos_bundle.sh", encoding: .utf8)
        let appSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)
        let englishServices = try String(contentsOfFile: "Resources/en.lproj/ServicesMenu.strings", encoding: .utf8)
        let chineseServices = try String(contentsOfFile: "Resources/zh-Hans.lproj/ServicesMenu.strings", encoding: .utf8)

        for source in [buildScript, bundleScript] {
            #expect(source.contains("<key>NSServices</key>"))
            #expect(source.contains("<string>openDockerCompatibilityTerminal</string>"))
            #expect(source.contains("<key>NSPortName</key>"))
            #expect(source.contains("<key>NSSendTypes</key>"))
            #expect(source.contains("<string>NSFilenamesPboardType</string>"))
            #expect(source.contains("<string>public.file-url</string>"))
            #expect(source.contains("<key>NSSendFileTypes</key>"))
            #expect(source.contains("<string>public.folder</string>"))
            #expect(source.contains("<key>NSRequiredContext</key>"))
            #expect(source.contains("<string>com.apple.finder</string>"))
        }
        #expect(buildScript.contains("lsregister"))
        #expect(appSource.contains("NSApp.servicesProvider = self"))
        #expect(appSource.contains("NSUpdateDynamicServices()"))
        #expect(englishServices.contains("\"在 Docker 兼容终端中打开\" = \"Open in Docker Compatibility Terminal\";"))
        #expect(chineseServices.contains("\"在 Docker 兼容终端中打开\" = \"在 Docker 兼容终端中打开\";"))
    }

    @Test("service request resolves file URL pasteboard items")
    func serviceRequestResolvesPasteboardURLs() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let projectDirectory = directory.appending(path: "Project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        let projectFile = projectDirectory.appending(path: "README.md")
        try "demo".write(to: projectFile, atomically: true, encoding: .utf8)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([projectDirectory as NSURL]))

        #expect(DockerCompatibilityTerminalServiceRequest.workingDirectory(from: pasteboard) == projectDirectory.standardizedFileURL)

        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([projectFile as NSURL]))
        #expect(DockerCompatibilityTerminalServiceRequest.workingDirectory(from: pasteboard) == projectDirectory.standardizedFileURL)
        #expect(DockerCompatibilityTerminalServiceRequest.workingDirectory(fromPath: projectDirectory.appending(path: "missing").path) == nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ContainerDesktopTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func nsColorsMatch(_ lhs: NSColor, _ rhs: NSColor, tolerance: CGFloat = 0.0001) -> Bool {
        guard let lhs = lhs.usingColorSpace(.sRGB),
              let rhs = rhs.usingColorSpace(.sRGB)
        else {
            return lhs.isEqual(rhs)
        }
        return abs(lhs.redComponent - rhs.redComponent) <= tolerance
            && abs(lhs.greenComponent - rhs.greenComponent) <= tolerance
            && abs(lhs.blueComponent - rhs.blueComponent) <= tolerance
            && abs(lhs.alphaComponent - rhs.alphaComponent) <= tolerance
    }

    @MainActor
    private func keyEvent(_ key: String, modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: 0
        )!
    }
}

private final class RecordingTerminalDelegate: TerminalViewDelegate {
    var sentData: [Data] = []

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: TerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        sentData.append(Data(data))
    }

    func scrolled(source: TerminalView, position: Double) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}

    func bell(source: TerminalView) {}

    func clipboardCopy(source: TerminalView, content: Data) {}

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}
