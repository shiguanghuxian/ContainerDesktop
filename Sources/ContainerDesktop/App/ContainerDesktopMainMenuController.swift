import AppKit
import SwiftUI

struct ContainerDesktopMenuLocalizationSnapshot: Equatable, Sendable {
    struct PageItem: Equatable, Sendable {
        var rawValue: String
        var title: String
        var isEnabled: Bool
    }

    var appMenuTitle: String
    var aboutApp: String
    var checkForUpdates: String
    var settings: String
    var hideApp: String
    var hideOthers: String
    var showAll: String
    var quit: String
    var editMenuTitle: String
    var viewMenuTitle: String
    var helpMenuTitle: String
    var undo: String
    var redo: String
    var cut: String
    var copy: String
    var paste: String
    var selectAll: String
    var reload: String
    var help: String
    var commandConverter: String
    var dockerCompatibilityTerminal: String
    var dockerCompatibilitySystemTerminal: String
    var selectedSectionRaw: String
    var pageItems: [PageItem]

    init(language: AppLanguage, selectedSection: AppSection) {
        let isChinese = language.resolved == .zhHans
        let appName = AppBranding.displayName
        appMenuTitle = appName
        aboutApp = isChinese ? "关于 \(appName)" : "About \(appName)"
        checkForUpdates = isChinese ? "检查更新…" : "Check for Updates..."
        settings = language.t(.settings)
        hideApp = isChinese ? "隐藏 \(appName)" : "Hide \(appName)"
        hideOthers = isChinese ? "隐藏其他" : "Hide Others"
        showAll = isChinese ? "全部显示" : "Show All"
        quit = isChinese ? "退出 \(appName)" : "Quit \(appName)"
        editMenuTitle = isChinese ? "编辑" : "Edit"
        viewMenuTitle = isChinese ? "显示" : "View"
        helpMenuTitle = language.t(.help)
        undo = isChinese ? "撤销" : "Undo"
        redo = isChinese ? "重做" : "Redo"
        cut = isChinese ? "剪切" : "Cut"
        copy = isChinese ? "复制" : "Copy"
        paste = isChinese ? "粘贴" : "Paste"
        selectAll = isChinese ? "全选" : "Select All"
        reload = language.t(.refresh)
        help = language.t(.help)
        commandConverter = language.t(.commandConverter)
        dockerCompatibilityTerminal = isChinese ? "Docker 兼容终端" : "Docker Compatibility Terminal"
        dockerCompatibilitySystemTerminal = isChinese ? "兼容系统终端" : "Compatible System Terminal"
        selectedSectionRaw = selectedSection.rawValue
        pageItems = AppSection.menuPageSections.map { section in
            PageItem(
                rawValue: section.rawValue,
                title: section.title(language: language),
                isEnabled: selectedSection != section
            )
        }
    }

    func hasSameVisibleContent(as other: ContainerDesktopMenuLocalizationSnapshot) -> Bool {
        self.appMenuTitle == other.appMenuTitle
            && self.aboutApp == other.aboutApp
            && self.checkForUpdates == other.checkForUpdates
            && self.settings == other.settings
            && self.hideApp == other.hideApp
            && self.hideOthers == other.hideOthers
            && self.showAll == other.showAll
            && self.quit == other.quit
            && self.editMenuTitle == other.editMenuTitle
            && self.viewMenuTitle == other.viewMenuTitle
            && self.helpMenuTitle == other.helpMenuTitle
            && self.undo == other.undo
            && self.redo == other.redo
            && self.cut == other.cut
            && self.copy == other.copy
            && self.paste == other.paste
            && self.selectAll == other.selectAll
            && self.reload == other.reload
            && self.help == other.help
            && self.commandConverter == other.commandConverter
            && self.dockerCompatibilityTerminal == other.dockerCompatibilityTerminal
            && self.dockerCompatibilitySystemTerminal == other.dockerCompatibilitySystemTerminal
            && self.pageItems.map(\.rawValue) == other.pageItems.map(\.rawValue)
            && self.pageItems.map(\.title) == other.pageItems.map(\.title)
    }
}

struct ContainerDesktopMainMenuActions {
    var openMain: @MainActor (AppSection) -> Void
    var openSettings: @MainActor () -> Void
    var openDockerCompatibilityTerminal: @MainActor () -> Void
    var openDockerCompatibilitySystemTerminal: @MainActor () -> Void
    var checkForUpdates: @MainActor () -> Void
    var reload: @MainActor () -> Void
}

