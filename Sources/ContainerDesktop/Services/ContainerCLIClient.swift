import Foundation

enum ContainerCLIClientError: LocalizedError, Sendable {
    case unsupportedMachineImage(reference: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedMachineImage(let reference, let detail):
            let suffix = detail.trimmed.isEmpty ? "" : "\n\(detail)"
            return "镜像 \(reference) 不适合作为 Machine 镜像，需要包含可执行的 /sbin/init。\(suffix)"
        }
    }
}

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

    func listMachines() async throws -> [MachineSummary] {
        try await decode([MachineSummary].self, executable: "container", arguments: ["machine", "list", "--format", "json"])
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

    func inspectMachine(_ id: String) async throws -> (details: [MachineInspection], rawText: String) {
        let result = try await runner.run(executable: "container", arguments: ["machine", "inspect", id], timeout: 120)
        let data = Data(result.stdout.utf8)
        let details = try JSONDecoder.containerDesktop.decode([MachineInspection].self, from: data)
        return (details, result.stdout)
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

    func machineLogs(_ id: String, boot: Bool = false, lines: Int? = 200) async throws -> String {
        var arguments = ["machine", "logs"]
        if boot {
            arguments.append("--boot")
        }
        if let lines {
            arguments.append(contentsOf: ["-n", String(lines)])
        }
        arguments.append(id)
        return try await runText(arguments: arguments)
    }

    func systemLogs(last: String = "5m") async throws -> String {
        try await runText(arguments: ["system", "logs", "--last", last])
    }

    func createMachine(
        name: String?,
        image: String,
        cpus: String?,
        memory: String?,
        homeMount: String?,
        setDefault: Bool,
        noBoot: Bool
    ) async throws {
        var arguments = ["machine", "create"]
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--name", name])
        }
        if let cpus, !cpus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--cpus", cpus])
        }
        if let memory, !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--memory", memory])
        }
        if let homeMount, !homeMount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            arguments.append(contentsOf: ["--home-mount", homeMount])
        }
        if setDefault {
            arguments.append("--set-default")
        }
        if noBoot {
            arguments.append("--no-boot")
        }
        arguments.append(image)
        _ = try await runner.run(executable: "container", arguments: arguments, timeout: 1200)
    }

    func validateMachineImage(reference: String) async throws {
        let trimmed = reference.trimmed
        guard !trimmed.isEmpty else {
            throw ContainerCLIClientError.unsupportedMachineImage(reference: reference, detail: "镜像不能为空。")
        }
        do {
            _ = try await runner.run(
                executable: "container",
                arguments: ["run", "--rm", "--entrypoint", "/bin/sh", trimmed, "-lc", "test -x /sbin/init"],
                timeout: 1200
            )
        } catch {
            throw ContainerCLIClientError.unsupportedMachineImage(
                reference: trimmed,
                detail: error.localizedDescription
            )
        }
    }

    func runContainer(name: String?, image: String, command: [String] = [], detached: Bool = true) async throws {
        let options = ContainerRunOptions(
            name: name,
            image: image,
            command: command,
            detached: detached
        )
        try await runContainer(options)
    }

    func runContainer(_ options: ContainerRunOptions) async throws {
        _ = try await runner.run(executable: "container", arguments: options.arguments, timeout: 1200)
    }

    func runMachineCommand(id: String, command: [String]) async throws -> String {
        var arguments = ["machine", "run", "-n", id, "--"]
        arguments.append(contentsOf: command)
        return try await runner.run(executable: "container", arguments: arguments, timeout: 1200).stdout
    }

    func startContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["start", id], timeout: 60)
    }

    func bootMachine(_ id: String) async throws {
        _ = try await runMachineCommand(id: id, command: ["true"])
    }

    func stopContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["stop", id], timeout: 60)
    }

    func stopMachine(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["machine", "stop", id], timeout: 120)
    }

    func deleteContainer(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["delete", id], timeout: 60)
    }

    func deleteMachine(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["machine", "delete", id], timeout: 120)
    }

    func setDefaultMachine(_ id: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["machine", "set-default", id], timeout: 60)
    }

    func setMachineConfig(id: String, cpus: String?, memory: String?, homeMount: String?) async throws {
        var settings: [String] = []
        if let cpus = cpus?.nilIfBlank {
            settings.append("cpus=\(cpus)")
        }
        if let memory = memory?.nilIfBlank {
            settings.append("memory=\(memory)")
        }
        if let homeMount = homeMount?.nilIfBlank {
            settings.append("home-mount=\(homeMount)")
        }
        guard !settings.isEmpty else { return }
        _ = try await runner.run(
            executable: "container",
            arguments: ["machine", "set", "-n", id] + settings,
            timeout: 60
        )
    }

    func pullImage(_ reference: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["image", "pull", reference], timeout: 900)
    }

    func buildImage(_ options: ImageBuildOptions) async throws -> String {
        try await runner.run(executable: "container", arguments: options.arguments, timeout: 3600).combinedOutput
    }

    func tagImage(source: String, target: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["image", "tag", source, target], timeout: 120)
    }

    func pushImage(_ options: ImagePushOptions) async throws -> String {
        try await runner.run(executable: "container", arguments: options.arguments, timeout: 1800).combinedOutput
    }

    func saveImages(_ options: ImageSaveOptions) async throws -> String {
        try await runner.run(executable: "container", arguments: options.arguments, timeout: 1800).combinedOutput
    }

    func loadImage(_ options: ImageLoadOptions) async throws -> String {
        try await runner.run(executable: "container", arguments: options.arguments, timeout: 1800).combinedOutput
    }

    func deleteImage(_ reference: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["image", "delete", reference], timeout: 120)
    }

    func pruneStoppedContainers() async throws -> String {
        try await runner.run(executable: "container", arguments: ["prune"], timeout: 300).stdout
    }

    func pruneDanglingImages() async throws -> String {
        try await runner.run(executable: "container", arguments: ["image", "prune"], timeout: 300).stdout
    }

    func createVolume(name: String, size: String? = nil, options: [String] = [], label: [String] = []) async throws {
        try await createVolume(VolumeCreateOptions(name: name, size: size, options: options, labels: label))
    }

    func createVolume(_ options: VolumeCreateOptions) async throws {
        _ = try await runner.run(executable: "container", arguments: options.arguments, timeout: 60)
    }

    func deleteVolume(_ name: String) async throws {
        _ = try await runner.run(executable: "container", arguments: ["volume", "delete", name], timeout: 60)
    }

    func pruneVolumes() async throws -> String {
        try await runner.run(executable: "container", arguments: ["volume", "prune"], timeout: 300).stdout
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


    func restartContainer(_ id: String) async throws {
        try await stopContainer(id)
        try await startContainer(id)
    }

    func execContainer(id: String, command: String) async throws -> String {
        let arguments = try CommandLineTokenizer.split(command)
        guard !arguments.isEmpty else {
            throw CommandRunnerError.executableNotFound("empty command")
        }
        let combined = ["exec", id] + arguments
        return try await runner.run(executable: "container", arguments: combined, timeout: 600).stdout
    }

    func containerFileContent(id: String, path: String) async throws -> String {
        let safePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safePath.isEmpty else {
            throw CommandRunnerError.executableNotFound("empty path")
        }
        return try await execContainerShell(id: id, script: "cat -- \(ShellEscaper.singleQuoted(safePath))")
    }

    func makeContainerLogStream(id: String, boot: Bool = false, lines: Int = 300) async throws -> ContainerProcessStream {
        let executable = try await resolvedExecutable(named: "container")
        var arguments = ["logs", "--follow", "-n", String(lines)]
        if boot {
            arguments.insert("--boot", at: 1)
        }
        arguments.append(id)
        return ContainerProcessStream(executable: executable, arguments: arguments)
    }

    func makeSystemLogStream(last: String = "5m") async throws -> ContainerProcessStream {
        let executable = try await resolvedExecutable(named: "container")
        return ContainerProcessStream(executable: executable, arguments: ["system", "logs", "--follow", "--last", last])
    }

    func makeContainerShellSession(id: String, shell: String = "sh") async throws -> ContainerTerminalSession {
        let executable = try await resolvedExecutable(named: "container")
        return ContainerTerminalSession(executable: executable, arguments: ["exec", "-it", id, shell])
    }

    func makeMachineShellSession(id: String, shell: String = "sh") async throws -> ContainerTerminalSession {
        let executable = try await resolvedExecutable(named: "container")
        return ContainerTerminalSession(executable: executable, arguments: ["machine", "run", "-n", id, "-i", "-t", "--", shell])
    }

    func listContainerFiles(id: String, path: String) async throws -> [ContainerFileEntry] {
        let normalizedPath = path.nilIfBlank ?? "/"
        let script = """
        dir=\(ShellEscaper.singleQuoted(normalizedPath))
        [ -d "$dir" ] || exit 2
        for p in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
          [ -e "$p" ] || continue
          name=${p##*/}
          kind=$(stat -c '%F' "$p" 2>/dev/null || echo other)
          mode=$(stat -c '%A' "$p" 2>/dev/null || echo '?')
          owner=$(stat -c '%U' "$p" 2>/dev/null || echo '?')
          group=$(stat -c '%G' "$p" 2>/dev/null || echo '?')
          size=$(stat -c '%s' "$p" 2>/dev/null || echo 0)
          mtime=$(stat -c '%Y' "$p" 2>/dev/null || echo 0)
          target=""
          if [ -L "$p" ]; then target=$(readlink "$p" 2>/dev/null || true); fi
          printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' "$name" "$p" "$kind" "$mode" "$owner" "$group" "$size" "$mtime" "$target"
        done
        """
        let output = try await execContainerShell(id: id, script: script)
        return output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { ContainerFileEntry.parseListingLine(String($0)) }
    }

    func writeContainerFile(id: String, path: String, contents: String) async throws {
        let safePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safePath.isEmpty else {
            throw CommandRunnerError.executableNotFound("empty path")
        }
        _ = try await runner.run(
            executable: "container",
            arguments: ["exec", "-i", id, "sh", "-lc", "cat > \(ShellEscaper.singleQuoted(safePath))"],
            timeout: 600,
            standardInput: contents
        )
    }

    func createContainerDirectory(id: String, path: String) async throws {
        try await execContainerShell(id: id, script: "mkdir -p -- \(ShellEscaper.singleQuoted(path))")
    }

    func renameContainerPath(id: String, source: String, destination: String) async throws {
        try await execContainerShell(
            id: id,
            script: "mv -- \(ShellEscaper.singleQuoted(source)) \(ShellEscaper.singleQuoted(destination))"
        )
    }

    func deleteContainerPath(id: String, path: String) async throws {
        try await execContainerShell(id: id, script: "rm -rf -- \(ShellEscaper.singleQuoted(path))")
    }

    func copyFromContainer(id: String, remotePath: String, localPath: String) async throws {
        _ = try await runner.run(
            executable: "container",
            arguments: ["copy", "\(id):\(remotePath)", localPath],
            timeout: 1200
        )
    }

    func copyToContainer(id: String, localPath: String, remotePath: String) async throws {
        _ = try await runner.run(
            executable: "container",
            arguments: ["copy", localPath, "\(id):\(remotePath)"],
            timeout: 1200
        )
    }

    func exportContainer(id: String, outputPath: String?) async throws -> String {
        var arguments = ["export"]
        arguments.appendOption("-o", outputPath)
        arguments.append(id)
        return try await runner.run(executable: "container", arguments: arguments, timeout: 1800).combinedOutput
    }

    @discardableResult
    func execContainerShell(id: String, script: String, timeout: TimeInterval = 600) async throws -> String {
        try await runner.run(
            executable: "container",
            arguments: ["exec", id, "sh", "-lc", script],
            timeout: timeout
        ).stdout
    }

    private func resolvedExecutable(named name: String) async throws -> String {
        guard let executable = await runner.resolveExecutable(named: name) else {
            throw ContainerProcessError.executableNotFound(name)
        }
        return executable
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
