import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Command runner")
struct CommandRunnerTests {
    @Test("runs a fake CLI from a configured search root")
    func runsFakeCLI() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appending(path: "fake-container")
        try """
        #!/usr/bin/env bash
        echo "{\\"ok\\":true}"
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let runner = CommandRunner(searchRoots: [directory])
        let result = try await runner.run(executable: "fake-container")

        #expect(result.stdout.contains("\"ok\":true"))
        #expect(result.exitCode == 0)
    }

    @Test("passes standard input to a fake CLI")
    func passesStandardInput() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appending(path: "fake-login")
        try """
        #!/usr/bin/env bash
        read -r password
        echo "password:$password"
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let runner = CommandRunner(searchRoots: [directory])
        let result = try await runner.run(executable: "fake-login", standardInput: "secret-token\n")

        #expect(result.stdout.contains("password:secret-token"))
    }

    @Test("reports stdout from non-zero exits")
    func reportsStdoutFromNonZeroExits() async throws {
        let directory = try makeTemporaryExecutableDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeExecutable(
            named: "fake-failing-cli",
            in: directory,
            script: """
            #!/usr/bin/env bash
            echo "failure written to stdout"
            exit 42
            """
        )

        let runner = CommandRunner(searchRoots: [directory])
        var description = ""
        do {
            _ = try await runner.run(executable: "fake-failing-cli")
        } catch {
            description = error.localizedDescription
        }

        #expect(description.contains("退出码 42"))
        #expect(description.contains("fake-failing-cli"))
        #expect(description.contains("failure written to stdout"))
    }

    @Test("reports stderr from non-zero exits")
    func reportsStderrFromNonZeroExits() async throws {
        let directory = try makeTemporaryExecutableDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeExecutable(
            named: "fake-stderr-cli",
            in: directory,
            script: """
            #!/usr/bin/env bash
            echo "failure written to stderr" >&2
            exit 7
            """
        )

        let runner = CommandRunner(searchRoots: [directory])
        var description = ""
        do {
            _ = try await runner.run(executable: "fake-stderr-cli")
        } catch {
            description = error.localizedDescription
        }

        #expect(description.contains("退出码 7"))
        #expect(description.contains("fake-stderr-cli"))
        #expect(description.contains("failure written to stderr"))
    }

    private func makeTemporaryExecutableDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeExecutable(named name: String, in directory: URL, script: String) throws {
        let executable = directory.appending(path: name)
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }
}
