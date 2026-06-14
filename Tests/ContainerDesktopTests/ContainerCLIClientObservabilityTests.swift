import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Container CLI observability commands")
struct ContainerCLIClientObservabilityTests {
    @Test("system logs uses last duration")
    func systemLogsUsesLastDuration() async throws {
        let fake = try FakeObservabilityCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        let output = try await client.systemLogs(last: "10m")

        #expect(output == "system logs output\n")
        #expect(try fake.commandLog().contains("system logs --last 10m\n"))
    }
}

private struct FakeObservabilityCLI {
    let directory: URL
    let logURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        logURL = directory.appending(path: "commands.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let executable = directory.appending(path: "container")
        try """
        #!/usr/bin/env bash
        set -euo pipefail
        printf '%s\\n' "$*" >> "\(logURL.path)"

        case "$*" in
          "system logs --last 10m")
            printf 'system logs output\\n'
            ;;
          *)
            echo "unexpected command: $*" >&2
            exit 64
            ;;
        esac
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }

    func commandLog() throws -> String {
        try String(contentsOf: logURL, encoding: .utf8)
    }
}
