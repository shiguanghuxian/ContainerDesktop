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
}
