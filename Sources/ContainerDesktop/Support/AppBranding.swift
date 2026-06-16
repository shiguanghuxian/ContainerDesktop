import Foundation

enum AppBranding {
    static let displayName = "Container Desktop"
    static let legacyDisplayName = "ContainerDesktop"

    static var logPrefix: String {
        "[\(displayName)]"
    }

    static var legacyLogPrefix: String {
        "[\(legacyDisplayName)]"
    }
}
