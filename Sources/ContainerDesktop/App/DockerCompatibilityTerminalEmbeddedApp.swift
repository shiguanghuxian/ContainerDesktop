import AppKit
import Foundation

enum DockerCompatibilityTerminalEmbeddedApp {
    static let bundleName = "Docker Compatibility Terminal.app"
    static let openWorkingDirectoryNotification = Notification.Name("com.shiguanghuxian.ContainerDesktop.DockerCompatibilityTerminal.openWorkingDirectory")
    static let workingDirectoryUserInfoKey = "workingDirectory"

    static func bundleURL(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL
            .appending(path: "Contents")
            .appending(path: "Applications")
            .appending(path: bundleName)
    }

    @MainActor
    static func open(workingDirectory: URL) -> Bool {
        let appURL = bundleURL()
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return false
        }

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: DockerCompatibilityTerminalApplication.bundleIdentifier).first {
            postOpenWorkingDirectoryNotification(workingDirectory)
            runningApp.activate(options: [])
            return true
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [
            DockerCompatibilityTerminalApplication.workingDirectoryFlag,
            workingDirectory.path,
        ]
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        return true
    }

    private static func postOpenWorkingDirectoryNotification(_ workingDirectory: URL) {
        DistributedNotificationCenter.default().postNotificationName(
            openWorkingDirectoryNotification,
            object: nil,
            userInfo: [
                workingDirectoryUserInfoKey: workingDirectory.path,
            ],
            deliverImmediately: true
        )
    }
}
