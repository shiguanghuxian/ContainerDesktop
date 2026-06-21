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
        #expect(store.operationFeedback?.phase == .succeeded)
        #expect(store.operationFeedback?.message == "已启动容器 2 个")

        let log = try fake.commandLog()
        #expect(log.contains("start web-1\n"))
        #expect(log.contains("start api-1\n"))
        #expect(log.split(separator: "\n").filter { $0 == "list --all --format json" }.count == 1)
    }

    @MainActor
    @Test("deletes selected images and refreshes resources once")
    func deletesSelectedImagesAndRefreshesOnce() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let result = await store.deleteImages(["alpine:latest", "", "ubuntu:24.04", "alpine:latest"])

        #expect(result.succeeded)
        #expect(result.deletedReferences == ["alpine:latest", "ubuntu:24.04"])
        #expect(result.output.contains("已删除 2 个镜像"))
        #expect(store.imageOperationStatusIsError == false)
        #expect(store.imageOperationStatusMessage?.contains("已删除 2 个镜像") == true)
        #expect(store.operationFeedback?.phase == .succeeded)
        #expect(store.operationFeedback?.message == "已删除镜像 2 个")

        let log = try fake.commandLog()
        #expect(log.contains("image delete alpine:latest\n"))
        #expect(log.contains("image delete ubuntu:24.04\n"))
        #expect(log.split(separator: "\n").filter { $0 == "image delete alpine:latest" }.count == 1)
        #expect(log.split(separator: "\n").filter { $0 == "image list --format json" }.count == 1)
    }

    @MainActor
    @Test("empty image batch delete does not call CLI")
    func emptyImageBatchDeleteDoesNotCallCLI() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let result = await store.deleteImages(["", "   "])

        #expect(!result.succeeded)
        #expect(result.deletedReferences.isEmpty)
        #expect(result.output == "请选择要删除的镜像。")
        #expect(store.imageOperationStatusIsError)
        #expect(store.operationFeedback?.phase == .failed)
        #expect((try? fake.commandLog()) == nil)
    }

    @MainActor
    @Test("image batch delete reports partial failures")
    func imageBatchDeleteReportsPartialFailures() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        let result = await store.deleteImages(["alpine:latest", "missing:latest", "busybox:latest"])

        #expect(!result.succeeded)
        #expect(result.deletedReferences == ["alpine:latest", "busybox:latest"])
        #expect(result.output.contains("部分镜像删除失败"))
        #expect(result.output.contains("missing:latest"))
        #expect(result.output.contains("image is used by a container"))
        #expect(store.imageOperationStatusIsError)
        #expect(store.errorMessage?.contains("missing:latest") == true)
        #expect(store.operationFeedback?.phase == .failed)

        let log = try fake.commandLog()
        #expect(log.contains("image delete alpine:latest\n"))
        #expect(log.contains("image delete missing:latest\n"))
        #expect(log.contains("image delete busybox:latest\n"))
        #expect(log.split(separator: "\n").filter { $0 == "image list --format json" }.count == 1)
    }

    @MainActor
    @Test("operation feedback reports running and success states")
    func operationFeedbackReportsRunningAndSuccessStates() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        async let operation: Void = store.startContainer("slow-container")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.operationFeedback?.phase == .running)
        #expect(store.operationFeedback?.message == "正在启动容器 slow-container")

        await operation

        #expect(store.operationFeedback?.phase == .succeeded)
        #expect(store.operationFeedback?.message == "已启动容器 slow-container")
    }

    @MainActor
    @Test("creates network with advanced options and refreshes resources")
    func createsNetworkWithAdvancedOptionsAndRefreshesResources() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.createNetwork(options: NetworkCreateOptions(
            name: " app-net ",
            internalOnly: true,
            plugin: "container-network-vmnet",
            subnet: "192.168.100.0/24",
            subnetV6: "fd00:100::/64",
            labels: ["app=web", "tier=edge"],
            options: ["mtu=1500"]
        ))

        #expect(store.busyMessage == nil)
        #expect(store.errorMessage == nil)
        #expect(store.operationFeedback?.phase == .succeeded)
        #expect(store.operationFeedback?.message == "已创建网络 app-net")

        let log = try fake.commandLog()
        #expect(log.contains("network create --internal --label app=web --label tier=edge --option mtu=1500 --plugin container-network-vmnet --subnet 192.168.100.0/24 --subnet-v6 fd00:100::/64 app-net\n"))
        #expect(log.split(separator: "\n").filter { $0 == "network list --format json" }.count == 1)
    }

    @MainActor
    @Test("loads caches and clears browser port targets")
    func loadsCachesAndClearsBrowserPortTargets() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))
        let container = ContainerSummary(
            configuration: .init(
                id: "web-ports",
                image: .init(reference: "nginx:latest"),
                platform: .init(os: "linux", architecture: "arm64"),
                resources: .init(cpus: 1, memoryInBytes: 1_073_741_824),
                creationDate: nil,
                labels: [:]
            ),
            status: .init(
                state: "running",
                networks: [.init(ipv4Address: "192.168.64.2")],
                startedDate: nil
            )
        )

        await store.loadBrowserPortTargets(for: container)
        await store.loadBrowserPortTargets(for: container)

        #expect(store.browserPortTargets(for: container).map(\.url.absoluteString) == [
            "http://127.0.0.1:8080",
            "http://192.168.64.2:80",
        ])
        #expect(try fake.commandLog().split(separator: "\n").filter { $0 == "inspect web-ports" }.count == 1)

        await store.refreshAll()

        #expect(store.browserPortTargets(for: container).isEmpty)

        await store.loadBrowserPortTargets(for: container)
        await store.startContainer("web-ports")

        #expect(store.browserPortTargets(for: container).isEmpty)
    }

    @MainActor
    @Test("operation feedback reports failures and can dismiss")
    func operationFeedbackReportsFailuresAndDismisses() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.startContainer("missing-container")

        #expect(store.operationFeedback?.phase == .failed)
        #expect(store.operationFeedback?.message == "启动容器 missing-container失败")
        #expect(store.errorMessage?.contains("unexpected command") == true)

        store.dismissOperationFeedback()

        #expect(store.operationFeedback == nil)
    }

    @MainActor
    @Test("operation feedback replaces previous finished state")
    func operationFeedbackReplacesPreviousFinishedState() async throws {
        let fake = try FakeBatchContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.startContainer("web-1")
        let firstID = store.operationFeedback?.id

        await store.stopContainer("api-1")

        #expect(store.operationFeedback?.id != firstID)
        #expect(store.operationFeedback?.phase == .succeeded)
        #expect(store.operationFeedback?.message == "已停止容器 api-1")
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
          "start web-ports")
            echo "started"
            ;;
          "start slow-container")
            sleep 0.2
            echo "slow ok"
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
          "image delete alpine:latest"|"image delete ubuntu:24.04"|"image delete busybox:latest")
            echo "deleted"
            ;;
          "image delete missing:latest")
            echo "image is used by a container" >&2
            exit 74
            ;;
          "network create --internal --label app=web --label tier=edge --option mtu=1500 --plugin container-network-vmnet --subnet 192.168.100.0/24 --subnet-v6 fd00:100::/64 app-net")
            echo "network created"
            ;;
          "inspect web-ports")
            cat <<'JSON'
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" }
            ]
          }
        }
        JSON
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
