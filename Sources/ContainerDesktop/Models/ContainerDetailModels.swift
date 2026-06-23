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

enum ContainerBrowserPortTargetSource: String, Codable, Hashable, Sendable {
    case host
    case container
}

struct ContainerBrowserPortTarget: Identifiable, Hashable, Sendable {
    var id: String {
        [
            action.rawValue,
            url?.absoluteString ?? copyValue ?? "",
            "\(containerPort)",
        ].joined(separator: "|")
    }

    var title: String
    var url: URL?
    var copyValue: String?
    var action: ContainerPortQuickActionKind
    var source: ContainerBrowserPortTargetSource
    var scheme: String
    var protocolName: String
    var host: String
    var port: Int
    var hostPort: Int?
    var containerPort: Int
    var systemImage: String

    var endpointText: String {
        let displayHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        return "\(displayHost):\(port)"
    }

    static func targets(from inspectText: String, container: ContainerSummary) -> [ContainerBrowserPortTarget] {
        guard let data = inspectText.data(using: .utf8),
              let value = try? JSONDecoder.containerDesktop.decode(JSONValue.self, from: data) else {
            return []
        }
        return targets(from: value, container: container)
    }

    static func targets(from inspectValue: JSONValue, container: ContainerSummary) -> [ContainerBrowserPortTarget] {
        let mappings = ContainerPublishedPortMapping.mappings(from: inspectValue)
        let containerHost = IPAddressCopy.normalized(container.primaryIP)
        var targets: [ContainerBrowserPortTarget] = []

        for mapping in mappings where mapping.protocolName == "tcp" {
            if let hostPort = mapping.hostPort {
                let endpoint = ContainerPortEndpoint(
                    host: normalizedHostBindAddress(mapping.hostIP),
                    port: hostPort,
                    source: .host,
                    hostPort: hostPort,
                    containerPort: mapping.containerPort,
                    protocolName: mapping.protocolName
                )
                targets.append(contentsOf: ContainerPortQuickActionCatalog.targets(
                    imageName: container.imageName,
                    containerPort: mapping.containerPort,
                    protocolName: mapping.protocolName,
                    endpoint: endpoint
                ))
            }

            if let containerHost {
                let endpoint = ContainerPortEndpoint(
                    host: containerHost,
                    port: mapping.containerPort,
                    source: .container,
                    hostPort: mapping.hostPort,
                    containerPort: mapping.containerPort,
                    protocolName: mapping.protocolName
                )
                targets.append(contentsOf: ContainerPortQuickActionCatalog.targets(
                    imageName: container.imageName,
                    containerPort: mapping.containerPort,
                    protocolName: mapping.protocolName,
                    endpoint: endpoint
                ))
            }
        }

        var seenIDs: Set<String> = []
        return targets.filter { target in
            seenIDs.insert(target.id).inserted
        }
    }

    static func portSummary(from inspectText: String) -> String {
        guard let data = inspectText.data(using: .utf8),
              let value = try? JSONDecoder.containerDesktop.decode(JSONValue.self, from: data) else {
            return "No ports"
        }
        let values = ContainerPublishedPortMapping.mappings(from: value)
            .map(\.displayText)
        return values.isEmpty ? "No ports" : values.prefix(3).joined(separator: ", ")
    }

    private static func normalizedHostBindAddress(_ host: String?) -> String {
        guard let host = IPAddressCopy.normalized(host) else { return "127.0.0.1" }
        if host == "0.0.0.0" || host == "::" || host == "[::]" {
            return "127.0.0.1"
        }
        return host
    }
}

private struct ContainerPublishedPortMapping: Hashable, Sendable {
    var protocolName: String
    var hostIP: String?
    var hostPort: Int?
    var containerPort: Int

    var displayText: String {
        if let hostPort {
            return "\(hostPort):\(containerPort)/\(protocolName)"
        }
        return "\(containerPort)/\(protocolName)"
    }

