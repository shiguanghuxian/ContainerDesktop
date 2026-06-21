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

    @Test("lists container backed volume files through transient container command")
    func listsContainerBackedVolumeFilesThroughTransientContainerCommand() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        interactive=0
        last=""
        for arg in "$@"; do
          if [ "$arg" = "-i" ]; then interactive=1; fi
          last="$arg"
        done
        if [ "$interactive" != "1" ]; then
          exit 0
        fi
        cat >/dev/null
        printf '[0/6] [0s]\\n'
        if [ "$last" = "config" ]; then
          printf 'f\\t7\\t1781233548\\tapp.env\\n'
        else
          printf 'd\\t\\t1781233546\\tconfig\\n'
          printf 'f\\t42\\t1781233547\\tREADME.md\\n'
        fi
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)

        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        let snapshot = try await service.list(volumeName: "demo-volume", sourcePath: imageFile.path)

        #expect(snapshot.displayPath == "/")
        #expect(snapshot.entries.map(\.name) == ["config", "README.md"])
        #expect(snapshot.entries[0].isDirectory)
        #expect(!snapshot.entries[0].isHostBacked)
        #expect(snapshot.entries[1].size == 42)

        let nested = try await service.list(volumeName: "demo-volume", sourcePath: imageFile.path, relativePath: "config")
        #expect(nested.displayPath == "/config")
        #expect(nested.entries.map(\.name) == ["app.env"])
        #expect(nested.entries[0].size == 7)
        #expect(!nested.entries[0].isHostBacked)
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

    @Test("volume browser store keeps create directory status after refresh")
    @MainActor
    func volumeBrowserStoreKeepsCreateDirectoryStatusAfterRefresh() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let volume = VolumeSummary(configuration: .init(
            name: "host-volume",
            driver: "local",
            format: "directory",
            source: root.path,
            creationDate: Date(),
            labels: [:],
            options: [:],
            sizeInBytes: nil
        ))
        let store = VolumeBrowserStore()

        await store.load(volume: volume)
        await store.createDirectory(volume: volume, name: "data")

        #expect(store.isError == false)
        #expect(store.statusMessage?.contains("data") == true)
        #expect(store.snapshot?.entries.contains { $0.name == "data" && $0.isDirectory } == true)
    }

    @Test("volume browser store refreshes container backed snapshot after create directory")
    @MainActor
    func volumeBrowserStoreRefreshesContainerBackedSnapshotAfterCreateDirectory() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        let countFile = root.appending(path: "count.txt")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        interactive=0
        for arg in "$@"; do
          if [ "$arg" = "-i" ]; then interactive=1; fi
        done
        if [ "$interactive" != "1" ]; then
          exit 0
        fi
        cat >/dev/null
        count=0
        if [ -f "\(countFile.path)" ]; then
          count="$(cat "\(countFile.path)")"
        fi
        count=$((count + 1))
        printf '%s' "$count" > "\(countFile.path)"
        if [ "$count" = "1" ]; then
          printf '目录 data 已创建。\\n'
          exit 0
        fi
        printf '[0/6] [0s]\\n'
        printf 'd\\t\\t1781233548\\tdata\\n'
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)
        let volume = VolumeSummary(configuration: .init(
            name: "container-volume",
            driver: "local",
            format: "ext4",
            source: imageFile.path,
            creationDate: Date(),
            labels: [:],
            options: [:],
            sizeInBytes: nil
        ))
        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        let store = VolumeBrowserStore(service: service)

        await store.createDirectory(volume: volume, name: "data")

        #expect(store.isError == false)
        #expect(store.statusMessage?.contains("目录 data 已创建。") == true)
        #expect(store.snapshot?.isHostBacked == false)
        #expect(store.snapshot?.entries.contains { $0.name == "data" && $0.isDirectory } == true)
    }

    @Test("creates container backed volume directory through transient container command")
    func createsContainerBackedVolumeDirectoryThroughTransientContainerCommand() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        let argumentsLog = root.appending(path: "arguments.log")
        let standardInputLog = root.appending(path: "stdin.log")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        interactive=0
        for arg in "$@"; do
          if [ "$arg" = "-i" ]; then interactive=1; fi
        done
        if [ "$interactive" != "1" ]; then
          exit 0
        fi
        for arg in "$@"; do
          printf '%s\\n' "$arg"
        done > "\(argumentsLog.path)"
        cat > "\(standardInputLog.path)"
        last=""
        for arg in "$@"; do last="$arg"; done
        printf '目录 %s 已创建。\\n' "$last"
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)

        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        let output = try await service.createDirectory(
            volumeName: "demo-volume",
            sourcePath: imageFile.path,
            relativePath: "config",
            name: "new-folder"
        )

        let arguments = try String(contentsOf: argumentsLog, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        let standardInput = try String(contentsOf: standardInputLog, encoding: .utf8)
        #expect(output.contains("new-folder"))
        #expect(arguments == [
            "run",
            "--rm",
            "-i",
            "-v",
            "demo-volume:/mnt",
            "docker.io/library/alpine:3.22",
            "sh",
            "-s",
            "--",
            "config",
            "new-folder",
        ])
        #expect(standardInput.contains("rel=\"$1\""))
        #expect(standardInput.contains("mkdir \"$target\""))
        #expect(standardInput.contains("父目录不存在"))
        #expect(standardInput.contains("目标名称已存在"))
    }

    @Test("container backed create directory reports known failures")
    func containerBackedCreateDirectoryReportsKnownFailures() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        last=""
        previous=""
        for arg in "$@"; do
          previous="$last"
          last="$arg"
        done
        if [ "$last" = "existing" ]; then
          printf '目标名称已存在：/mnt/%s/%s\\n' "$previous" "$last" >&2
          exit 73
        fi
        printf '父目录不存在：/mnt/%s\\n' "$previous" >&2
        exit 66
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)

        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        var missingParentMessage = ""
        do {
            _ = try await service.createDirectory(
                volumeName: "demo-volume",
                sourcePath: imageFile.path,
                relativePath: "missing",
                name: "child"
            )
        } catch {
            missingParentMessage = error.localizedDescription
        }

        var existingTargetMessage = ""
        do {
            _ = try await service.createDirectory(
                volumeName: "demo-volume",
                sourcePath: imageFile.path,
                relativePath: "config",
                name: "existing"
            )
        } catch {
            existingTargetMessage = error.localizedDescription
        }

        #expect(missingParentMessage.contains("父目录不存在：/mnt/missing"))
        #expect(missingParentMessage.contains("退出码 66"))
        #expect(existingTargetMessage.contains("目标名称已存在：/mnt/config/existing"))
        #expect(existingTargetMessage.contains("退出码 73"))
    }

    @Test("transient container command failures preserve CLI output")
    func transientContainerCommandFailuresPreserveCLIOutput() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        printf 'pulling docker.io/library/alpine:3.22\\n'
        printf 'network unavailable while preparing transient container\\n' >&2
        exit 125
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)

        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        var message = ""
        do {
            _ = try await service.createDirectory(
                volumeName: "demo-volume",
                sourcePath: imageFile.path,
                relativePath: "",
                name: "data"
            )
        } catch {
            message = error.localizedDescription
        }

        #expect(message.contains("pulling docker.io/library/alpine:3.22"))
        #expect(message.contains("network unavailable while preparing transient container"))
        #expect(message.contains("退出码 125"))
    }

    @Test("volume browser store reports refresh failure after create success")
    @MainActor
    func volumeBrowserStoreReportsRefreshFailureAfterCreateSuccess() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fakeContainer = root.appending(path: "container")
        let imageFile = root.appending(path: "volume.img")
        let countFile = root.appending(path: "count.txt")
        try Data().write(to: imageFile)
        try """
        #!/bin/sh
        count=0
        if [ -f "\(countFile.path)" ]; then
          count="$(cat "\(countFile.path)")"
        fi
        count=$((count + 1))
        printf '%s' "$count" > "\(countFile.path)"
        if [ "$count" = "1" ]; then
          printf '目录 data 已创建。\\n'
          exit 0
        fi
        printf '目录不存在：/mnt\\n' >&2
        exit 66
        """.write(to: fakeContainer, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeContainer.path)

        let volume = VolumeSummary(configuration: .init(
            name: "container-volume",
            driver: "local",
            format: "ext4",
            source: imageFile.path,
            creationDate: Date(),
            labels: [:],
            options: [:],
            sizeInBytes: nil
        ))
        let service = VolumeBrowserService(runner: CommandRunner(searchRoots: [root]))
        let store = VolumeBrowserStore(service: service)

        await store.createDirectory(volume: volume, name: "data")

        #expect(store.isError)
        #expect(store.statusMessage?.contains("目录 data 已创建。") == true)
        #expect(store.statusMessage?.contains("创建成功，但刷新目录失败") == true)
        #expect(store.statusMessage?.contains("目录不存在：/mnt") == true)
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
