import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose parser")
struct ComposeParserTests {
    @Test("parses compose services, volumes, and networks")
    func parsesComposeFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "docker-compose.yml")
        try """
        name: demo
        services:
          web:
            image: nginx:latest
            container_name: demo_web
            ports:
              - "8080:80"
            depends_on:
              - db
          db:
            image: postgres:16
            environment:
              POSTGRES_PASSWORD: example
        volumes:
          data:
        networks:
          appnet:
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let project = try ComposeParser.parse(fileURL: fileURL)

        #expect(project.name == "demo")
        #expect(project.services.count == 2)
        #expect(project.services.first { $0.name == "web" }?.ports == ["8080:80"])
        #expect(project.services.first { $0.name == "web" }?.containerName == "demo_web")
        #expect(project.volumes == ["data"])
        #expect(project.networks == ["appnet"])
    }

    @Test("uses parent directory as default project name")
    func usesParentDirectoryAsDefaultProjectName() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appending(path: "base", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "docker-compose.yml")
        try """
        services:
          mysql:
            image: mysql:8.0
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let project = try ComposeParser.parse(fileURL: fileURL)

        #expect(project.name == "base")
    }
}
