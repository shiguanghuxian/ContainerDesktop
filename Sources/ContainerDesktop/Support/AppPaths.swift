import Foundation

enum AppPaths {
    static let bundleIdentifier = "com.shiguanghuxian.ContainerDesktop"
    static let minimumSystemVersion = "26.0"

    static var homeDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var containerConfigURL: URL {
        homeDirectory
            .appending(path: ".config")
            .appending(path: "container")
            .appending(path: "config.toml")
    }

    static var containerConfigDirectory: URL {
        containerConfigURL.deletingLastPathComponent()
    }

    static var appConfigDirectory: URL {
        homeDirectory
            .appending(path: ".config")
            .appending(path: "containerdesktop")
    }

    static var composeProjectsURL: URL {
        appConfigDirectory
            .appending(path: "compose-projects.json")
    }

    static var operationHistoryURL: URL {
        appConfigDirectory
            .appending(path: "operation-history.json")
    }

    static var appUpdateCacheDirectory: URL {
        appConfigDirectory
            .appending(path: "app-update-cache")
    }
}
