import Foundation

enum ObservabilityLogSource: String, CaseIterable, Identifiable, Hashable, Sendable {
    case containerStdio
    case containerBoot
    case system

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let isChinese = language.resolved == .zhHans
        switch self {
        case .containerStdio:
            return isChinese ? "容器日志" : "Container logs"
        case .containerBoot:
            return isChinese ? "Boot 日志" : "Boot logs"
        case .system:
            return isChinese ? "系统日志" : "System logs"
        }
    }
}

enum ObservabilityInputNormalizer {
    static func logLines(_ text: String) -> Int {
        max(min(Int(text.trimmed) ?? 120, 1000), 20)
    }

    static func systemLogLast(_ text: String) -> String {
        let value = text.trimmed.lowercased()
        guard !value.isEmpty else { return "5m" }

        let suffix = value.last.map(String.init) ?? ""
        let hasUnit = ["m", "h", "d"].contains(suffix)
        let numberText = hasUnit ? String(value.dropLast()) : value
        guard let number = Int(numberText), number > 0 else { return "5m" }
        return hasUnit ? "\(number)\(suffix)" : "\(number)"
    }
}

enum ObservabilityStatsSort: String, CaseIterable, Identifiable, Hashable, Sendable {
    case memory
    case network
    case blockIO
    case processes
    case cpu
    case containerID

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let isChinese = language.resolved == .zhHans
        switch self {
        case .memory:
            return isChinese ? "内存" : "Memory"
        case .network:
            return isChinese ? "网络" : "Network"
        case .blockIO:
            return "Block I/O"
        case .processes:
            return "PIDs"
        case .cpu:
            return "CPU usec"
        case .containerID:
            return isChinese ? "容器 ID" : "Container ID"
        }
    }
}

struct ObservabilityStatsSummary: Hashable, Sendable {
    var containerCount: Int
    var totalMemoryUsageBytes: Int64
    var totalMemoryLimitBytes: Int64
    var totalNetworkRxBytes: Int64
    var totalNetworkTxBytes: Int64
    var totalBlockReadBytes: Int64
    var totalBlockWriteBytes: Int64
    var totalProcesses: Int

    init(snapshots: [ContainerStatsSnapshot]) {
        containerCount = snapshots.count
        totalMemoryUsageBytes = snapshots.reduce(0) { $0 + $1.memoryUsageBytes }
        totalMemoryLimitBytes = snapshots.reduce(0) { $0 + $1.memoryLimitBytes }
        totalNetworkRxBytes = snapshots.reduce(0) { $0 + $1.networkRxBytes }
        totalNetworkTxBytes = snapshots.reduce(0) { $0 + $1.networkTxBytes }
        totalBlockReadBytes = snapshots.reduce(0) { $0 + $1.blockReadBytes }
        totalBlockWriteBytes = snapshots.reduce(0) { $0 + $1.blockWriteBytes }
        totalProcesses = snapshots.reduce(0) { $0 + $1.numProcesses }
    }

    var memoryDisplay: String {
        let used = ByteCountFormatter.string(fromByteCount: totalMemoryUsageBytes, countStyle: .memory)
        let limit = ByteCountFormatter.string(fromByteCount: totalMemoryLimitBytes, countStyle: .memory)
        return "\(used) / \(limit)"
    }

    var networkDisplay: String {
        let rx = ByteCountFormatter.string(fromByteCount: totalNetworkRxBytes, countStyle: .file)
        let tx = ByteCountFormatter.string(fromByteCount: totalNetworkTxBytes, countStyle: .file)
        return "RX \(rx) / TX \(tx)"
    }

    var blockIODisplay: String {
        let read = ByteCountFormatter.string(fromByteCount: totalBlockReadBytes, countStyle: .file)
        let write = ByteCountFormatter.string(fromByteCount: totalBlockWriteBytes, countStyle: .file)
        return "R \(read) / W \(write)"
    }
}