@MainActor
final class ContainerDesktopMainMenuController: NSObject, NSMenuDelegate, NSMenuItemValidation {
    static let shared = ContainerDesktopMainMenuController()

    private var snapshot: ContainerDesktopMenuLocalizationSnapshot?
    private var actions: ContainerDesktopMainMenuActions?
    private var reinstallWorkItem: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    private var mainMenu: NSMenu?
    private var appMenuItem: NSMenuItem?
    private var editMenuItem: NSMenuItem?
    private var viewMenuItem: NSMenuItem?
    private var helpMenuItem: NSMenuItem?

    private override init() {
        super.init()

        let notificationCenter = NotificationCenter.default
        let refreshNames: [Notification.Name] = [
            NSApplication.didFinishLaunchingNotification,
            NSApplication.didBecomeActiveNotification,
        ]
        observers = refreshNames.map { name in
            notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scheduleReinstallMenuIfNeeded()
                }
            }
        }
    }

    func configure(snapshot: ContainerDesktopMenuLocalizationSnapshot, actions: ContainerDesktopMainMenuActions) {
        self.actions = actions
        let previousSnapshot = self.snapshot
        guard previousSnapshot != snapshot || isManagedMenuInstalled == false else { return }
        syncMenu(snapshot: snapshot, previousSnapshot: previousSnapshot)
        self.snapshot = snapshot
    }

    func reinstallMenuIfNeeded() {
        guard let snapshot, isManagedMenuInstalled == false else { return }
        installMenu(snapshot: snapshot)
    }

    func updateSelectedSection(_ section: AppSection) {
        guard var snapshot else { return }
        snapshot.selectedSectionRaw = section.rawValue
        snapshot.pageItems = snapshot.pageItems.map { page in
            ContainerDesktopMenuLocalizationSnapshot.PageItem(
                rawValue: page.rawValue,
                title: page.title,
                isEnabled: page.rawValue != section.rawValue
            )
        }
        self.snapshot = snapshot
        updateViewValidation()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === editMenuItem?.submenu {
            updateEditValidation()
        } else if menu === viewMenuItem?.submenu {
            updateViewValidation()
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let actionName = menuItem.representedObject as? String {
            if AppSection(rawValue: actionName) != nil {
                return actionName != selectedSection.rawValue
            }
            return canPerformResponderAction(Selector(actionName))
        }
        return true
    }

    private var selectedSection: AppSection {
        let rawValue = snapshot?.selectedSectionRaw
            ?? UserDefaults.standard.string(forKey: "containerdesktop.selected.section")
            ?? AppSection.dashboard.rawValue
        return AppSection(rawValue: rawValue) ?? .dashboard
    }

    private var isManagedMenuInstalled: Bool {
        guard let mainMenu = NSApp.mainMenu,
              mainMenu === self.mainMenu,
              let appMenuItem,
              let editMenuItem,
              let viewMenuItem,
              let helpMenuItem,
              mainMenu.items.count == 4
        else {
            return false
        }

        return mainMenu.items[0] === appMenuItem
            && mainMenu.items[1] === editMenuItem
            && mainMenu.items[2] === viewMenuItem
            && mainMenu.items[3] === helpMenuItem
    }

    private func syncMenu(
        snapshot: ContainerDesktopMenuLocalizationSnapshot,
        previousSnapshot: ContainerDesktopMenuLocalizationSnapshot?
    ) {
        if isManagedMenuInstalled {
            if let previousSnapshot, snapshot.hasSameVisibleContent(as: previousSnapshot) {
                updateViewValidation()
                return
            }
            applySnapshotInPlace(snapshot)
        } else {
            installMenu(snapshot: snapshot)
            scheduleReinstallMenuIfNeeded()
        }
    }

    private func installMenu(snapshot: ContainerDesktopMenuLocalizationSnapshot) {
        let mainMenu = NSMenu(title: "MainMenu")
        mainMenu.autoenablesItems = false

        let appMenuItem = NSMenuItem(title: snapshot.appMenuTitle, action: nil, keyEquivalent: "")
        let editMenuItem = NSMenuItem(title: snapshot.editMenuTitle, action: nil, keyEquivalent: "")
        let viewMenuItem = NSMenuItem(title: snapshot.viewMenuTitle, action: nil, keyEquivalent: "")
        let helpMenuItem = NSMenuItem(title: snapshot.helpMenuTitle, action: nil, keyEquivalent: "")

        let appMenu = self.appMenu(snapshot: snapshot)
        let editMenu = self.editMenu(snapshot: snapshot)
        let viewMenu = self.viewMenu(snapshot: snapshot)
        let helpMenu = self.helpMenu(snapshot: snapshot)

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(editMenuItem)
        mainMenu.addItem(viewMenuItem)
        mainMenu.addItem(helpMenuItem)

        mainMenu.setSubmenu(appMenu, for: appMenuItem)
        mainMenu.setSubmenu(editMenu, for: editMenuItem)
        mainMenu.setSubmenu(viewMenu, for: viewMenuItem)
        mainMenu.setSubmenu(helpMenu, for: helpMenuItem)

        self.mainMenu = mainMenu
        self.appMenuItem = appMenuItem
        self.editMenuItem = editMenuItem
        self.viewMenuItem = viewMenuItem
        self.helpMenuItem = helpMenuItem

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = nil
        NSApp.helpMenu = helpMenu
    }

    private func applySnapshotInPlace(_ snapshot: ContainerDesktopMenuLocalizationSnapshot) {
        guard isManagedMenuInstalled,
              let mainMenu,
              let appMenuItem,
              let editMenuItem,
              let viewMenuItem,
              let helpMenuItem
        else {
            installMenu(snapshot: snapshot)
            return
        }

        appMenuItem.title = snapshot.appMenuTitle
        editMenuItem.title = snapshot.editMenuTitle
        viewMenuItem.title = snapshot.viewMenuTitle
        helpMenuItem.title = snapshot.helpMenuTitle

        let appMenu = self.appMenu(snapshot: snapshot)
        let editMenu = self.editMenu(snapshot: snapshot)
        let viewMenu = self.viewMenu(snapshot: snapshot)
        let helpMenu = self.helpMenu(snapshot: snapshot)

        mainMenu.setSubmenu(appMenu, for: appMenuItem)
        mainMenu.setSubmenu(editMenu, for: editMenuItem)
        mainMenu.setSubmenu(viewMenu, for: viewMenuItem)
        mainMenu.setSubmenu(helpMenu, for: helpMenuItem)
        NSApp.windowsMenu = nil
        NSApp.helpMenu = helpMenu
    }

    private func scheduleReinstallMenuIfNeeded() {
        guard NSApp.isRunning else { return }
        reinstallWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.reinstallMenuIfNeeded()
            }
        }
        reinstallWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func appMenu(snapshot: ContainerDesktopMenuLocalizationSnapshot) -> NSMenu {
        let menu = NSMenu(title: snapshot.appMenuTitle)
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(item(snapshot.aboutApp, action: #selector(openAbout(_:))))
        menu.addItem(item(snapshot.checkForUpdates, action: #selector(checkForUpdates(_:))))
        menu.addItem(.separator())
        menu.addItem(item(snapshot.settings, action: #selector(openSettings(_:)), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(snapshot.hideApp, action: #selector(hideApp(_:)), key: "h"))
        menu.addItem(item(snapshot.hideOthers, action: #selector(hideOthers(_:)), key: "h", modifiers: [.command, .option]))
        menu.addItem(item(snapshot.showAll, action: #selector(showAll(_:))))
        menu.addItem(.separator())
        menu.addItem(item(snapshot.quit, action: #selector(quit(_:)), key: "q"))
        return menu
    }

    private func editMenu(snapshot: ContainerDesktopMenuLocalizationSnapshot) -> NSMenu {
        let menu = NSMenu(title: snapshot.editMenuTitle)
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(responderItem(snapshot.undo, action: Selector(("undo:")), key: "z"))
        menu.addItem(responderItem(snapshot.redo, action: Selector(("redo:")), key: "Z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(responderItem(snapshot.cut, action: #selector(NSText.cut(_:)), key: "x"))
        menu.addItem(responderItem(snapshot.copy, action: #selector(NSText.copy(_:)), key: "c"))
        menu.addItem(responderItem(snapshot.paste, action: #selector(NSText.paste(_:)), key: "v"))
        menu.addItem(.separator())
        menu.addItem(responderItem(snapshot.selectAll, action: #selector(NSText.selectAll(_:)), key: "a"))
        return menu
    }

    private func viewMenu(snapshot: ContainerDesktopMenuLocalizationSnapshot) -> NSMenu {
        let menu = NSMenu(title: snapshot.viewMenuTitle)
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(item(snapshot.reload, action: #selector(reload(_:)), key: "r"))
        let commandConverterItem = item(snapshot.commandConverter, action: #selector(openCommandConverter(_:)))
        commandConverterItem.representedObject = AppSection.commandConverter.rawValue
        commandConverterItem.isEnabled = snapshot.selectedSectionRaw != AppSection.commandConverter.rawValue
        menu.addItem(commandConverterItem)
        menu.addItem(item(snapshot.dockerCompatibilityTerminal, action: #selector(openDockerCompatibilityTerminal(_:)), key: "t", modifiers: [.command, .option]))
        menu.addItem(item(snapshot.dockerCompatibilitySystemTerminal, action: #selector(openDockerCompatibilitySystemTerminal(_:))))
        menu.addItem(.separator())

        for page in snapshot.pageItems {
            let item = self.item(page.title, action: #selector(openPage(_:)))
            item.representedObject = page.rawValue
            item.isEnabled = page.isEnabled
            menu.addItem(item)
        }

        return menu
    }

    private func helpMenu(snapshot: ContainerDesktopMenuLocalizationSnapshot) -> NSMenu {
        let menu = NSMenu(title: snapshot.helpMenuTitle)
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(item(snapshot.help, action: #selector(openHelp(_:)), key: "?", modifiers: [.command, .shift]))
        menu.addItem(item(snapshot.aboutApp, action: #selector(openAbout(_:))))
        return menu
    }

    private func item(
        _ title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = key.isEmpty ? [] : modifiers
        return item
    }

    private func responderItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = self.item(title, action: #selector(sendResponderAction(_:)), key: key, modifiers: modifiers)
        item.representedObject = NSStringFromSelector(action)
        item.isEnabled = canPerformResponderAction(action)
        return item
    }

    private func updateEditValidation() {
        for item in editMenuItem?.submenu?.items ?? [] {
            guard let actionName = item.representedObject as? String else { continue }
            item.isEnabled = canPerformResponderAction(Selector(actionName))
        }
    }

    private func updateViewValidation() {
        for item in viewMenuItem?.submenu?.items ?? [] {
            guard let rawValue = item.representedObject as? String,
                  AppSection(rawValue: rawValue) != nil
            else {
                continue
            }
            item.isEnabled = rawValue != selectedSection.rawValue
        }
    }

    private func canPerformResponderAction(_ action: Selector) -> Bool {
        NSApp.target(forAction: action, to: nil, from: nil) != nil
    }

    @objc private func sendResponderAction(_ sender: NSMenuItem) {
        guard let actionName = sender.representedObject as? String else { return }
        NSApp.sendAction(Selector(actionName), to: nil, from: nil)
        updateEditValidation()
    }

    @objc private func openPage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let section = AppSection(rawValue: rawValue)
        else {
            return
        }
        actions?.openMain(section)
        updateSelectedSection(section)
    }

    @objc private func openCommandConverter(_ sender: NSMenuItem) {
        actions?.openMain(.commandConverter)
        updateSelectedSection(.commandConverter)
    }

    @objc private func openDockerCompatibilityTerminal(_ sender: NSMenuItem) {
        actions?.openDockerCompatibilityTerminal()
    }

    @objc private func openDockerCompatibilitySystemTerminal(_ sender: NSMenuItem) {
        actions?.openDockerCompatibilitySystemTerminal()
    }

    @objc private func openHelp(_ sender: NSMenuItem) {
        actions?.openMain(.help)
        updateSelectedSection(.help)
    }

    @objc private func openAbout(_ sender: NSMenuItem) {
        actions?.openMain(.about)
        updateSelectedSection(.about)
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        actions?.openSettings()
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        actions?.checkForUpdates()
    }

    @objc private func reload(_ sender: NSMenuItem) {
        actions?.reload()
    }

    @objc private func hideApp(_ sender: NSMenuItem) {
        NSApp.hide(nil)
    }

    @objc private func hideOthers(_ sender: NSMenuItem) {
        NSApp.hideOtherApplications(nil)
    }

    @objc private func showAll(_ sender: NSMenuItem) {
        NSApp.unhideAllApplications(nil)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }
}

private extension AppSection {
    static var menuPageSections: [AppSection] {
        [
            .dashboard,
            .containers,
            .machines,
            .images,
            .volumes,
            .networks,
            .compose,
            .observability,
            .registries,
            .system,
        ]
    }
}
