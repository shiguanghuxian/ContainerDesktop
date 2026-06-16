import Foundation

struct ResourceMonitorClient: Sendable {
    let containerClient: ContainerCLIClient
    let hostProcessClient: HostProcessMonitorClient

    init(
        containerClient: ContainerCLIClient = ContainerCLIClient(),
        hostProcessClient: HostProcessMonitorClient = HostProcessMonitorClient()
    ) {
        self.containerClient = containerClient
        self.hostProcessClient = hostProcessClient
    }

    func sample(
        containerIDs: [String] = [],
        previousSamples: [String: ContainerResourceSample] = [:],
        runningContainerCount: Int,
        date: Date = Date()
    ) async throws -> ResourceMonitorSnapshot {
        async let statsTask = containerClient.containerStats(containerIDs)
        async let hostProcessTask = hostProcessClient.processes()

        let snapshots = try await statsTask
        let hostProcesses = try await hostProcessTask
        let samples = snapshots
            .map { snapshot in
                ContainerResourceSample.make(
                    snapshot: snapshot,
                    date: date,
                    previous: previousSamples[snapshot.id]
                )
            }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
        let environment = EnvironmentResourceSnapshot(
            date: date,
            containerSamples: samples,
            runningContainerCount: runningContainerCount,
            hostProcesses: hostProcesses
        )

        return ResourceMonitorSnapshot(
            date: date,
            containerSamples: samples,
            hostProcesses: hostProcesses,
            environment: environment
        )
    }
}

struct HostProcessMonitorClient: Sendable {
    let runner: CommandRunner

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func processes() async throws -> [HostProcessResourceSnapshot] {
        let result = try await runner.run(
            executable: "ps",
            arguments: ["-axo", "pid=,ppid=,pcpu=,rss=,comm=,args="],
            timeout: 20
        )
        return Self.parse(output: result.stdout)
    }

    static func parse(output: String) -> [HostProcessResourceSnapshot] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
            .sorted { lhs, rhs in
                if lhs.category != rhs.category {
                    return lhs.category.sortOrder < rhs.category.sortOrder
                }
                if lhs.cpuPercent != rhs.cpuPercent {
                    return lhs.cpuPercent > rhs.cpuPercent
                }
                return lhs.pid < rhs.pid
            }
    }

    static func parseLine(_ line: String) -> HostProcessResourceSnapshot? {
        let parts = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            .map(String.init)
        guard parts.count >= 6,
              let pid = Int(parts[0]),
              let parentPID = Int(parts[1]),
              let cpuPercent = Double(parts[2]),
              let rssKilobytes = Int64(parts[3]) else {
            return nil
        }

        let command = parts[4]
        let arguments = parts[5]
        guard let category = category(command: command, arguments: arguments) else {
            return nil
        }

        return HostProcessResourceSnapshot(
            pid: pid,
            parentPID: parentPID,
            cpuPercent: cpuPercent,
            residentMemoryBytes: rssKilobytes * 1024,
            command: command,
            arguments: arguments,
            category: category
        )
    }

    private static func category(command: String, arguments: String) -> HostProcessResourceCategory? {
        let commandName = URL(fileURLWithPath: command).lastPathComponent
        let argumentsName = URL(fileURLWithPath: arguments.components(separatedBy: " ").first ?? arguments).lastPathComponent
        let combined = "\(command) \(arguments)"

        if commandName == "container-compose" || argumentsName == "container-compose" || combined.contains("/container-compose ") {
            return .containerCompose
        }

        if commandName == "container" || argumentsName == "container" || combined.contains("/container ") {
            return .containerCLI
        }

        if commandName == "container-runtime-linux" || combined.contains("container-runtime-linux") {
            return .containerRuntime
        }

        let serviceNames = [
            "container-apiserver",
            "machine-apiserver",
            "container-network-vmnet",
            "container-core-images",
            "containermanagerd",
        ]
        if serviceNames.contains(commandName) || serviceNames.contains(argumentsName) || serviceNames.contains(where: { combined.contains($0) }) {
            return .containerService
        }

        return nil
    }
}

private extension HostProcessResourceCategory {
    var sortOrder: Int {
        switch self {
        case .containerService: 0
        case .containerRuntime: 1
        case .containerCompose: 2
        case .containerCLI: 3
        }
    }
}
