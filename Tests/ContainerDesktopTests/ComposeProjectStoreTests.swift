import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose project store")
struct ComposeProjectStoreTests {
    @MainActor
    @Test("captures compose command failure output")
    func capturesComposeCommandFailureOutput() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try writeExecutable(
            named: "container-compose",
            in: directory,
            script: """
        #!/usr/bin/env bash
        echo "compose failed on stdout"
        echo "compose failed on stderr" >&2
        exit 42
        """
        )

        let composeFile = directory.appending(path: "compose.yml")
        try """
        services:
          web:
            image: nginx:latest
        """.write(to: composeFile, atomically: true, encoding: .utf8)

        let store = ComposeProjectStore(
            client: ComposeCLIClient(runner: CommandRunner(searchRoots: [directory])),
            persistenceURL: directory.appending(path: "compose-projects.json")
        )
        let project = ComposeProject(
            path: composeFile,
            name: "demo",
            services: [ComposeProject.Service(name: "web", image: "nginx:latest")],
            volumes: [],
            networks: [],
            lastModified: Date()
        )

        await store.up(project)

        #expect(store.errorMessage?.contains("退出码 42") == true)
        #expect(store.errorMessage?.contains("compose failed on stdout") == true)
        #expect(store.errorMessage?.contains("compose failed on stderr") == true)
        #expect(store.lastOutput.contains("compose failed on stdout"))
        #expect(store.lastOutput.contains("compose failed on stderr"))
        #expect(store.busyProjectID == nil)
    }

    @MainActor
    @Test("adds builder latest guidance to compose build failures")
    func addsBuilderLatestGuidanceToComposeBuildFailures() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try writeExecutable(
            named: "container-compose",
            in: directory,
            script: """
            #!/usr/bin/env bash
            echo 'Building image for service: app (Tag: localhost/containerdesktop/demo:latest)'
            echo 'Error: unknown: "HTTP request to https://ghcr.io/v2/apple/container-builder-shim/builder/manifests/latest failed with response: 404 Not Found. Reason: Unknown"'
            exit 1
            """
        )

        let composeFile = directory.appending(path: "compose.yml")
        try """
        services:
          app:
            build: .
            image: localhost/containerdesktop/demo:latest
        """.write(to: composeFile, atomically: true, encoding: .utf8)

        let store = ComposeProjectStore(
            client: ComposeCLIClient(runner: CommandRunner(searchRoots: [directory])),
            persistenceURL: directory.appending(path: "compose-projects.json")
        )
        let project = ComposeProject(
            path: composeFile,
            name: "demo",
            services: [ComposeProject.Service(name: "app", image: "localhost/containerdesktop/demo:latest", buildContext: ".")],
            volumes: [],
            networks: [],
            lastModified: Date()
        )

        await store.up(project)

        #expect(store.errorMessage?.contains(ContainerBuilderImageDefaults.legacyLatestImage) == true)
        #expect(store.errorMessage?.contains(ContainerBuilderImageDefaults.currentImage) == true)
        #expect(store.errorMessage?.contains("重启 container system") == true)
        #expect(store.lastOutput.contains(ContainerBuilderImageDefaults.currentImage))
    }

    @MainActor
    @Test("adds vminit latest guidance to compose build failures")
    func addsVminitLatestGuidanceToComposeBuildFailures() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try writeExecutable(
            named: "container-compose",
            in: directory,
            script: """
            #!/usr/bin/env bash
            echo 'Building services'
            echo 'Error: internalError: "failed to create container" (cause: "unknown: "HTTP request to https://ghcr.io/v2/apple/containerization/vminit/manifests/latest failed with response: 404 Not Found. Reason: Unknown"")'
            exit 1
            """
        )

        let composeFile = directory.appending(path: "compose.yml")
        try """
        services:
          app:
            image: alpine:latest
        """.write(to: composeFile, atomically: true, encoding: .utf8)

        let store = ComposeProjectStore(
            client: ComposeCLIClient(runner: CommandRunner(searchRoots: [directory])),
            persistenceURL: directory.appending(path: "compose-projects.json")
        )
        let project = ComposeProject(
            path: composeFile,
            name: "demo",
            services: [ComposeProject.Service(name: "app", image: "alpine:latest")],
            volumes: [],
            networks: [],
            lastModified: Date()
        )

        await store.up(project)

        #expect(store.errorMessage?.contains(ContainerVminitImageDefaults.legacyLatestImage) == true)
        #expect(store.errorMessage?.contains(ContainerVminitImageDefaults.currentImage) == true)
        #expect(store.errorMessage?.contains("重启 container system") == true)
        #expect(store.lastOutput.contains(ContainerVminitImageDefaults.currentImage))
    }

    private func makeTemporaryDirectory() throws -> URL {
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
