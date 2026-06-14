import AppKit
import Testing
@testable import ContainerDesktop

@MainActor
@Suite("ContainerDesktop main menu")
struct ContainerDesktopMainMenuControllerTests {
    @Test("main menu keeps managed items and follows language")
    func mainMenuKeepsManagedItemsAndFollowsLanguage() {
        let application = NSApplication.shared
        let originalMainMenu = application.mainMenu
        var openedSections: [AppSection] = []
        var settingsOpenCount = 0
        var updateCheckCount = 0
        var reloadCount = 0

        defer {
            application.mainMenu = originalMainMenu
        }

        let actions = ContainerDesktopMainMenuActions(
            openMain: { section in openedSections.append(section) },
            openSettings: { settingsOpenCount += 1 },
            checkForUpdates: { updateCheckCount += 1 },
            reload: { reloadCount += 1 }
        )

        let chineseSnapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: .zhHans,
            selectedSection: .dashboard
        )
        ContainerDesktopMainMenuController.shared.configure(snapshot: chineseSnapshot, actions: actions)

        #expect(application.mainMenu?.items.map(\.title) == ["ContainerDesktop", "编辑", "显示", "帮助"])
        #expect(application.mainMenu?.items[0].submenu?.items.first?.title == "关于 ContainerDesktop")
        #expect(application.mainMenu?.items[0].submenu?.items.first?.target === ContainerDesktopMainMenuController.shared)
        #expect(application.mainMenu?.items[0].submenu?.items.first { $0.title == "检查更新…" }?.target === ContainerDesktopMainMenuController.shared)
        #expect(application.mainMenu?.items[0].submenu?.items.first { $0.title == "设置" }?.target === ContainerDesktopMainMenuController.shared)

