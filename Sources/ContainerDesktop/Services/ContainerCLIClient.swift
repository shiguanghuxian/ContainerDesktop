import Foundation

struct ContainerCLIClient: Sendable {
    let runner: CommandRunner

    private struct SystemStatusResponse: Decodable {
        var status: String
    }

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func probe() async -> EnvironmentProbe {
        let macVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let architecture = ProcessInfo.processInfo.environment["PROCESSOR_ARCHITECTURE"] ?? {
            #if arch(arm64)
            return "arm64"
            #else
            return "x86_64"
            #endif
        }()

        let containerAvailable = await runner.resolveExecutable(named: "container") != nil
        let composeAvailable = await runner.resolveExecutable(named: "container-compose") != nil

        var systemRunning = false
        var systemVersion: String?
        var errorMessage: String?

        if containerAvailable {
            do {
                let result = try await runner.run(
                    executable: "container",
                    arguments: ["system", "status", "--format", "json"],
                    timeout: 30
                )
                let data = Data(result.stdout.utf8)
                let status = try? JSONDecoder.containerDesktop.decode(SystemStatusResponse.self, from: data)
                systemRunning = status?.status == "running"
                systemVersion = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        return EnvironmentProbe(
            macOSVersion: macVersion,
            architecture: architecture,
            containerAvailable: containerAvailable,
            containerComposeAvailable: composeAvailable,
            systemRunning: systemRunning,
            systemVersion: systemVersion,
            errorMessage: errorMessage
        )
    }

    func systemVersion() async throws -> [SystemVersionEntry] {
        try await decode([SystemVersionEntry].self, executable: "container", arguments: ["system", "version", "--format", "json"])
    }

    func systemProperties() async throws -> JSONValue {
        try await decode(JSONValue.self, executable: "container", arguments: ["system", "property", "list", "--format", "json"])
    }

    func systemDF() async throws -> DiskUsageSummary {
        try await decode(DiskUsageSummary.self, executable: "container", arguments: ["system", "df", "--format", "json"])
    }

    func listContainers() async throws -> [ContainerSummary] {
        try await decode([ContainerSummary].self, executable: "container", arguments: ["list", "--all", "--format", "json"])
    }

    func listImages() async throws -> [ImageSummary] {
        try await decode([ImageSummary].self, executable: "container", arguments: ["image", "list", "--format", "json"])
    }

    func listVolumes() async throws -> [VolumeSummary] {
        try await decode([VolumeSummary].self, executable: "container", arguments: ["volume", "list", "--format", "json"])
    }

    func listNetworks() async throws -> [NetworkSummary] {
        try await decode([NetworkSummary].self, executable: "container", arguments: ["network", "list", "--format", "json"])
    }

    func listRegistries() async throws -> [RegistrySummary] {
        try await decode([RegistrySummary].self, executable: "container", arguments: ["registry", "list", "--format", "json"])
    }

    func listMachineIDs() async throws -> [String] {
        try await decode([String].self, executable: "container", arguments: ["machine", "list", "--quiet", "--format", "json"])
    }

    func inspectContainer(_ id: String) async throws -> JSONValue {
        try await decode(JSONValue.self, executable: "container", arguments: ["inspect", id])
    }

    func inspectImage(_ reference: String) async throws -> JSONValue {
        try await decode(JSONValue.self, executable: "container", arguments: ["image", "inspect", reference])
    }

    func inspectVolume(_ name: String) async throws -> JSONValue {
        try await decode(JSONValue.self, executable: "container", arguments: ["volume", "inspect", name])
    }

    func inspectNetwork(_ name: String) async throws -> JSONValue {
        try await decode(JSONValue.self, executable: "container", arguments: ["network", "inspect", name])
    }

    func containerLogs(_ id: String, boot: Bool = false, lines: Int? = 200) async throws -> String {
        var arguments = ["logs"]
        if boot {
            arguments.append("--boot")
        }
        if let lines {
            arguments.append(contentsOf: ["-n", String(lines)])
        }
        arguments.append(id)
        return try await runText(arguments: arguments)
    }

    func containerStats(_ ids: [String] = []) async throws -> [ContainerStatsSnapshot] {
        var arguments = ["stats", "--format", "json", "--no-stream"]
        arguments.append(contentsOf: ids)
        return try await decode([ContainerStatsSnapshot].self, executable: "container", arguments: arguments)
    }

    func runContainer(name: String?, image: String, command: [String] = [], detached: Bool = true) async throws {
        var arguments = ["run"]
        if detached {
            arguments.append("-d")
        }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--name", name])
        }
        arguments.append(image)
        arguments.append(contentsOf: command)
        _ = try await runner.run(executable: "container", arguments: arguments, timeout: 1200)
    }

    func startContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["start", id], timeout: 60)
    }

    func stopContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["stop", id], timeout: 60)
    }

    func deleteContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["delete", id], timeout: 60)
    }

    func pullImage(_ reference: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["image", "pull", reference], timeout: 900)
    }

    func deleteImage(_ reference: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["image", "delete", reference], timeout: 120)
    }

    func createVolume(name: String, size: String? = nil, options: [String] = [], label: [String] = []) async throws {
        var arguments = ["volume", "create"]
        for entry in label {
            arguments.append(contentsOf: ["--label", entry])
        }
        for entry in options {
            arguments.append(contentsOf: ["--opt", entry])
        }
        if let size {
            arguments.append(contentsOf: ["-s", size])
        }
        arguments.append(name)
        _ = try await runner.run(executable: "container", arguments: arguments, timeout: 60)
    }

    func deleteVolume(_ name: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["volume", "delete", name], timeout: 60)
    }

    func createNetwork(name: String, internalOnly: Bool = false, subnet: String? = nil, subnetV6: String? = nil) async throws {
        var arguments = ["network", "create"]
        if internalOnly {
            arguments.append("--internal")
        }
        if let subnet {
            arguments.append(contentsOf: ["--subnet", subnet])
        }
        if let subnetV6 {
            arguments.append(contentsOf: ["--subnet-v6", subnetV6])
        }
        arguments.append(name)
        _ = try await runner.run(executable: "container", arguments: arguments, timeout: 60)
    }

    func deleteNetwork(_ name: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["network", "delete", name], timeout: 60)
    }

    func loginRegistry(server: String, username: String, password: String) async throws {
        _ = try await runner.run(
            executable: "container",
            arguments: ["registry", "login", "--password-stdin", "--username", username, server],
            timeout: 120,
            standardInput: password
        )
    }

    func logoutRegistry(_ registry: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["registry", "logout", registry], timeout: 60)
    }

    func startSystem() async throws {
        _ = try await runner.run(executable: "container", arguments: ["system", "start"], timeout: 300)
    }

    func stopSystem() async throws {
        _ = try await runner.run(executable: "container", arguments: ["system", "stop"], timeout: 120)
    }

    private func runText(arguments: [String]) async throws -> String {
        try await runner.run(executable: "container", arguments: arguments, timeout: 600).stdout
    }

    private func decode<T: Decodable>(_ type: T.Type, executable: String, arguments: [String]) async throws -> T {
        let result = try await runner.run(executable: executable, arguments: arguments, timeout: 1200)
        let data = Data(result.stdout.utf8)
        return try JSONDecoder.containerDesktop.decode(T.self, from: data)
    }
}
