import Foundation
import Testing
@testable import ContainerDesktop

@MainActor
@Suite("Launch at login")
struct LaunchAtLoginStoreTests {
    @Test("enables login item through service")
    func enablesLoginItemThroughService() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let store = LaunchAtLoginStore(service: service)

        #expect(store.isEnabled == false)
        store.setEnabled(true)

        #expect(service.registerCallCount == 1)
        #expect(service.unregisterCallCount == 0)
        #expect(store.status == .enabled)
        #expect(store.isEnabled == true)
        #expect(store.errorMessage == nil)
        #expect(store.isUpdating == false)
    }

    @Test("disables login item through service")
    func disablesLoginItemThroughService() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let store = LaunchAtLoginStore(service: service)

        #expect(store.isEnabled == true)
        store.setEnabled(false)

        #expect(service.registerCallCount == 0)
        #expect(service.unregisterCallCount == 1)
        #expect(store.status == .notRegistered)
        #expect(store.isEnabled == false)
        #expect(store.errorMessage == nil)
    }

    @Test("failed update refreshes actual service status")
    func failedUpdateRefreshesActualServiceStatus() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.registerError = FakeLaunchAtLoginError(message: "registration failed")
        let store = LaunchAtLoginStore(service: service)

        store.setEnabled(true)

        #expect(service.registerCallCount == 1)
        #expect(store.status == .notRegistered)
        #expect(store.isEnabled == false)
        #expect(store.errorMessage == "registration failed")
        #expect(store.isUpdating == false)
    }

    @Test("requires approval is represented as enabled but can be cleared")
    func requiresApprovalIsEnabledButCanBeCleared() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)
        let store = LaunchAtLoginStore(service: service)

        #expect(store.isEnabled == true)
        #expect(store.canToggle == true)
        store.setEnabled(false)

        #expect(service.unregisterCallCount == 1)
        #expect(store.status == .notRegistered)
        #expect(store.isEnabled == false)
    }

    @Test("unavailable status disables toggling")
    func unavailableStatusDisablesToggling() {
        let service = FakeLaunchAtLoginService(status: .unavailable("not in app bundle"))
        let store = LaunchAtLoginStore(service: service)

        #expect(store.isEnabled == false)
        #expect(store.canToggle == false)
        store.setEnabled(true)

        #expect(service.registerCallCount == 0)
        #expect(service.unregisterCallCount == 0)
        #expect(store.status == .unavailable("not in app bundle"))
        #expect(store.errorMessage == nil)
    }

    @Test("service maps ServiceManagement not found to not registered inside app bundle")
    func serviceMapsServiceManagementNotFoundToNotRegisteredInsideAppBundle() {
        let service = LaunchAtLoginService(
            bundleURLProvider: {
                URL(fileURLWithPath: "/Applications/ContainerDesktop.app")
            },
            executableURLProvider: {
                URL(fileURLWithPath: "/Applications/ContainerDesktop.app/Contents/MacOS/ContainerDesktop")
            },
            serviceStatusProvider: { .notFound }
        )

        #expect(service.status == .notRegistered)
    }

    @Test("service resolves app bundle from nested bundle URL")
    func serviceResolvesAppBundleFromNestedBundleURL() {
        let service = LaunchAtLoginService(
            bundleURLProvider: {
                URL(fileURLWithPath: "/Applications/ContainerDesktop.app/Contents/MacOS")
            },
            executableURLProvider: { nil },
            serviceStatusProvider: { .notFound }
        )

        #expect(service.status == .notRegistered)
    }

    @Test("service resolves app bundle from executable URL")
    func serviceResolvesAppBundleFromExecutableURL() {
        let service = LaunchAtLoginService(
            bundleURLProvider: {
                URL(fileURLWithPath: "/tmp/ContainerDesktop")
            },
            executableURLProvider: {
                URL(fileURLWithPath: "/Applications/ContainerDesktop.app/Contents/MacOS/ContainerDesktop")
            },
            serviceStatusProvider: { .notFound }
        )

        #expect(service.status == .notRegistered)
    }

    @Test("service reports unavailable outside app bundle")
    func serviceReportsUnavailableOutsideAppBundle() {
        let service = LaunchAtLoginService(
            bundleURLProvider: {
                URL(fileURLWithPath: "/tmp/ContainerDesktop")
            },
            executableURLProvider: {
                URL(fileURLWithPath: "/tmp/ContainerDesktop")
            },
            serviceStatusProvider: { .enabled }
        )

        guard case .unavailable(let detail) = service.status else {
            Issue.record("Expected unavailable launch status")
            return
        }
        #expect(detail.contains("/tmp/ContainerDesktop"))
    }

    @Test("settings wiring keeps ServiceManagement in service layer")
    func settingsWiringKeepsServiceManagementInServiceLayer() throws {
        let appSource = try String(contentsOfFile: "Sources/ContainerDesktop/App/ContainerDesktopApp.swift", encoding: .utf8)
        let settingsSource = try String(contentsOfFile: "Sources/ContainerDesktop/Views/SettingsView.swift", encoding: .utf8)
        let systemSettingsSource = try String(contentsOfFile: "Sources/ContainerDesktop/Views/System/SystemConfigEditorView.swift", encoding: .utf8)
        let serviceSource = try String(contentsOfFile: "Sources/ContainerDesktop/Services/LaunchAtLoginService.swift", encoding: .utf8)
        let preferencesSource = try String(contentsOfFile: "Sources/ContainerDesktop/Support/AppPreferences.swift", encoding: .utf8)

        #expect(appSource.contains("private let launchAtLoginStore = LaunchAtLoginStore()"))
        #expect(appSource.contains("launchAtLoginStore: launchAtLoginStore"))
        #expect(settingsSource.contains("@Bindable var launchAtLoginStore: LaunchAtLoginStore"))
        #expect(settingsSource.contains("SystemConfigEditorView("))
        #expect(systemSettingsSource.contains("@Bindable var launchAtLoginStore: LaunchAtLoginStore"))
        #expect(systemSettingsSource.contains("launchAtLoginBinding"))
        #expect(systemSettingsSource.contains("language.t(.launchAtLogin)"))
        #expect(systemSettingsSource.contains("language.t(.launchAtLoginSubtitle)"))
        #expect(systemSettingsSource.contains("SystemTerminalSettingsPanel()"))
        #expect(systemSettingsSource.contains("DockerCompatibilityTerminalStrings.systemTerminalTitle(language)"))
        #expect(systemSettingsSource.contains("DockerCompatibilityTerminalStrings.systemTerminalSubtitle(language)"))
        #expect(!systemSettingsSource.contains("SMAppService"))
        #expect(serviceSource.contains("import ServiceManagement"))
        #expect(serviceSource.contains("SMAppService.mainApp"))
        #expect(serviceSource.contains("serviceStatusProvider"))
        #expect(serviceSource.contains("appBundleAncestor"))
        #expect(preferencesSource.contains("case launchAtLogin"))
        #expect(preferencesSource.contains("开机自动启动"))
        #expect(preferencesSource.contains("Launch at Login"))
    }
}

@MainActor
private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }
}

private struct FakeLaunchAtLoginError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}
