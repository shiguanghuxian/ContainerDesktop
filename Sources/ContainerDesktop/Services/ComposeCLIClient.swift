import Foundation

struct ComposeCLIClient: Sendable {
    let runner: CommandRunner

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func build(composePath: URL, services: [String] = [], noCache: Bool = false) async throws -> CommandResult {
        let options = ComposeOperationOptions(services: services, noCache: noCache)
        return try await build(composePath: composePath, options: options)
    }

    func build(composePath: URL, options: ComposeOperationOptions) async throws -> CommandResult {
        let arguments = options.buildArguments(composePath: composePath)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 2400)
    }

    func up(composePath: URL, services: [String] = [], detach: Bool = true, noCache: Bool = false) async throws -> CommandResult {
        let options = ComposeOperationOptions(services: services, detach: detach, noCache: noCache)
        return try await up(composePath: composePath, options: options)
    }

    func up(composePath: URL, options: ComposeOperationOptions) async throws -> CommandResult {
        let arguments = options.upArguments(composePath: composePath)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 2400)
    }

    func down(composePath: URL, services: [String] = []) async throws -> CommandResult {
        let options = ComposeOperationOptions(services: services)
        return try await down(composePath: composePath, options: options)
    }

    func down(composePath: URL, options: ComposeOperationOptions) async throws -> CommandResult {
        let arguments = options.downArguments(composePath: composePath)
        return try await runner.run(executable: "container-compose", arguments: arguments, workingDirectory: composePath.deletingLastPathComponent(), timeout: 1200)
    }

    func version() async throws -> CommandResult {
        try await runner.run(executable: "container-compose", arguments: ["version"], timeout: 60)
    }
}
