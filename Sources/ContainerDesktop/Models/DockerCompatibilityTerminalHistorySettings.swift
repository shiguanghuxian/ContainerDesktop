import Foundation

enum DockerCompatibilityTerminalHistorySettings {
    static let outputEventLimitDefaultsKey = "containerdesktop.dockerCompatibilityTerminal.outputEventLimit"
    static let defaultOutputEventLimit = 8_000
    static let minimumOutputEventLimit = 1_000
    static let maximumOutputEventLimit = 50_000
    static let outputEventLimitStep = 1_000

    static var outputEventLimitRange: ClosedRange<Int> {
        minimumOutputEventLimit...maximumOutputEventLimit
    }

    static func storedOutputEventLimit(in defaults: UserDefaults = .containerDesktopShared) -> Int {
        guard defaults.object(forKey: outputEventLimitDefaultsKey) != nil else {
            return defaultOutputEventLimit
        }
        return clampedOutputEventLimit(defaults.integer(forKey: outputEventLimitDefaultsKey))
    }

    static func clampedOutputEventLimit(_ value: Int) -> Int {
        min(max(value, minimumOutputEventLimit), maximumOutputEventLimit)
    }
}
