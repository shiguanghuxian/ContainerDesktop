import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Compose and volume operations")
struct ComposeAndVolumeOptionsTests {
    @Test("builds compose operation arguments")
    func buildsComposeOperationArguments() {
        let composePath = URL(fileURLWithPath: "/tmp/compose.yml")
        let options = ComposeOperationOptions(
            services: ["web"],
            detach: true,
            buildBeforeUp: true,
            noCache: true,
            interactive: true,
            tty: true,
            user: "1000:1000",
            workdir: "/app",
            env: ["RAILS_ENV=production"],
            envFiles: ["/tmp/.env"],
            ulimits: ["nofile=1024:2048"]
        )

        #expect(options.upArguments(composePath: composePath) == [
            "up",
            "-f", "/tmp/compose.yml",
            "-i",
            "-t",
            "-u", "1000:1000",
            "-w", "/app",
            "-e", "RAILS_ENV=production",
            "--env-file", "/tmp/.env",
            "--ulimit", "nofile=1024:2048",
            "-d",
            "-b",
            "--no-cache",
            "web",
        ])

        #expect(options.downArguments(composePath: composePath).contains("-b") == false)
        #expect(options.buildArguments(composePath: composePath).contains("--no-cache"))
    }

    @Test("builds registry basic authorization")
    func buildsRegistryBasicAuthorization() {
        let credentials = RegistryBrowseCredentials(username: "user", password: "token")

        #expect(credentials.isUsable)
        #expect(credentials.basicAuthorizationHeader == "Basic dXNlcjp0b2tlbg==")
    }

    @Test("lists and exports volume files")
    func listsAndExportsVolumeFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let nested = root.appending(path: "nested", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "hello".write(to: root.appending(path: "hello.txt"), atomically: true, encoding: .utf8)

        let service = VolumeBrowserService()
        let snapshot = try service.list(sourcePath: root.path)
        #expect(snapshot.displayPath == "/")
        #expect(snapshot.entries.contains { $0.name == "hello.txt" && !$0.isDirectory })
        #expect(snapshot.entries.contains { $0.name == "nested" && $0.isDirectory })

        let archive = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).tar")
        _ = try await service.exportVolume(sourcePath: root.path, outputPath: archive.path)
        #expect(FileManager.default.fileExists(atPath: archive.path))
    }

    @Test("clones and empties volume directories")
    func clonesAndEmptiesVolumeDirectories() async throws {
        let fileManager = FileManager.default
        let source = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let target = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let nested = source.appending(path: "nested", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        try "hello".write(to: nested.appending(path: "hello.txt"), atomically: true, encoding: .utf8)

        let service = VolumeBrowserService()
        _ = try await service.cloneVolume(sourcePath: source.path, destinationPath: target.path)

        let clonedFile = target.appending(path: "nested/hello.txt")
        #expect(try String(contentsOf: clonedFile, encoding: .utf8) == "hello")

        _ = try await service.emptyVolume(sourcePath: source.path)
        #expect(try fileManager.contentsOfDirectory(atPath: source.path).isEmpty)
    }

    @Test("rejects cloning into non-empty volume directories")
    func rejectsCloningIntoNonEmptyVolumeDirectories() async throws {
        let fileManager = FileManager.default
        let source = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let target = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        try "source".write(to: source.appending(path: "source.txt"), atomically: true, encoding: .utf8)
        try "existing".write(to: target.appending(path: "existing.txt"), atomically: true, encoding: .utf8)

        let service = VolumeBrowserService()
        var didReject = false
        do {
            _ = try await service.cloneVolume(sourcePath: source.path, destinationPath: target.path)
        } catch {
            didReject = true
        }

        #expect(didReject)
        #expect(FileManager.default.fileExists(atPath: target.appending(path: "existing.txt").path))
    }

    @Test("creates renames and deletes volume file entries")
    func createsRenamesAndDeletesVolumeFileEntries() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let service = VolumeBrowserService()
        _ = try await service.createDirectory(sourcePath: root.path, relativePath: "", name: "data")
        let createdDirectory = root.appending(path: "data", directoryHint: .isDirectory)
        #expect(fileManager.fileExists(atPath: createdDirectory.path))

        let fileURL = createdDirectory.appending(path: "old.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        _ = try await service.renameEntry(sourcePath: root.path, entryPath: fileURL.path, newName: "new.txt")
        let renamedFile = createdDirectory.appending(path: "new.txt")
        #expect(fileManager.fileExists(atPath: renamedFile.path))
        #expect(!fileManager.fileExists(atPath: fileURL.path))

        _ = try await service.deleteEntry(sourcePath: root.path, entryPath: renamedFile.path)
        #expect(!fileManager.fileExists(atPath: renamedFile.path))
    }

    @Test("rejects unsafe volume file entry paths")
    func rejectsUnsafeVolumeFileEntryPaths() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let outside = fileManager.temporaryDirectory.appending(path: "\(UUID().uuidString)-outside.txt")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "outside".write(to: outside, atomically: true, encoding: .utf8)

        let service = VolumeBrowserService()
        var rejectedName = false
        do {
            _ = try await service.createDirectory(sourcePath: root.path, relativePath: "", name: "../escape")
        } catch {
            rejectedName = true
        }

        var rejectedDelete = false
        do {
            _ = try await service.deleteEntry(sourcePath: root.path, entryPath: outside.path)
        } catch {
            rejectedDelete = true
        }

        #expect(rejectedName)
        #expect(rejectedDelete)
        #expect(fileManager.fileExists(atPath: outside.path))
    }
}
