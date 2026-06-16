import Foundation

struct ContainerResourceSample: Identifiable, Hashable, Sendable {
    var id: String { snapshot.id }
    var date: Date
    var snapshot: ContainerStatsSnapshot
    var cpuPercent: Double
    var networkRxBytesPerSecond: Double
    var networkTxBytesPerSecond: Double
    var blockReadBytesPerSecond: Double
    var blockWriteBytesPerSecond: Double

    var memoryUsageBytes: Int64 { snapshot.memoryUsageBytes }
    var memoryLimitBytes: Int64 { snapshot.memoryLimitBytes }
    var numProcesses: Int { snapshot.numProcesses }

    var memoryUsageDisplay: String {
        ByteCountFormatter.string(fromByteCount: memoryUsageBytes, countStyle: .memory)
    }

    var memoryLimitDisplay: String {
        ByteCountFormatter.string(fromByteCount: memoryLimitBytes, countStyle: .memory)
    }

    var networkRateDisplay: String {
        "RX \(Self.bytesPerSecond(networkRxBytesPerSecond)) / TX \(Self.bytesPerSecond(networkTxBytesPerSecond))"
    }

    var blockIORateDisplay: String {
        "R \(Self.bytesPerSecond(blockReadBytesPerSecond)) / W \(Self.bytesPerSecond(blockWriteBytesPerSecond))"
    }

    static func make(
        snapshot: ContainerStatsSnapshot,
        date: Date = Date(),
        previous: ContainerResourceSample? = nil
    ) -> ContainerResourceSample {
        let elapsed = previous.map { max(date.timeIntervalSince($0.date), 0.001) } ?? 0

        func rate(_ current: Int64, _ previous: Int64) -> Double {
            guard elapsed > 0 else { return 0 }
            return Double(max(current - previous, 0)) / elapsed
        }

        let cpuPercent: Double
        if let previous {
            let deltaUsec = max(snapshot.cpuUsageUsec - previous.snapshot.cpuUsageUsec, 0)
            cpuPercent = min(max(Double(deltaUsec) / (elapsed * 1_000_000) * 100, 0), 1_000)
        } else {
            cpuPercent = 0
        }

        return ContainerResourceSample(
            date: date,
            snapshot: snapshot,
            cpuPercent: cpuPercent,
            networkRxBytesPerSecond: previous.map { rate(snapshot.networkRxBytes, $0.snapshot.networkRxBytes) } ?? 0,
            networkTxBytesPerSecond: previous.map { rate(snapshot.networkTxBytes, $0.snapshot.networkTxBytes) } ?? 0,
            blockReadBytesPerSecond: previous.map { rate(snapshot.blockReadBytes, $0.snapshot.blockReadBytes) } ?? 0,
            blockWriteBytesPerSecond: previous.map { rate(snapshot.blockWriteBytes, $0.snapshot.blockWriteBytes) } ?? 0
        )
    }

    static func bytesPerSecond(_ value: Double) -> String {
        "\(ByteCountFormatter.string(fromByteCount: Int64(max(value, 0)), countStyle: .file))/s"
    }
}

