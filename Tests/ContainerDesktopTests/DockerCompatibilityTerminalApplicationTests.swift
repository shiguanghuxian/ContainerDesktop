import AppKit
import Foundation
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
        #expect(DockerCompatibilityTerminalStrings.settingsMenuTitle(.zhHans) == "终端设置…")
        #expect(DockerCompatibilityTerminalStrings.settingsMenuTitle(.en) == "Terminal Settings...")
        #expect(DockerCompatibilityTerminalStrings.openTerminalHelp(.zhHans) == "打开 Docker 兼容终端")
        #expect(DockerCompatibilityTerminalStrings.openTerminalHelp(.en) == "Open Docker compatibility terminal")
        #expect(DockerCompatibilityTerminalStrings.newTab(.zhHans) == "新建 Tab")
        #expect(DockerCompatibilityTerminalStrings.newTab(.en) == "New Tab")
        #expect(DockerCompatibilityTerminalStrings.closeTab(.zhHans) == "关闭 Tab")
        #expect(DockerCompatibilityTerminalStrings.closeTab(.en) == "Close Tab")
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
    @Test("closing final docker terminal tab requests window close")
    func closingFinalDockerTerminalTabRequestsWindowClose() {
        let tabsStore = DockerCompatibilityTerminalTabsStore(initialWorkingDirectory: AppPaths.homeDirectory)

        tabsStore.selectedTab?.store.terminalState = .connected

        #expect(tabsStore.closeSelectedTab() == .closedLastTab)
        #expect(tabsStore.tabs.isEmpty)
        #expect(tabsStore.selectedTabID == nil)
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

    @Test("main app fallback uses terminal window for scoped tab shortcuts")
    func mainAppFallbackUsesTerminalWindowForScopedTabShortcuts() throws {
        let source = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)

        #expect(source.contains("DockerCompatibilityTerminalWindow(contentViewController: hostingController)"))
        #expect(source.contains("configureDockerCompatibilityTerminalTabKeyCommands(on: window)"))
        #expect(source.contains("addTabIfWindowExists: true"))
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
        #expect(store.terminalText.contains("step-0\r"))
        #expect(store.terminalText.contains("step-199\r"))
    }

    @MainActor
    @Test("terminal feed skips trimmed event gaps without reset")
    func terminalFeedSkipsTrimmedEventGapsWithoutReset() {
        let terminalView = FocusableTerminalView(frame: .zero)
        let coordinator = SwiftTermTerminalView.Coordinator(
            onInput: { _ in },
            onSizeChange: { _, _ in }
        )

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

    @Test("service request resolves file URL pasteboard items")
    func serviceRequestResolvesPasteboardURLs() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let projectDirectory = directory.appending(path: "Project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects([projectDirectory as NSURL]))

        #expect(DockerCompatibilityTerminalServiceRequest.workingDirectory(from: pasteboard) == projectDirectory.standardizedFileURL)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "ContainerDesktopTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
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
