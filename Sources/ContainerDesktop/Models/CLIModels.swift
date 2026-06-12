import Foundation

struct EnvironmentProbe: Codable, Hashable, Sendable {
    var macOSVersion: String
    var architecture: String
    var containerAvailable: Bool
    var containerComposeAvailable: Bool
    var systemRunning: Bool
    var systemVersion: String?
    var errorMessage: String?
}

struct ContainerSummary: Identifiable, Codable, Hashable, Sendable {
    struct Configuration: Codable, Hashable, Sendable {
        struct Image: Codable, Hashable, Sendable {
            var reference: String
        }

        struct Platform: Codable, Hashable, Sendable {
            var os: String
            var architecture: String
        }

        struct Resources: Codable, Hashable, Sendable {
            var cpus: Int
            var memoryInBytes: Int64
        }

        var id: String
        var image: Image
        var platform: Platform
        var resources: Resources
        var creationDate: Date?
    }

    struct Status: Codable, Hashable, Sendable {
        struct NetworkAttachment: Codable, Hashable, Sendable {
            var ipv4Address: String?
        }

        var state: String
        var networks: [NetworkAttachment]
        var startedDate: Date?
    }

    var id: String { configuration.id }
    var configuration: Configuration
    var status: Status

    var imageName: String { configuration.image.reference }
    var platformName: String { "\(configuration.platform.os)/\(configuration.platform.architecture)" }
    var cpuCount: Int { configuration.resources.cpus }
    var memoryDisplay: String { ByteCountFormatter.string(fromByteCount: configuration.resources.memoryInBytes, countStyle: .memory) }
    var state: String { status.state }
    var primaryIP: String { status.networks.compactMap(\.ipv4Address).first ?? "—" }
    var startedText: String {
        guard let startedDate = status.startedDate else { return "—" }
        return startedDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ImageSummary: Identifiable, Codable, Hashable, Sendable {
    struct Configuration: Codable, Hashable, Sendable {
        struct Descriptor: Codable, Hashable, Sendable {
            var digest: String
        }

        var name: String
        var creationDate: Date?
        var descriptor: Descriptor
    }

    struct Variant: Codable, Hashable, Sendable {
        struct Platform: Codable, Hashable, Sendable {
            var os: String
            var architecture: String
        }

        var platform: Platform
        var digest: String
        var size: Int64
    }

    var id: String {
        let digest = configuration.descriptor.digest
        if let colonIndex = digest.firstIndex(of: ":") {
            return String(digest[digest.index(after: colonIndex)...])
        }
        return digest
    }

    var configuration: Configuration
    var variants: [Variant] = []

    var reference: String { configuration.name }
    var tag: String {
        guard let colonIndex = configuration.name.lastIndex(of: ":") else { return "latest" }
        return String(configuration.name[configuration.name.index(after: colonIndex)...])
    }
    var digest: String { configuration.descriptor.digest }
    var sizeDisplay: String {
        let bytes = variants.reduce(Int64(0)) { $0 + $1.size }
        guard bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    var createdText: String {
        guard let creationDate = configuration.creationDate else { return "—" }
        return creationDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct VolumeSummary: Identifiable, Codable, Hashable, Sendable {
    struct Configuration: Codable, Hashable, Sendable {
        var name: String
        var driver: String
        var format: String
        var source: String
        var creationDate: Date
        var labels: [String: String]
        var options: [String: String]
        var sizeInBytes: UInt64?
    }

    var configuration: Configuration

    var id: String { configuration.name }
    var name: String { configuration.name }
    var driver: String { configuration.driver }
    var format: String { configuration.format }
    var source: String { configuration.source }
    var isAnonymous: Bool { configuration.labels["com.apple.container.resource.anonymous"] != nil }
    var createdText: String { configuration.creationDate.formatted(date: .abbreviated, time: .shortened) }
    var typeText: String { isAnonymous ? "anonymous" : "named" }
    var sizeDisplay: String {
        guard let size = configuration.sizeInBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

struct NetworkSummary: Identifiable, Codable, Hashable, Sendable {
    struct Configuration: Codable, Hashable, Sendable {
        var name: String
        var creationDate: Date
        var mode: String
        var ipv4Subnet: String?
        var ipv6Subnet: String?
        var labels: [String: String]
        var plugin: String
        var options: [String: String]
    }

    struct Status: Codable, Hashable, Sendable {
        var ipv4Subnet: String
    }

    var configuration: Configuration
    var status: Status

    var id: String { configuration.name }
    var name: String { configuration.name }
    var subnetText: String { status.ipv4Subnet }
    var createdText: String { configuration.creationDate.formatted(date: .abbreviated, time: .shortened) }
}

struct RegistrySummary: Identifiable, Codable, Hashable, Sendable {
    var id: String { server }
    var server: String
}

struct ContainerStatsSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var blockReadBytes: Int64
    var blockWriteBytes: Int64
    var cpuUsageUsec: Int64
    var memoryLimitBytes: Int64
    var memoryUsageBytes: Int64
    var networkRxBytes: Int64
    var networkTxBytes: Int64
    var numProcesses: Int

    var memoryUsageDisplay: String {
        ByteCountFormatter.string(fromByteCount: memoryUsageBytes, countStyle: .memory)
    }

    var memoryLimitDisplay: String {
        ByteCountFormatter.string(fromByteCount: memoryLimitBytes, countStyle: .memory)
    }

    var networkDisplay: String {
        let rx = ByteCountFormatter.string(fromByteCount: networkRxBytes, countStyle: .file)
        let tx = ByteCountFormatter.string(fromByteCount: networkTxBytes, countStyle: .file)
        return "RX \(rx) / TX \(tx)"
    }

    var blockIODisplay: String {
        let read = ByteCountFormatter.string(fromByteCount: blockReadBytes, countStyle: .file)
        let write = ByteCountFormatter.string(fromByteCount: blockWriteBytes, countStyle: .file)
        return "R \(read) / W \(write)"
    }
}

struct SystemVersionEntry: Identifiable, Codable, Hashable, Sendable {
    var id: String { appName }
    var appName: String
    var buildType: String
    var commit: String
    var version: String
}

struct DiskUsageSummary: Codable, Hashable, Sendable {
    struct Resource: Codable, Hashable, Sendable {
        var active: Int
        var reclaimable: Int64
        var sizeInBytes: Int64
        var total: Int

        var sizeDisplay: String {
            ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
        }

        var reclaimableDisplay: String {
            ByteCountFormatter.string(fromByteCount: reclaimable, countStyle: .file)
        }

        var reclaimableRatio: Double {
            guard sizeInBytes > 0 else { return 0 }
            return min(max(Double(reclaimable) / Double(sizeInBytes), 0), 1)
        }
    }

    struct ResourceItem: Identifiable, Hashable, Sendable {
        var id: String { name }
        var name: String
        var value: Resource
    }

    var containers: Resource
    var images: Resource
    var volumes: Resource

    var totalSizeInBytes: Int64 {
        containers.sizeInBytes + images.sizeInBytes + volumes.sizeInBytes
    }

    var reclaimableSizeInBytes: Int64 {
        containers.reclaimable + images.reclaimable + volumes.reclaimable
    }

    var totalSizeDisplay: String {
        ByteCountFormatter.string(fromByteCount: totalSizeInBytes, countStyle: .file)
    }

    var reclaimableDisplay: String {
        ByteCountFormatter.string(fromByteCount: reclaimableSizeInBytes, countStyle: .file)
    }

    var resources: [ResourceItem] {
        [
            ResourceItem(name: "Containers", value: containers),
            ResourceItem(name: "Images", value: images),
            ResourceItem(name: "Volumes", value: volumes),
        ]
    }
}

struct SystemPropertyListResponse: Codable, Hashable, Sendable {
    struct Item: Codable, Hashable, Sendable {
        var key: String
        var value: JSONValue
    }

    var rawItems: [String: JSONValue]
}

struct ComposeProjectRecord: Codable, Hashable, Identifiable, Sendable {
    var id: String { path }
    var path: String
    var name: String
    var services: Int
    var lastOpened: Date
}

struct ComposeProject: Identifiable, Hashable, Sendable {
    struct Service: Identifiable, Hashable, Sendable {
        var id: String { name }
        var name: String
        var image: String?
        var buildContext: String?
        var command: [String] = []
        var ports: [String] = []
        var volumes: [String] = []
        var dependsOn: [String] = []
        var environment: [String: String] = [:]
        var networks: [String] = []
        var platform: String?
    }

    var id: String { path.path }
    var path: URL
    var name: String
    var services: [Service]
    var volumes: [String]
    var networks: [String]
    var lastModified: Date
}