    static func mappings(from value: JSONValue) -> [ContainerPublishedPortMapping] {
        guard let object = rootObject(from: value) else {
            return []
        }

        var mappings: [ContainerPublishedPortMapping] = []
        mappings.append(contentsOf: publishedPortMappings(from: object))
        mappings.append(contentsOf: dockerNetworkPortMappings(from: object))
        mappings.append(contentsOf: exposedPortMappings(from: object))

        let boundContainerPorts = Set(
            mappings.compactMap { mapping -> String? in
                guard mapping.hostPort != nil else { return nil }
                return "\(mapping.protocolName)|\(mapping.containerPort)"
            }
        )

        var seen: Set<String> = []
        return mappings.filter { mapping in
            if mapping.hostPort == nil {
                let key = "\(mapping.protocolName)|\(mapping.containerPort)"
                if boundContainerPorts.contains(key) {
                    return false
                }
            }
            let key = [
                mapping.protocolName,
                mapping.hostIP ?? "",
                mapping.hostPort.map(String.init) ?? "",
                "\(mapping.containerPort)",
            ].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }

    private static func publishedPortMappings(from object: [String: JSONValue]) -> [ContainerPublishedPortMapping] {
        guard let configuration = object.value(forAny: ["configuration", "Configuration"]),
              case .object(let config) = configuration,
              let publishedPorts = config.value(forAny: ["publishedPorts", "published_ports", "PublishedPorts"]),
              case .array(let ports) = publishedPorts else {
            return []
        }

        return ports.compactMap { port in
            guard case .object(let item) = port else { return nil }
            let proto = item.scalarText(forAny: ["protocol", "proto"])?.lowercased() ?? "tcp"
            guard let containerPort = item.portValue(forAny: ["containerPort", "container_port", "targetPort", "target", "port"]) else {
                return nil
            }

            let hostValue = item.scalarText(forAny: ["host"])
            let hostPort = item.portValue(forAny: ["hostPort", "host_port", "publishedPort", "published"])
                ?? numericHostPort(from: hostValue)
            let hostIP = item.scalarText(forAny: ["hostIP", "hostIp", "host_ip", "hostAddress", "host_address", "address", "ip"])
                ?? nonNumericHost(from: hostValue)

            return ContainerPublishedPortMapping(
                protocolName: proto,
                hostIP: hostIP,
                hostPort: hostPort,
                containerPort: containerPort
            )
        }
    }

    private static func dockerNetworkPortMappings(from object: [String: JSONValue]) -> [ContainerPublishedPortMapping] {
        guard let networkSettings = object.object(forAny: ["NetworkSettings", "networkSettings", "network_settings"]),
              let ports = networkSettings.object(forAny: ["Ports", "ports"]) else {
            return []
        }

        var mappings: [ContainerPublishedPortMapping] = []
        for portKey in ports.keys.sorted(by: portSortKey(_:_:)) {
            guard let bindings = ports[portKey], let (containerPort, proto) = parsePortKey(portKey) else { continue }
            switch bindings {
            case .array(let values) where !values.isEmpty:
                for value in values {
                    guard case .object(let binding) = value else { continue }
                    mappings.append(ContainerPublishedPortMapping(
                        protocolName: proto,
                        hostIP: binding.scalarText(forAny: ["HostIp", "HostIP", "hostIP", "hostIp", "host_ip", "IP"]),
                        hostPort: binding.portValue(forAny: ["HostPort", "hostPort", "host_port", "publishedPort", "published"]),
                        containerPort: containerPort
                    ))
                }
            case .array, .null:
                mappings.append(ContainerPublishedPortMapping(
                    protocolName: proto,
                    hostIP: nil,
                    hostPort: nil,
                    containerPort: containerPort
                ))
            default:
                continue
            }
        }
        return mappings
    }

    private static func exposedPortMappings(from object: [String: JSONValue]) -> [ContainerPublishedPortMapping] {
        var mappings: [ContainerPublishedPortMapping] = []

        if let configuration = object.object(forAny: ["configuration", "Configuration"]),
           let exposedPorts = configuration.value(forAny: ["exposedPorts", "exposed_ports", "ExposedPorts"]) {
            mappings.append(contentsOf: exposedPortMappings(from: exposedPorts))
        }

        if let config = object.object(forAny: ["Config", "config"]),
           let exposedPorts = config.value(forAny: ["ExposedPorts", "exposedPorts", "exposed_ports"]) {
            mappings.append(contentsOf: exposedPortMappings(from: exposedPorts))
        }

        return mappings
    }

    private static func exposedPortMappings(from value: JSONValue) -> [ContainerPublishedPortMapping] {
        switch value {
        case .object(let ports):
            return ports.keys.sorted(by: portSortKey(_:_:)).compactMap(exposedPortMapping(from:))
        case .array(let ports):
            return ports.compactMap { value in
                switch value {
                case .string(let port):
                    return exposedPortMapping(from: port)
                case .object(let item):
                    let proto = item.scalarText(forAny: ["protocol", "proto"])?.lowercased() ?? "tcp"
                    guard let containerPort = item.portValue(forAny: ["containerPort", "container_port", "targetPort", "target", "port"]) else {
                        return nil
                    }
                    return ContainerPublishedPortMapping(
                        protocolName: proto,
                        hostIP: nil,
                        hostPort: nil,
                        containerPort: containerPort
                    )
                default:
                    return nil
                }
            }
        default:
            return []
        }
    }

    private static func exposedPortMapping(from text: String) -> ContainerPublishedPortMapping? {
        guard let (containerPort, proto) = parsePortKey(text) else { return nil }
        return ContainerPublishedPortMapping(
            protocolName: proto,
            hostIP: nil,
            hostPort: nil,
            containerPort: containerPort
        )
    }

    private static func parsePortKey(_ value: String) -> (Int, String)? {
        let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
        guard let portText = parts.first,
              let port = Int(portText),
              (1...65_535).contains(port) else {
            return nil
        }
        let proto = parts.count > 1 ? parts[1].lowercased() : "tcp"
        return (port, proto)
    }

    private static func portSortKey(_ lhs: String, _ rhs: String) -> Bool {
        let lhsPort = parsePortKey(lhs)?.0 ?? .max
        let rhsPort = parsePortKey(rhs)?.0 ?? .max
        if lhsPort != rhsPort { return lhsPort < rhsPort }
        return lhs < rhs
    }

    private static func rootObject(from value: JSONValue) -> [String: JSONValue]? {
        switch value {
        case .array(let values):
            if case .object(let first)? = values.first { return first }
            return nil
        case .object(let object):
            return object
        default:
            return nil
        }
    }

    private static func numericHostPort(from value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value).flatMap { (1...65_535).contains($0) ? $0 : nil }
    }

    private static func nonNumericHost(from value: String?) -> String? {
        guard let value, numericHostPort(from: value) == nil else { return nil }
        return value
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func value(forAny keys: [String]) -> JSONValue? {
        for key in keys {
            if let value = self[key] { return value }
        }
        return nil
    }

    func object(forAny keys: [String]) -> [String: JSONValue]? {
        guard let value = value(forAny: keys),
              case .object(let object) = value else {
            return nil
        }
        return object
    }

    func scalarText(forAny keys: [String]) -> String? {
        value(forAny: keys)?.scalarText?.nilIfBlank
    }

    func portValue(forAny keys: [String]) -> Int? {
        guard let text = scalarText(forAny: keys),
              let value = Int(text),
              (1...65_535).contains(value) else {
            return nil
        }
        return value
    }
}

private extension JSONValue {
    var scalarText: String? {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            value.rounded() == value ? String(Int64(value)) : String(value)
        case .bool(let value):
            String(value)
        default:
            nil
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
