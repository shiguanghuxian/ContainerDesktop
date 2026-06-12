import Foundation

struct ComposeCLIClient: Sendable {
    let runner: CommandRunner

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func build(composePath: URL, services: [String] = [], noCache: Bool = false) async throws -> CommandResult {
        var arguments = ["build", "-f", composePath.path]
        if noCache {
            arguments.append("--no-cache")
        }
        arguments.append(contentsOf: services)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 2400)
    }

    func up(composePath: URL, services: [String] = [], detach: Bool = true, noCache: Bool = false) async throws -> CommandResult {
        var arguments = ["up", "-f", composePath.path]
        if detach {
            arguments.append("-d")
        }
        if noCache {
            arguments.append("--no-cache")
        }
        arguments.append(contentsOf: services)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 2400)
    }

    func down(composePath: URL, services: [String] = []) async throws -> CommandResult {
        var arguments = ["down", "-f", composePath.path]
        arguments.append(contentsOf: services)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 1200)
    }
}
