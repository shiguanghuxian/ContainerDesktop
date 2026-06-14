import Foundation

enum RuntimeOperationKey {
    static let systemStart = "system:start"
    static let systemStop = "system:stop"
    static let containerRun = "container:run"
    static let machineCreate = "machine:create"
    static let imagePull = "image:pull"
    static let volumeCreate = "volume:create"
    static let volumePrune = "volume:prune"
    static let networkCreate = "network:create"

    static func containerStart(_ id: String) -> String {
        "container:start:\(id)"
    }

    static func containerStop(_ id: String) -> String {
        "container:stop:\(id)"
    }

    static func containerDelete(_ id: String) -> String {
        "container:delete:\(id)"
    }

    static func machineBoot(_ id: String) -> String {
        "machine:boot:\(id)"
    }

    static func machineStop(_ id: String) -> String {
        "machine:stop:\(id)"
    }

    static func machineDelete(_ id: String) -> String {
        "machine:delete:\(id)"
    }

    static func machineSetDefault(_ id: String) -> String {
        "machine:default:\(id)"
    }

    static func imageDelete(_ reference: String) -> String {
        "image:delete:\(reference)"
    }

    static func volumeDelete(_ name: String) -> String {
        "volume:delete:\(name)"
    }

    static func networkDelete(_ name: String) -> String {
        "network:delete:\(name)"
    }
}