struct EnvironmentResourceSnapshot: Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var containerCount: Int
    var runningContainerCount: Int
    var cpuPercent: Double
    var memoryUsageBytes: Int64
    var memoryLimitBytes: Int64
    var networkRxBytesPerSecond: Double
    var networkTxBytesPerSecond: Double
    var blockReadBytesPerSecond: Double
    var blockWriteBytesPerSecond: Double
    var numProcesses: Int
    var hostProcessCPUPercent: Double
    var hostProcessMemoryBytes: Int64

    init(
        date: Date = Date(),
        containerSamples: [ContainerResourceSample],
        runningContainerCount: Int,
        hostProcesses: [HostProcessResourceSnapshot]
    ) {
        self.date = date
        self.containerCount = containerSamples.count
        self.runningContainerCount = runningContainerCount
        self.cpuPercent = containerSamples.reduce(0) { $0 + $1.cpuPercent }
        self.memoryUsageBytes = containerSamples.reduce(0) { $0 + $1.memoryUsageBytes }
        self.memoryLimitBytes = containerSamples.reduce(0) { $0 + $1.memoryLimitBytes }
        self.networkRxBytesPerSecond = containerSamples.reduce(0) { $0 + $1.networkRxBytesPerSecond }
        self.networkTxBytesPerSecond = containerSamples.reduce(0) { $0 + $1.networkTxBytesPerSecond }
        self.blockReadBytesPerSecond = containerSamples.reduce(0) { $0 + $1.blockReadBytesPerSecond }
        self.blockWriteBytesPerSecond = containerSamples.reduce(0) { $0 + $1.blockWriteBytesPerSecond }
        self.numProcesses = containerSamples.reduce(0) { $0 + $1.numProcesses }
        self.hostProcessCPUPercent = hostProcesses.reduce(0) { $0 + $1.cpuPercent }
        self.hostProcessMemoryBytes = hostProcesses.reduce(0) { $0 + $1.residentMemoryBytes }
    }

    var memoryDisplay: String {
        let used = ByteCountFormatter.string(fromByteCount: memoryUsageBytes, countStyle: .memory)
        let limit = ByteCountFormatter.string(fromByteCount: memoryLimitBytes, countStyle: .memory)
        return "\(used) / \(limit)"
    }

    var hostMemoryDisplay: String {
        ByteCountFormatter.string(fromByteCount: hostProcessMemoryBytes, countStyle: .memory)
    }

    var networkRateDisplay: String {
        "RX \(ContainerResourceSample.bytesPerSecond(networkRxBytesPerSecond)) / TX \(ContainerResourceSample.bytesPerSecond(networkTxBytesPerSecond))"
    }

    var blockIORateDisplay: String {
        "R \(ContainerResourceSample.bytesPerSecond(blockReadBytesPerSecond)) / W \(ContainerResourceSample.bytesPerSecond(blockWriteBytesPerSecond))"
    }
}

enum HostProcessResourceCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case containerService
    case containerRuntime
    case containerCompose
    case containerCLI

    var title: String {
        switch self {
        case .containerService:
            return "container service"
        case .containerRuntime:
            return "container runtime"
        case .containerCompose:
            return "container-compose"
        case .containerCLI:
            return "container CLI"
        }
    }
}

struct HostProcessResourceSnapshot: Identifiable, Hashable, Sendable {
    var id: Int { pid }
    var pid: Int
    var parentPID: Int
    var cpuPercent: Double
    var residentMemoryBytes: Int64
    var command: String
    var arguments: String
    var category: HostProcessResourceCategory

    var memoryDisplay: String {
        ByteCountFormatter.string(fromByteCount: residentMemoryBytes, countStyle: .memory)
    }

    var displayName: String {
        URL(fileURLWithPath: command).lastPathComponent.nilIfBlank ?? command
    }
}

struct ResourceMonitorSnapshot: Hashable, Sendable {
    var date: Date
    var containerSamples: [ContainerResourceSample]
    var hostProcesses: [HostProcessResourceSnapshot]
    var environment: EnvironmentResourceSnapshot
}

extension Array where Element == ContainerResourceSample {
    func sortedForObservability(by sort: ObservabilityStatsSort) -> [ContainerResourceSample] {
        sorted { lhs, rhs in
            switch sort {
            case .memory:
                return descending(lhs.memoryUsageBytes, rhs.memoryUsageBytes, lhsID: lhs.id, rhsID: rhs.id)
            case .network:
                return descending(
                    lhs.networkRxBytesPerSecond + lhs.networkTxBytesPerSecond,
                    rhs.networkRxBytesPerSecond + rhs.networkTxBytesPerSecond,
                    lhsID: lhs.id,
                    rhsID: rhs.id
                )
            case .blockIO:
                return descending(
                    lhs.blockReadBytesPerSecond + lhs.blockWriteBytesPerSecond,
                    rhs.blockReadBytesPerSecond + rhs.blockWriteBytesPerSecond,
                    lhsID: lhs.id,
                    rhsID: rhs.id
                )
            case .processes:
                return descending(lhs.numProcesses, rhs.numProcesses, lhsID: lhs.id, rhsID: rhs.id)
            case .cpu:
                return descending(lhs.cpuPercent, rhs.cpuPercent, lhsID: lhs.id, rhsID: rhs.id)
            case .containerID:
                return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
        }
    }

    private func descending<T: Comparable>(_ lhs: T, _ rhs: T, lhsID: String, rhsID: String) -> Bool {
        if lhs == rhs {
            return lhsID.localizedStandardCompare(rhsID) == .orderedAscending
        }
        return lhs > rhs
    }
}
