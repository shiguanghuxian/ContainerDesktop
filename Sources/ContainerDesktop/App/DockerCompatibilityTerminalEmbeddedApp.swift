import AppKit
import Foundation

enum DockerCompatibilityTerminalEmbeddedApp {
    static let bundleName = "Docker Compatibility Terminal.app"
    static let openWorkingDirectoryNotification = Notification.Name("com.shiguanghuxian.ContainerDesktop.DockerCompatibilityTerminal.openWorkingDirectory")
    static let workingDirectoryUserInfoKey = "workingDirectory"
    static let shellTargetKindUserInfoKey = "shellTargetKind"
    static let shellTargetIDUserInfoKey = "shellTargetID"

    static func bundleURL(in bundle: Bundle = .main) -> URL {
        bundle.bundleURL
            .appending(path: "Contents")
            .appending(path: "Applications")
            .appending(path: bundleName)
    }

    @MainActor
    static func open(workingDirectory: URL) -> Bool {
        open(request: DockerCompatibilityTerminalOpenRequest(workingDirectory: workingDirectory))
    }

    @MainActor
    static func open(request: DockerCompatibilityTerminalOpenRequest) -> Bool {
        let appURL = bundleURL()
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            return false
        }

        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: DockerCompatibilityTerminalApplication.bundleIdentifier).first {
            postOpenWorkingDirectoryNotification(request)
            runningApp.activate(options: [])
            return true
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        configuration.arguments = DockerCompatibilityTerminalApplication.launchArguments(for: request)
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        return true
    }

    static func openRequest(from userInfo: [AnyHashable: Any]?) -> DockerCompatibilityTerminalOpenRequest? {
        guard let path = userInfo?[workingDirectoryUserInfoKey] as? String,
              let workingDirectory = DockerCompatibilityTerminalServiceRequest.workingDirectory(fromPath: path)
        else {
            return nil
        }
        let shellTarget = TerminalShellTarget(
            kindRawValue: userInfo?[shellTargetKindUserInfoKey] as? String,
            id: userInfo?[shellTargetIDUserInfoKey] as? String
        )
        return DockerCompatibilityTerminalOpenRequest(
            workingDirectory: workingDirectory,
            shellTarget: shellTarget
        )
    }

    private static func postOpenWorkingDirectoryNotification(_ request: DockerCompatibilityTerminalOpenRequest) {
        var userInfo: [String: String] = [
            workingDirectoryUserInfoKey: request.workingDirectory.path,
        ]
        if let shellTarget = request.shellTarget {
            userInfo[shellTargetKindUserInfoKey] = shellTarget.kind.rawValue
            userInfo[shellTargetIDUserInfoKey] = shellTarget.resourceID
        }
        DistributedNotificationCenter.default().postNotificationName(
            openWorkingDirectoryNotification,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }
}