enum ObservabilityComposeScope: Hashable, Identifiable, Sendable {
    case all
    case project(String)
    case service(projectID: String, serviceName: String)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .project(let projectID):
            return "project:\(projectID)"
        case .service(let projectID, let serviceName):
            return "service:\(projectID):\(serviceName)"
        }
    }

    func containers(from containers: [ContainerSummary], projects: [ComposeProject]) -> [ContainerSummary] {
        switch self {
        case .all:
            return containers
        case .project(let projectID):
            guard let project = projects.first(where: { $0.id == projectID }) else { return [] }
            let matchedIDs = Set(
                project
                    .runtimeSummaries(containers: containers)
                    .flatMap { $0.containers.map(\.id) }
            )
            return containers.filter { matchedIDs.contains($0.id) }
        case .service(let projectID, let serviceName):
            guard let project = projects.first(where: { $0.id == projectID }),
                  let summary = project.runtimeSummaries(containers: containers).first(where: { $0.service.name == serviceName }) else {
                return []
            }
            let matchedIDs = Set(summary.containers.map(\.id))
            return containers.filter { matchedIDs.contains($0.id) }
        }
    }
}

enum GlobalLogStreamFormatter {
    static func prefixSystem(chunk: String) -> String {
        let prefix = AppBranding.logPrefix
        return chunk
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                guard !line.isEmpty else { return prefix }
                return "\(prefix) \(line)"
            }
            .joined(separator: "\n")
    }

    static func prefix(chunk: String, containerID: String, imageName: String) -> String {
        let cleanID = containerID.nilIfBlank ?? "unknown"
        let shortID = String(cleanID.prefix(18))
        let image = imageName.nilIfBlank ?? "unknown"
        let prefix = "[\(shortID)] \(image)"
        return chunk
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                guard !line.isEmpty else { return prefix }
                return "\(prefix) \(line)"
            }
            .joined(separator: "\n")
    }

    static func limited(_ text: String, maxCharacters: Int) -> String {
        guard maxCharacters > 0, text.count > maxCharacters else { return text }
        return String(text.suffix(maxCharacters))
    }

    static func filtered(_ text: String, containerIDs: Set<String>) -> String {
        guard !containerIDs.isEmpty else { return "" }
        let fullPrefixes = containerIDs.map { "[\($0)]" }
        let shortPrefixes = containerIDs.map { "[\(String($0.prefix(18)))]" }
        let allPrefixes = fullPrefixes + shortPrefixes

        let sections = text.components(separatedBy: "\n\n")
        if sections.count > 1 {
            let matchingSections = sections.filter { section in
                guard let firstLine = section.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first else {
                    return false
                }
                return allPrefixes.contains { firstLine.hasPrefix($0) }
            }
            if !matchingSections.isEmpty {
                return matchingSections.joined(separator: "\n\n")
            }
        }

        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                line.hasPrefix(AppBranding.logPrefix) || line.hasPrefix(AppBranding.legacyLogPrefix) || allPrefixes.contains { line.hasPrefix($0) }
            }
            .joined(separator: "\n")
    }
}

extension Array where Element == ContainerStatsSnapshot {
    func sortedForObservability(by sort: ObservabilityStatsSort) -> [ContainerStatsSnapshot] {
        sorted { lhs, rhs in
            switch sort {
            case .memory:
                return descending(lhs.memoryUsageBytes, rhs.memoryUsageBytes, lhsID: lhs.id, rhsID: rhs.id)
            case .network:
                return descending(
                    lhs.networkRxBytes + lhs.networkTxBytes,
                    rhs.networkRxBytes + rhs.networkTxBytes,
                    lhsID: lhs.id,
                    rhsID: rhs.id
                )
            case .blockIO:
                return descending(
                    lhs.blockReadBytes + lhs.blockWriteBytes,
                    rhs.blockReadBytes + rhs.blockWriteBytes,
                    lhsID: lhs.id,
                    rhsID: rhs.id
                )
            case .processes:
                return descending(lhs.numProcesses, rhs.numProcesses, lhsID: lhs.id, rhsID: rhs.id)
            case .cpu:
                return descending(lhs.cpuUsageUsec, rhs.cpuUsageUsec, lhsID: lhs.id, rhsID: rhs.id)
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
