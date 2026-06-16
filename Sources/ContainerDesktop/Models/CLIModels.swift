import Foundation

struct EnvironmentProbe: Codable, Hashable, Sendable {
    var macOSVersion: String
    var architecture: String
    var containerAvailable: Bool
    var containerComposeAvailable: Bool
    var containerVersion: String?
    var containerComposeVersion: String?
    var systemRunning: Bool
    var systemVersion: String?
    var errorMessage: String?

    init(
        macOSVersion: String,
        architecture: String,
        containerAvailable: Bool,
        containerComposeAvailable: Bool,
        containerVersion: String? = nil,
        containerComposeVersion: String? = nil,
        systemRunning: Bool,
        systemVersion: String?,
        errorMessage: String?
    ) {
        self.macOSVersion = macOSVersion
        self.architecture = architecture
        self.containerAvailable = containerAvailable
        self.containerComposeAvailable = containerComposeAvailable
        self.containerVersion = containerVersion
        self.containerComposeVersion = containerComposeVersion
        self.systemRunning = systemRunning
        self.systemVersion = systemVersion
        self.errorMessage = errorMessage
    }
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
        var labels: [String: String]?
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
    var labels: [String: String] { configuration.labels ?? [:] }
    var primaryIP: String { status.networks.compactMap(\.ipv4Address).first ?? "—" }
    var startedText: String {
        guard let startedDate = status.startedDate else { return "—" }
        return startedDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct MachineSummary: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var status: String
    var isDefault: Bool
    var ipAddress: String?
    var cpus: Int
    var memory: UInt64
    var diskSize: UInt64?
    var createdDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case isDefault = "default"
        case ipAddress
        case cpus
        case memory
        case diskSize
        case createdDate
    }

    var isRunning: Bool { status == "running" }
    var statusText: String { status }
    var ipAddressText: String { ipAddress ?? "—" }
    var memoryDisplay: String {
        ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
    }
    var diskSizeDisplay: String {
        guard let diskSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(diskSize), countStyle: .file)
    }
    var createdText: String {
        guard let createdDate else { return "—" }
        return createdDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct MachineInspection: Codable, Hashable, Sendable {
    struct Image: Codable, Hashable, Sendable {
        var reference: String?
        var descriptor: JSONValue?

        var referenceText: String { reference ?? "—" }
    }

    struct Platform: Codable, Hashable, Sendable {
        var os: String?
        var architecture: String?
        var variant: String?

        var displayName: String {
            [os, architecture, variant]
                .compactMap { $0?.nilIfBlank }
                .joined(separator: "/")
        }
    }

    struct UserSetup: Codable, Hashable, Sendable {
        var username: String
        var uid: UInt32
        var gid: UInt32

        var home: String { "/home/\(username)" }
    }

    var id: String
    var image: Image
    var platform: Platform
    var userSetup: UserSetup
    var status: String
    var startedDate: Date?
    var createdDate: Date?
    var containerId: String?
    var cpus: Int
    var memory: UInt64
    var homeMount: String
    var diskSize: UInt64?
    var ipAddress: String?

    var platformText: String {
        let value = platform.displayName
        return value.isEmpty ? "—" : value
    }

    var startedText: String {
        guard let startedDate else { return "—" }
        return startedDate.formatted(date: .abbreviated, time: .shortened)
    }

    var createdText: String {
        guard let createdDate else { return "—" }
        return createdDate.formatted(date: .abbreviated, time: .shortened)
    }

    var memoryDisplay: String {
        ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory)
    }

    var diskSizeDisplay: String {
        guard let diskSize else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(diskSize), countStyle: .file)
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
            var variant: String?

            var displayName: String {
                [os, architecture, variant]
                    .compactMap { $0?.nilIfBlank }
                    .joined(separator: "/")
            }
        }

        struct Config: Codable, Hashable, Sendable {
            struct History: Codable, Hashable, Sendable {
                var created: Date?
                var createdBy: String?
                var comment: String?
                var emptyLayer: Bool?

                enum CodingKeys: String, CodingKey {
                    case created
                    case createdBy = "created_by"
                    case comment
                    case emptyLayer = "empty_layer"
                }

                var instruction: String {
                    createdBy?.nilIfBlank ?? "—"
                }

                var createdText: String {
                    guard let created else { return "—" }
                    return created.formatted(date: .abbreviated, time: .shortened)
                }
            }

            struct RootFS: Codable, Hashable, Sendable {
                var diffIDs: [String]
                var type: String?

                enum CodingKeys: String, CodingKey {
                    case diffIDs = "diff_ids"
                    case type
                }
            }

            var architecture: String?
            var os: String?
            var variant: String?
            var created: Date?
            var history: [History]?
            var rootfs: RootFS?
        }

        var platform: Platform
        var digest: String
        var size: Int64
        var config: Config?

        var platformText: String {
            let value = platform.displayName
            return value.isEmpty ? "—" : value
        }

        var sizeDisplay: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }

        var layers: [ImageLayerEntry] {
            ImageLayerEntry.make(from: self)
        }
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