        let chineseViewTitles = application.mainMenu?.items[2].submenu?.items
            .filter { !$0.isSeparatorItem }
            .map(\.title)
        #expect(chineseViewTitles == [
            "刷新",
            "Docker 转换",
            "Dashboard",
            "Containers",
            "Machines",
            "Images",
            "Volumes",
            "Networks",
            "Compose",
            "观测",
            "Registries",
            "System",
        ])

        guard let initialMainMenu = application.mainMenu,
              initialMainMenu.items.count == 4
        else {
            Issue.record("Missing managed main menu")
            return
        }
        let initialTopItems = initialMainMenu.items

        if let settingsItem = application.mainMenu?.items[0].submenu?.items.first(where: { $0.title == "设置" }),
           let action = settingsItem.action {
            NSApp.sendAction(action, to: settingsItem.target, from: settingsItem)
        }
        #expect(settingsOpenCount == 1)

        if let updateItem = application.mainMenu?.items[0].submenu?.items.first(where: { $0.title == "检查更新…" }),
           let action = updateItem.action {
            NSApp.sendAction(action, to: updateItem.target, from: updateItem)
        }
        #expect(updateCheckCount == 1)

        if let reloadItem = application.mainMenu?.items[2].submenu?.items.first(where: { $0.title == "刷新" }),
           let action = reloadItem.action {
            NSApp.sendAction(action, to: reloadItem.target, from: reloadItem)
        }
        #expect(reloadCount == 1)

        if let converterItem = application.mainMenu?.items[2].submenu?.items.first(where: { $0.title == "Docker 转换" }),
           let action = converterItem.action {
            NSApp.sendAction(action, to: converterItem.target, from: converterItem)
        }
        #expect(openedSections == [.commandConverter])
        #expect(application.mainMenu?.items[2].submenu?.items.first { $0.representedObject as? String == AppSection.commandConverter.rawValue }?.isEnabled == false)

        let englishSnapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: .en,
            selectedSection: .containers
        )
        ContainerDesktopMainMenuController.shared.configure(snapshot: englishSnapshot, actions: actions)

        #expect(application.mainMenu === initialMainMenu)
        for index in initialTopItems.indices {
            #expect(application.mainMenu?.items[index] === initialTopItems[index])
        }
        #expect(application.mainMenu?.items.map(\.title) == ["ContainerDesktop", "Edit", "View", "Help"])
        #expect(application.mainMenu?.items[0].submenu?.items.first?.title == "About ContainerDesktop")
        #expect(application.mainMenu?.items[0].submenu?.items.first { $0.title == "Check for Updates..." } != nil)
        #expect(application.mainMenu?.items[0].submenu?.items.first { $0.title == "Settings" } != nil)

        let englishViewTitles = application.mainMenu?.items[2].submenu?.items
            .filter { !$0.isSeparatorItem }
            .map(\.title)
        #expect(englishViewTitles == [
            "Refresh",
            "Docker Convert",
            "Dashboard",
            "Containers",
            "Machines",
            "Images",
            "Volumes",
            "Networks",
            "Compose",
            "Observe",
            "Registries",
            "System",
        ])

        guard let englishViewMenu = application.mainMenu?.items[2].submenu else {
            Issue.record("Missing English View menu")
            return
        }
        let englishViewItems = englishViewMenu.items

        let sameVisibleSnapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: .en,
            selectedSection: .images
        )
        ContainerDesktopMainMenuController.shared.configure(snapshot: sameVisibleSnapshot, actions: actions)

        #expect(application.mainMenu === initialMainMenu)
        #expect(application.mainMenu?.items[2].submenu === englishViewMenu)
        for index in englishViewItems.indices {
            #expect(application.mainMenu?.items[2].submenu?.items[index] === englishViewItems[index])
        }

        ContainerDesktopMainMenuController.shared.menuNeedsUpdate(englishViewMenu)
        #expect(englishViewMenu.items.first { $0.representedObject as? String == AppSection.images.rawValue }?.isEnabled == false)
        #expect(englishViewMenu.items.first { $0.representedObject as? String == AppSection.containers.rawValue }?.isEnabled == true)
    }

    @Test("section changes do not rebuild menu language")
    func sectionChangesDoNotRebuildMenuLanguage() {
        let application = NSApplication.shared
        let originalMainMenu = application.mainMenu

        defer {
            application.mainMenu = originalMainMenu
        }

        let snapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: .zhHans,
            selectedSection: .dashboard
        )
        let actions = ContainerDesktopMainMenuActions(
            openMain: { _ in },
            openSettings: {},
            checkForUpdates: {},
            reload: {}
        )
        ContainerDesktopMainMenuController.shared.configure(snapshot: snapshot, actions: actions)

        guard let initialMainMenu = application.mainMenu,
              let initialViewMenu = application.mainMenu?.items[2].submenu
        else {
            Issue.record("Missing managed main menu")
            return
        }
        let initialViewItems = initialViewMenu.items

        ContainerDesktopMainMenuController.shared.updateSelectedSection(.images)

        #expect(application.mainMenu === initialMainMenu)
        #expect(application.mainMenu?.items.map(\.title) == ["ContainerDesktop", "编辑", "显示", "帮助"])
        #expect(application.mainMenu?.items[2].submenu === initialViewMenu)
        for index in initialViewItems.indices {
            #expect(application.mainMenu?.items[2].submenu?.items[index] === initialViewItems[index])
        }
        #expect(initialViewMenu.items.first { $0.representedObject as? String == AppSection.images.rawValue }?.isEnabled == false)
        #expect(initialViewMenu.items.first { $0.representedObject as? String == AppSection.dashboard.rawValue }?.isEnabled == true)
    }

    @Test("main menu restores after system replacement")
    func mainMenuRestoresAfterSystemReplacement() {
        let application = NSApplication.shared
        let originalMainMenu = application.mainMenu

        defer {
            application.mainMenu = originalMainMenu
        }

        let snapshot = ContainerDesktopMenuLocalizationSnapshot(
            language: .en,
            selectedSection: .dashboard
        )
        let actions = ContainerDesktopMainMenuActions(
            openMain: { _ in },
            openSettings: {},
            checkForUpdates: {},
            reload: {}
        )
        ContainerDesktopMainMenuController.shared.configure(snapshot: snapshot, actions: actions)

        let systemMenu = NSMenu(title: "SwiftUI Default")
        for title in ["ContainerDesktop", "Edit", "View", "Window", "Help"] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = NSMenu(title: title)
            systemMenu.addItem(item)
        }
        application.mainMenu = systemMenu

        ContainerDesktopMainMenuController.shared.reinstallMenuIfNeeded()

        #expect(application.mainMenu?.items.map(\.title) == ["ContainerDesktop", "Edit", "View", "Help"])
        #expect(application.mainMenu?.items[2].submenu?.items.filter { !$0.isSeparatorItem }.map(\.title) == [
            "Refresh",
            "Docker Convert",
            "Dashboard",
            "Containers",
            "Machines",
            "Images",
            "Volumes",
            "Networks",
            "Compose",
            "Observe",
            "Registries",
            "System",
        ])
    }

    @Test("app avoids SwiftUI commands for desktop main menu")
    func appAvoidsSwiftUICommandsForDesktopMainMenu() throws {
        let appSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift",
            encoding: .utf8
        )
        let controllerSource = try String(
            contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopMainMenuController.swift",
            encoding: .utf8
        )

        #expect(!appSource.contains("ContainerDesktopCommands"))
        #expect(!appSource.contains(".commands"))
        #expect(!appSource.contains("WindowGroup("))
        #expect(!appSource.contains("MenuBarExtra"))
        #expect(appSource.contains("NSApplication.shared"))
        #expect(appSource.contains("NSStatusBar.system.statusItem"))
        #expect(controllerSource.contains("NSApp.mainMenu"))
        #expect(controllerSource.contains("reinstallMenuIfNeeded"))
        #expect(!controllerSource.contains("NSApplication.didUpdateNotification"))
        #expect(!FileManager.default.fileExists(atPath: "Sources/ContainerDesktop/App/ContainerDesktopMainMenuInstaller.swift"))
    }

    @Test("main window activation reuses existing window")
    func mainWindowActivationReusesExistingWindow() {
        let firstWindow = NSWindow()
        let secondWindow = NSWindow()
        firstWindow.isReleasedWhenClosed = false
        secondWindow.isReleasedWhenClosed = false
        ContainerDesktopMainWindow.mark(firstWindow)
        ContainerDesktopMainWindow.mark(secondWindow)

        defer {
            firstWindow.close()
            secondWindow.close()
        }

        var openCount = 0
        ContainerDesktopMainWindow.activateOrOpen {
            openCount += 1
        }

        #expect(openCount == 0)
        #expect(ContainerDesktopMainWindow.find() === firstWindow)
        #expect(!firstWindow.isReleasedWhenClosed)
        #expect(!secondWindow.isVisible)
    }
}
