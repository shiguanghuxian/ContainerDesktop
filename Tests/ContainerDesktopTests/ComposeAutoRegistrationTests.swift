import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose auto registration")
struct ComposeAutoRegistrationTests {
    @Test("docker compose up resolves default compose file")
    func dockerComposeUpResolvesDefaultComposeFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let composeFile = directory.appending(path: "compose.yaml")
        try writeComposeFile(composeFile, serviceNames: ["web"])

        let request = DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "docker",
            arguments: ["compose", "up", "-d"],
            workingDirectory: directory
        )

        #expect(request?.composeFileURL == composeFile.standardizedFileURL)
        #expect(request?.source == .dockerCompatibilityTerminal)
    }

    @Test("docker compose file flags resolve relative and absolute paths")
    func dockerComposeFileFlagsResolvePaths() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let relativeComposeFile = directory.appending(path: "custom.yml")
        let absoluteComposeFile = directory.appending(path: "absolute.yml")
        try writeComposeFile(relativeComposeFile, serviceNames: ["web"])
        try writeComposeFile(absoluteComposeFile, serviceNames: ["api"])

        let dockerRequest = DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "/usr/local/bin/docker",
            arguments: ["--context", "desktop", "compose", "-f", "custom.yml", "build"],
            workingDirectory: directory
        )
        let legacyRequest = DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "docker-compose",
            arguments: ["--file", absoluteComposeFile.path, "down"],
            workingDirectory: directory
        )

        #expect(dockerRequest?.composeFileURL == relativeComposeFile.standardizedFileURL)
        #expect(legacyRequest?.composeFileURL == absoluteComposeFile.standardizedFileURL)
    }

    @Test("compose registration ignores non project commands and missing files")
    func composeRegistrationIgnoresNonProjectCommands() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let composeFile = directory.appending(path: "compose.yaml")
        try writeComposeFile(composeFile, serviceNames: ["web"])

        #expect(DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "docker",
            arguments: ["compose", "version"],
            workingDirectory: directory
        ) == nil)
        #expect(DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "docker",
            arguments: ["compose", "--help"],
            workingDirectory: directory
        ) == nil)
        #expect(DockerCommandShimCLI.composeProjectRegistrationRequest(
            executable: "docker",
            arguments: ["compose", "-f", "missing.yml", "up", "-d"],
            workingDirectory: directory
        ) == nil)
    }

    @Test("auto registration notification round trips request")
    func autoRegistrationNotificationRoundTripsRequest() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let composeFile = directory.appending(path: "compose.yaml")

        let request = ComposeProjectAutoRegistrationNotification.request(from: [
            ComposeProjectAutoRegistrationNotification.composeFilePathUserInfoKey: composeFile.path,
            ComposeProjectAutoRegistrationNotification.sourceUserInfoKey: ComposeProjectAutoRegistrationSource.dockerCompatibilityTerminal.rawValue,
        ])

        #expect(request?.composeFileURL == composeFile.standardizedFileURL)
        #expect(request?.source == .dockerCompatibilityTerminal)
    }

    @Test("shim and main app wire compose auto registration")
    func shimAndMainAppWireComposeAutoRegistration() throws {
        let shimSource = try source("Sources/ContainerDesktop/Services/DockerCommandShimCLI.swift")
        let appSource = try source("Sources/ContainerDesktop/App/ContainerDesktopApp.swift")

        #expect(shimSource.contains("postComposeProjectAutoRegistrationIfNeeded"))
        #expect(shimSource.contains("ComposeProjectAutoRegistrationNotification.post(request)"))
        #expect(appSource.contains("observeComposeProjectAutoRegistrationRequests()"))
        #expect(appSource.contains("ComposeProjectAutoRegistrationNotification.name"))
        #expect(appSource.contains("composeStore.registerExternalProject"))

        let postCall = try #require(shimSource.range(of: "postComposeProjectAutoRegistrationIfNeeded"))
        let execCall = try #require(shimSource.range(of: "if result.commands.count == 1"))
        #expect(postCall.lowerBound < execCall.lowerBound)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeComposeFile(_ fileURL: URL, serviceNames: [String]) throws {
        let services = serviceNames
            .map {
                """
                  \($0):
                    image: alpine:latest
                """
            }
            .joined(separator: "\n")
        try """
        services:
        \(services)
        """.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