struct ImageLayerEntry: Identifiable, Hashable, Sendable {
    var index: Int
    var instruction: String
    var diffID: String?
    var createdAt: Date?
    var comment: String?
    var isEmptyLayer: Bool

    var id: Int { index }

    var digestText: String {
        diffID ?? "—"
    }

    var displayInstruction: String {
        var value = instruction.trimmed
        if value.hasPrefix("/bin/sh -c #(nop)") {
            value = String(value.dropFirst("/bin/sh -c #(nop)".count)).trimmed
        } else if value.hasPrefix("/bin/sh -c") {
            value = String(value.dropFirst("/bin/sh -c".count)).trimmed
        }
        if value.hasSuffix("# buildkit") {
            value = String(value.dropLast("# buildkit".count)).trimmed
        }
        return value.isEmpty ? "—" : value
    }

    var createdText: String {
        guard let createdAt else { return "—" }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var layerTypeText: String {
        isEmptyLayer ? "metadata" : "filesystem"
    }

    var sizeDisplay: String {
        "—"
    }

    static func make(from variant: ImageSummary.Variant) -> [ImageLayerEntry] {
        let history = variant.config?.history ?? []
        var diffIDs = variant.config?.rootfs?.diffIDs ?? []
        return history.enumerated().map { offset, item in
            let isEmptyLayer = item.emptyLayer == true
            let diffID = isEmptyLayer ? nil : (diffIDs.isEmpty ? nil : diffIDs.removeFirst())
            return ImageLayerEntry(
                index: offset,
                instruction: item.instruction,
                diffID: diffID,
                createdAt: item.created,
                comment: item.comment,
                isEmptyLayer: isEmptyLayer
            )
        }
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
    var username: String?
    var creationDate: Date?
    var modificationDate: Date?
    var labels: [String: String]

    enum CodingKeys: String, CodingKey {
        case server
        case name
        case id
        case username
        case creationDate
        case modificationDate
        case labels
    }

    init(
        server: String,
        username: String? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        labels: [String: String] = [:]
    ) {
        self.server = server
        self.username = username
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.labels = labels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resolvedServer = try container.decodeIfPresent(String.self, forKey: .server)
            ?? container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .id)

        guard let resolvedServer = resolvedServer?.nilIfBlank else {
            throw DecodingError.dataCorruptedError(
                forKey: .server,
                in: container,
                debugDescription: "Registry entry is missing server, name, or id."
            )
        }

        server = resolvedServer
        username = try container.decodeIfPresent(String.self, forKey: .username)?.nilIfBlank
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        modificationDate = try container.decodeIfPresent(Date.self, forKey: .modificationDate)
        labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(server, forKey: .server)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(creationDate, forKey: .creationDate)
        try container.encodeIfPresent(modificationDate, forKey: .modificationDate)
        try container.encode(labels, forKey: .labels)
    }

    var displayName: String {
        isDockerHub ? "Docker Hub" : server
    }

    var detailServer: String? {
        displayName == server ? nil : server
    }

    var usernameText: String {
        username ?? "—"
    }

    var createdText: String {
        guard let creationDate else { return "—" }
        return creationDate.formatted(date: .abbreviated, time: .shortened)
    }

    var isDockerHub: Bool {
        let normalized = server
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized == "docker.io"
            || normalized == "registry-1.docker.io"
            || normalized == "index.docker.io"
            || normalized == "index.docker.io/v1"
    }
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
