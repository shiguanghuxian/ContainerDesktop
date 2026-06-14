import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Runtime store container batches")
struct RuntimeStoreContainerBatchTests {
    @MainActor
    @Test("starts containers and refreshes resources once")
    func startsContainersAndRefreshesOnce() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let result = await store.startContainers(["web-1", "", "api-1"])

        #expect(result.succeeded)
        #expect(result.output.contains("web-1"))
        #expect(result.output.contains("api-1"))
        #expect(store.busyMessage == nil)

        let log = try fake.commandLog()
        #expect(log.contains("start web-1\n"))
        #expect(log.contains("start api-1\n"))
        #expect(log.split(separator: "\n").filter { $0 == "list --all --format json" }.count == 1)
    }

    @MainActor
    @Test("diagnoses machine images that cannot boot without init")
    func diagnosesMachineMissingInit() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.bootMachine("bad-machine")

        #expect(store.errorMessage?.contains("/sbin/init") == true)
        #expect(store.errorMessage?.contains("重新创建") == true)
        #expect(store.activeOperationKey == nil)
    }

    @MainActor
    @Test("validates machine image before create")
    func validatesMachineImageBeforeCreate() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let succeeded = await store.createMachine(
            name: "dev",
            image: "alpine:3.22",
            cpus: nil,
            memory: nil,
            homeMount: nil,
            setDefault: false,
            noBoot: false
        )

        #expect(succeeded)
        let lines = try fake.commandLog().split(separator: "\n").map(String.init)
        #expect(lines.first == "run --rm --entrypoint /bin/sh alpine:3.22 -lc test -x /sbin/init")
        #expect(lines.dropFirst().contains("machine create --name dev alpine:3.22"))
    }

    @MainActor
    @Test("rejects unsupported machine image before create")
    func rejectsUnsupportedMachineImageBeforeCreate() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let succeeded = await store.createMachine(
            name: "web",
            image: "nginx:latest",
            cpus: nil,
            memory: nil,
            homeMount: nil,
            setDefault: false,
            noBoot: false
        )

        #expect(!succeeded)
        #expect(store.errorMessage?.contains("/sbin/init") == true)
        let log = try fake.commandLog()
        #expect(log.contains("run --rm --entrypoint /bin/sh nginx:latest -lc test -x /sbin/init"))
        #expect(!log.contains("machine create --name web nginx:latest"))
    }
}

private struct FakeBatchContainerCLI {
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
        log="\(logURL.path)"
        printf '%s\\n' "$*" >> "$log"

        case "$*" in
          "start web-1"|"start api-1"|"stop web-1"|"stop api-1")
            echo "ok"
            ;;
          "run --rm --entrypoint /bin/sh alpine:3.22 -lc test -x /sbin/init")
            echo "ok"
            ;;
          "run --rm --entrypoint /bin/sh nginx:latest -lc test -x /sbin/init")
            echo "/sbin/init: not found" >&2
            exit 66
            ;;
          "machine create --name dev alpine:3.22")
            echo "created"
            ;;
          "machine run -n bad-machine -- true")
            echo "Operation not supported by device" >&2
            exit 70
            ;;
          "machine logs -n 80 bad-machine")
            echo "/sbin.machine/init: 74: exec: /sbin/init: not found"
            ;;
          "system status --format json")
            echo '{"status":"running"}'
            ;;
          "system version --format json")
            echo "[]"
            ;;
          "list --all --format json"|"image list --format json"|"volume list --format json"|"network list --format json"|"registry list --format json")
            echo "[]"
            ;;
          "machine list --format json")
            echo '[{"id":"bad-machine","status":"stopped","default":false,"cpus":4,"memory":2147483648}]'
            ;;
          "system property list --format json")
            echo "{}"
            ;;
          "system df --format json")
            cat <<'JSON'
        {
          "containers": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 },
          "images": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 },
          "volumes": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 }
        }
        JSON
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
