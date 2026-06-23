import Foundation

enum ComposeServiceRuntimeState: String, Hashable, Sendable {
    case running
    case stopped
    case mixed
    case missing

    var displayText: String {
        switch self {
        case .running: "running"
        case .stopped: "stopped"
        case .mixed: "mixed"
        case .missing: "not created"
        }
    }
}

struct ComposeServiceRuntimeSummary: Identifiable, Hashable, Sendable {
    var id: String { service.name }
    var service: ComposeProject.Service
    var containers: [ContainerSummary]

    var runningCount: Int {
        containers.filter { $0.state == "running" }.count
    }

    var runningContainers: [ContainerSummary] {
        containers.filter { $0.state == "running" }
    }

    var primaryRunningContainer: ContainerSummary? {
        runningContainers.first
    }

    var state: ComposeServiceRuntimeState {
        guard !containers.isEmpty else { return .missing }
        if runningCount == containers.count { return .running }
        if runningCount == 0 { return .stopped }
        return .mixed
    }

    var containerIDsText: String {
        containers.isEmpty ? "—" : containers.map(\.id).joined(separator: ", ")
    }
}

enum ComposeServiceContainerAction: String, CaseIterable, Hashable, Sendable {
    case start
    case stop
    case restart

    func title(language: AppLanguage) -> String {
        switch self {
        case .start:
            language.resolved == .zhHans ? "启动服务容器" : "Start service containers"
        case .stop:
            language.resolved == .zhHans ? "停止服务容器" : "Stop service containers"
        case .restart:
            language.resolved == .zhHans ? "重启服务容器" : "Restart service containers"
        }
    }

    func commandPreview(containerIDs: [String]) -> String {
        let ids = containerIDs.map(\.trimmed).filter { !$0.isEmpty }
        guard !ids.isEmpty else {
            return "container \(rawValue)"
        }

        let commands: [[String]]
        switch self {
        case .start:
            commands = ids.map { ["start", $0] }
        case .stop:
            commands = ids.map { ["stop", $0] }
        case .restart:
            commands = ids.flatMap { [["stop", $0], ["start", $0]] }
        }

        return commands
            .map { AppOperationCommandPreview.make(executable: "container", arguments: $0) }
            .joined(separator: " && ")
    }
}

extension ComposeProject {
    func runtimeSummaries(containers: [ContainerSummary]) -> [ComposeServiceRuntimeSummary] {
        let imageCounts = Dictionary(grouping: services.compactMap { $0.image?.nilIfBlank }, by: { $0 })
            .mapValues(\.count)

        return services.map { service in
            ComposeServiceRuntimeSummary(
                service: service,
                containers: containers.filter {
                    matches(container: $0, service: service, imageCounts: imageCounts)
                }
            )
        }
    }

    private func matches(
        container: ContainerSummary,
        service: Service,
        imageCounts: [String: Int]
    ) -> Bool {
        if let containerName = service.containerName?.nilIfBlank,
           container.id == containerName {
            return true
        }

        let labels = container.labels.mapKeys { $0.lowercased() }
        let projectLabel = labels["com.docker.compose.project"]
            ?? labels["com.apple.container.compose.project"]
            ?? labels["containerdesktop.compose.project"]
        let serviceLabel = labels["com.docker.compose.service"]
            ?? labels["com.apple.container.compose.service"]
            ?? labels["containerdesktop.compose.service"]

        if let projectLabel, let serviceLabel {
            return runtimeProjectNameCandidates.contains {
                projectLabel.caseInsensitiveCompare($0) == .orderedSame
            }
                && serviceLabel.caseInsensitiveCompare(service.name) == .orderedSame
        }

        let normalizedID = container.id.normalizedComposeToken
        let projectTokens = runtimeProjectNameCandidates
            .map(\.normalizedComposeToken)
            .filter { !$0.isEmpty }
        let serviceToken = service.name.normalizedComposeToken
        if !serviceToken.isEmpty,
           normalizedID.contains(serviceToken),
           (projectTokens.isEmpty || projectTokens.contains { normalizedID.contains($0) }) {
            return true
        }

        if let image = service.image?.nilIfBlank,
           imageCounts[image] == 1,
           container.imageName == image {
            return true
        }

        return false
    }

    private var runtimeProjectNameCandidates: [String] {
        [
            name,
            path.deletingLastPathComponent().lastPathComponent,
            path.deletingPathExtension().lastPathComponent,
        ]
        .compactMap(\.nilIfBlank)
        .uniquedCaseInsensitive()
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(map { (transform($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
    }
}

private extension String {
    var normalizedComposeToken: String {
        lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

private extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        return filter { value in
            seen.insert(value.lowercased()).inserted
        }
    }
}
