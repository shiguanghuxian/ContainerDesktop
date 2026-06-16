import Foundation

enum ContainerDetailTab: String, CaseIterable, Identifiable, Hashable {
    case logs
    case inspect
    case exec
    case files
    case stats

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .logs:
            return language.t(.logs)
        case .inspect:
            return "Inspect"
        case .exec:
            return "Exec"
        case .files:
            return "Files"
        case .stats:
            return "Stats"
        }
    }

    var systemImage: String {
        switch self {
        case .logs: "doc.plaintext"
        case .inspect: "curlybraces"
        case .exec: "terminal"
        case .files: "folder"
        case .stats: "chart.xyaxis.line"
        }
    }
}

enum ContainerFileKind: String, Codable, Hashable, Sendable {
    case directory
    case regularFile
    case symlink
    case other

    init(statDescription: String) {
        let lowercased = statDescription.lowercased()
        if lowercased.contains("directory") {
            self = .directory
        } else if lowercased.contains("symbolic link") {
            self = .symlink
        } else if lowercased.contains("regular file") || lowercased == "file" {
            self = .regularFile
        } else {
            self = .other
        }
    }

    var isPreviewableFile: Bool { self == .regularFile || self == .symlink }

    var systemImage: String {
        switch self {
        case .directory: "folder"
        case .regularFile: "doc.text"
        case .symlink: "arrowshape.turn.up.right"
        case .other: "questionmark.square"
        }
    }
}

enum ContainerFileSort: String, CaseIterable, Identifiable, Hashable {
    case name
    case size
    case modified
    case mode

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .name: language.t(.name)
        case .size: language.t(.size)
        case .modified: language.t(.modified)
        case .mode: language.t(.mode)
        }
    }
}

struct ContainerFileEntry: Identifiable, Hashable, Sendable {
    var id: String { path }
    var name: String
    var path: String
    var kind: ContainerFileKind
    var mode: String
    var owner: String
    var group: String
    var size: Int64
    var modifiedAt: Date?
    var linkTarget: String?

    var isDirectory: Bool { kind == .directory }
    var displayName: String {
        if let linkTarget, !linkTarget.isEmpty {
            return "\(name) -> \(linkTarget)"
        }
        return name
    }

    var sizeDisplay: String {
        guard !isDirectory else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var modifiedText: String {
        guard let modifiedAt else { return "—" }
        return modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }

    static func parseListingLine(_ line: String) -> ContainerFileEntry? {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 8 else { return nil }

        let name = parts[0]
        let path = parts[1]
        guard !name.isEmpty, !path.isEmpty else { return nil }

        let size = Int64(parts[6]) ?? 0
        let modifiedAt: Date?
        if let timestamp = TimeInterval(parts[7]) {
            modifiedAt = Date(timeIntervalSince1970: timestamp)
        } else {
            modifiedAt = nil
        }

        let linkTarget = parts.count > 8 ? parts[8].nilIfBlank : nil
        return ContainerFileEntry(
            name: name,
            path: path,
            kind: ContainerFileKind(statDescription: parts[2]),
            mode: parts[3],
            owner: parts[4],
            group: parts[5],
            size: size,
            modifiedAt: modifiedAt,
            linkTarget: linkTarget
        )
    }
}

struct ContainerStatsSample: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var snapshot: ContainerStatsSnapshot
    var cpuPercent: Double

    var memoryUsageBytes: Double { Double(snapshot.memoryUsageBytes) }
    var memoryLimitBytes: Double { Double(snapshot.memoryLimitBytes) }
    var blockReadBytes: Double { Double(snapshot.blockReadBytes) }
    var blockWriteBytes: Double { Double(snapshot.blockWriteBytes) }
    var networkRxBytes: Double { Double(snapshot.networkRxBytes) }
    var networkTxBytes: Double { Double(snapshot.networkTxBytes) }

    static func make(
        snapshot: ContainerStatsSnapshot,
        date: Date = Date(),
        previous: ContainerStatsSample? = nil
    ) -> ContainerStatsSample {
        let cpuPercent: Double
        if let previous {
            let elapsed = max(date.timeIntervalSince(previous.date), 0.001)
            let deltaUsec = max(snapshot.cpuUsageUsec - previous.snapshot.cpuUsageUsec, 0)
            cpuPercent = min(max(Double(deltaUsec) / (elapsed * 1_000_000) * 100, 0), 1_000)
        } else {
            cpuPercent = 0
        }

        return ContainerStatsSample(
            date: date,
            snapshot: snapshot,
            cpuPercent: cpuPercent
        )
    }
}

extension Array where Element == ContainerStatsSample {
    func nearest(to date: Date) -> ContainerStatsSample? {
        guard !isEmpty else { return nil }
        guard count > 1 else { return first }

        var lowerBound = 0
        var upperBound = count - 1

        while lowerBound < upperBound {
            let midpoint = (lowerBound + upperBound) / 2
            if self[midpoint].date < date {
                lowerBound = midpoint + 1
            } else {
                upperBound = midpoint
            }
        }

        let candidate = self[lowerBound]
        guard lowerBound > 0 else { return candidate }

        let previous = self[lowerBound - 1]
        let candidateDistance = abs(candidate.date.timeIntervalSince(date))
        let previousDistance = abs(previous.date.timeIntervalSince(date))
        return previousDistance <= candidateDistance ? previous : candidate
    }

    func downsampled(maxCount: Int) -> [ContainerStatsSample] {
        guard maxCount > 1, count > maxCount else { return self }

        let step = Double(count - 1) / Double(maxCount - 1)
        var result: [ContainerStatsSample] = []
        result.reserveCapacity(maxCount)

        var lastIndex = -1
        for position in 0..<maxCount {
            let index = Swift.min(Int((Double(position) * step).rounded()), count - 1)
            guard index != lastIndex else { continue }
            result.append(self[index])
            lastIndex = index
        }

        if result.last?.id != last?.id, let last {
            if result.count == maxCount {
                result[result.count - 1] = last
            } else {
                result.append(last)
            }
        }

        return result
    }
}

extension Array where Element == ContainerFileEntry {
    func sorted(by sort: ContainerFileSort) -> [ContainerFileEntry] {
        sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            switch sort {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .size:
                if lhs.size == rhs.size {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.size > rhs.size
            case .modified:
                return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
            case .mode:
                if lhs.mode == rhs.mode {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.mode < rhs.mode
            }
        }
    }
}
