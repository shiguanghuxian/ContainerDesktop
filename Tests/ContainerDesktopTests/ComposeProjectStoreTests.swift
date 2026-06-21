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

    @MainActor
    @Test("register external project loads existing records and persists")
    func registerExternalProjectLoadsExistingRecordsAndPersists() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let existingComposeFile = directory.appending(path: "existing.yml")
        let newComposeFile = directory.appending(path: "compose.yaml")
        try writeComposeFile(existingComposeFile, projectName: "existing", serviceNames: ["web"])
        try writeComposeFile(newComposeFile, projectName: "auto", serviceNames: ["api"])

        let persistenceURL = directory.appending(path: "compose-projects.json")
        let existingRecord = ComposeProjectRecord(
            path: existingComposeFile.path,
            name: "existing",
            services: 1,
            lastOpened: Date()
        )
        let data = try JSONEncoder.containerDesktop.encode([existingRecord])
        try data.write(to: persistenceURL, options: [.atomic])

        let store = ComposeProjectStore(persistenceURL: persistenceURL)

        await store.registerExternalProject(fileURL: newComposeFile)

        #expect(store.hasLoaded)
        #expect(store.projects.map(\.path) == [
            newComposeFile.standardizedFileURL,
            existingComposeFile.standardizedFileURL,
        ])

        let records = try JSONDecoder.containerDesktop.decode(
            [ComposeProjectRecord].self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(records.map(\.path) == [
            newComposeFile.standardizedFileURL.path,
            existingComposeFile.standardizedFileURL.path,
        ])
    }

    @MainActor
    @Test("register external project deduplicates and refreshes")
    func registerExternalProjectDeduplicatesAndRefreshes() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let composeFile = directory.appending(path: "compose.yaml")
        let persistenceURL = directory.appending(path: "compose-projects.json")
        let store = ComposeProjectStore(persistenceURL: persistenceURL)

        try writeComposeFile(composeFile, projectName: "auto", serviceNames: ["web"])
        await store.registerExternalProject(fileURL: composeFile)

        try writeComposeFile(composeFile, projectName: "auto", serviceNames: ["web", "api"])
        await store.registerExternalProject(fileURL: composeFile)

        #expect(store.projects.count == 1)
        #expect(store.projects.first?.services.map(\.name) == ["api", "web"])

        let records = try JSONDecoder.containerDesktop.decode(
            [ComposeProjectRecord].self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(records.count == 1)
        #expect(records.first?.services == 2)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeComposeFile(_ fileURL: URL, projectName: String, serviceNames: [String]) throws {
        let services = serviceNames
            .map {
                """
                  \($0):
                    image: alpine:latest
                """
            }
            .joined(separator: "\n")
        try """
        name: \(projectName)
        services:
        \(services)
        """.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func writeExecutable(named name: String, in directory: URL, script: String) throws {
        let executable = directory.appending(path: name)
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }
}
