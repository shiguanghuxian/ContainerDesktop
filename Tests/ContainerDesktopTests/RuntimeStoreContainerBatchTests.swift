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

    @MainActor
    @Test("local machine template validates before create")
    func customLocalMachineTemplateValidatesBeforeCreate() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let succeeded = await store.createMachine(
            name: "ubuntu",
            image: "local/ubuntu-machine:latest",
            cpus: nil,
            memory: nil,
            homeMount: nil,
            setDefault: false,
            noBoot: false
        )

        #expect(!succeeded)
        #expect(store.errorMessage?.contains("/sbin/init") == true)
        let log = try fake.commandLog()
        #expect(log.contains("run --rm --entrypoint /bin/sh local/ubuntu-machine:latest -lc test -x /sbin/init"))
        #expect(!log.contains("build -t local/ubuntu-machine:latest"))
        #expect(!log.contains("machine create --name ubuntu local/ubuntu-machine:latest"))
    }

    @MainActor
    @Test("local machine preset builds then validates before create")
    func localMachinePresetBuildsThenValidatesBeforeCreate() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        let recipe = try #require(FormPresetOptions.machineImagePreset(reference: "local/ubuntu-machine:latest")?.buildRecipe)

        let succeeded = await store.createMachine(
            name: "ubuntu",
            image: "local/ubuntu-machine:latest",
            cpus: nil,
            memory: nil,
            homeMount: nil,
            buildRecipe: recipe,
            setDefault: false,
            noBoot: false
        )

        #expect(succeeded)
        let lines = try fake.commandLog().split(separator: "\n").map(String.init)
        #expect(lines.first?.hasPrefix("build -t local/ubuntu-machine:latest ") == true)
        #expect(lines.dropFirst().first == "run --rm --entrypoint /bin/sh local/ubuntu-machine:latest -lc test -x /sbin/init")
        #expect(lines.contains("machine create --name ubuntu local/ubuntu-machine:latest"))
    }

    @MainActor
    @Test("local machine preset build failure stops before validation")
    func localMachinePresetBuildFailureStopsBeforeValidation() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        let recipe = try #require(FormPresetOptions.machineImagePreset(reference: "local/debian-machine:latest")?.buildRecipe)

        let succeeded = await store.createMachine(
            name: "debian",
            image: "local/debian-machine:latest",
            cpus: nil,
            memory: nil,
            homeMount: nil,
            buildRecipe: recipe,
            setDefault: false,
            noBoot: false
        )

        #expect(!succeeded)
        #expect(store.errorMessage?.contains("构建失败") == true)
        let log = try fake.commandLog()
        #expect(log.contains("build -t local/debian-machine:latest "))
        #expect(!log.contains("run --rm --entrypoint /bin/sh local/debian-machine:latest -lc test -x /sbin/init"))
        #expect(!log.contains("machine create --name debian local/debian-machine:latest"))
    }

    @MainActor
    @Test("updates machine config without rebooting")
    func updatesMachineConfigWithoutRebooting() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "dev", status: "running")]

        let succeeded = await store.updateMachineConfig(
            id: "dev",
            update: MachineConfigurationUpdate(cpus: 6, memory: "8G", homeMount: .ro)
        )

        #expect(succeeded)
        let log = try fake.commandLog()
        #expect(log.contains("machine set -n dev cpus=6 memory=8G home-mount=ro"))
        #expect(!log.contains("machine stop dev"))
        #expect(!log.contains("machine run -n dev -- true"))
    }

    @MainActor
    @Test("updates running machine config then restarts")
    func updatesRunningMachineConfigThenRestarts() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "dev", status: "running")]

        let succeeded = await store.updateMachineConfig(
            id: "dev",
            update: MachineConfigurationUpdate(cpus: 6, memory: "8G", homeMount: .ro),
            restartIfRunning: true
        )

        #expect(succeeded)
        let lines = try fake.commandLog().split(separator: "\n").map(String.init)
        #expect(lines.prefix(3).elementsEqual([
            "machine set -n dev cpus=6 memory=8G home-mount=ro",
            "machine stop dev",
            "machine run -n dev -- true",
        ]))
    }

    @MainActor
    @Test("updates stopped machine config without starting")
    func updatesStoppedMachineConfigWithoutStarting() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "stopped-dev", status: "stopped")]

        let succeeded = await store.updateMachineConfig(
            id: "stopped-dev",
            update: MachineConfigurationUpdate(cpus: 2, memory: "4G", homeMount: .none),
            restartIfRunning: true
        )

        #expect(succeeded)
        let log = try fake.commandLog()
        #expect(log.contains("machine set -n stopped-dev cpus=2 memory=4G home-mount=none"))
        #expect(!log.contains("machine stop stopped-dev"))
        #expect(!log.contains("machine run -n stopped-dev -- true"))
    }

    @MainActor
    @Test("machine config set failure skips restart")
    func machineConfigSetFailureSkipsRestart() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "fail-set", status: "running")]

        let succeeded = await store.updateMachineConfig(
            id: "fail-set",
            update: MachineConfigurationUpdate(cpus: 6, memory: "8G", homeMount: .ro),
            restartIfRunning: true
        )

        #expect(!succeeded)
        let log = try fake.commandLog()
        #expect(log.contains("machine set -n fail-set cpus=6 memory=8G home-mount=ro"))
        #expect(!log.contains("machine stop fail-set"))
        #expect(!log.contains("machine run -n fail-set -- true"))
    }

    @MainActor
    @Test("machine config restart failure reports saved configuration")
    func machineConfigRestartFailureReportsSavedConfiguration() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "fail-boot", status: "running")]

        let succeeded = await store.updateMachineConfig(
            id: "fail-boot",
            update: MachineConfigurationUpdate(cpus: 6, memory: "8G", homeMount: .ro),
            restartIfRunning: true
        )

        #expect(!succeeded)
        #expect(store.errorMessage?.contains("配置已保存，但自动重启失败") == true)
        let lines = try fake.commandLog().split(separator: "\n").map(String.init)
        #expect(lines.contains("machine set -n fail-boot cpus=6 memory=8G home-mount=ro"))
        #expect(lines.contains("machine stop fail-boot"))
        #expect(lines.contains("machine run -n fail-boot -- true"))
    }

    @MainActor
    @Test("machine config stop failure reports saved configuration")
    func machineConfigStopFailureReportsSavedConfiguration() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        store.machines = [machineSummary(id: "fail-stop", status: "running")]

        let succeeded = await store.updateMachineConfig(
            id: "fail-stop",
            update: MachineConfigurationUpdate(cpus: 6, memory: "8G", homeMount: .ro),
            restartIfRunning: true
        )

        #expect(!succeeded)
        #expect(store.errorMessage?.contains("配置已保存，但自动重启失败") == true)
        let log = try fake.commandLog()
        #expect(log.contains("machine set -n fail-stop cpus=6 memory=8G home-mount=ro"))
        #expect(log.contains("machine stop fail-stop"))
        #expect(!log.contains("machine run -n fail-stop -- true"))
    }

    private func machineSummary(id: String, status: String) -> MachineSummary {
        MachineSummary(
            id: id,
            status: status,
            isDefault: false,
            ipAddress: nil,
            cpus: 4,
            memory: 2_147_483_648,
            diskSize: nil,
            createdDate: nil
        )
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
        ubuntu_built="\(directory.appending(path: "ubuntu-built").path)"
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
          "run --rm --entrypoint /bin/sh local/ubuntu-machine:latest -lc test -x /sbin/init")
            if [ -f "$ubuntu_built" ]; then
              echo "ok"
            else
              echo "image not found: local/ubuntu-machine:latest" >&2
              exit 66
            fi
            ;;
          build\\ -t\\ local/ubuntu-machine:latest\\ *)
            touch "$ubuntu_built"
            echo "built ubuntu"
            ;;
          build\\ -t\\ local/debian-machine:latest\\ *)
            echo "apt source unavailable" >&2
            exit 72
            ;;
          "machine create --name dev alpine:3.22")
            echo "created"
            ;;
          "machine create --name ubuntu local/ubuntu-machine:latest")
            echo "created ubuntu"
            ;;
          "machine set -n dev cpus=6 memory=8G home-mount=ro")
            echo "updated"
            ;;
          "machine set -n stopped-dev cpus=2 memory=4G home-mount=none")
            echo "updated stopped"
            ;;
          "machine set -n fail-set cpus=6 memory=8G home-mount=ro")
            echo "set failed" >&2
            exit 71
            ;;
          "machine set -n fail-boot cpus=6 memory=8G home-mount=ro")
            echo "updated before boot failure"
            ;;
          "machine set -n fail-stop cpus=6 memory=8G home-mount=ro")
            echo "updated before stop failure"
            ;;
          "machine stop dev"|"machine stop fail-boot")
            echo "stopped"
            ;;
          "machine stop fail-stop")
            echo "stop failed" >&2
            exit 72
            ;;
          "machine run -n dev -- true")
            echo "booted"
            ;;
          "machine run -n fail-boot -- true")
            echo "boot failed" >&2
            exit 73
            ;;
          "machine logs -n 80 fail-boot")
            echo "failed to boot after config update"
            ;;
          "machine logs -n 80 fail-stop")
            echo "failed to stop after config update"
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
