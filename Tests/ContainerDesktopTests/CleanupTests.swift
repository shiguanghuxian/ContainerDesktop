import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Cache cleanup")
struct CleanupTests {
    @Test("prune client uses safe commands")
    func pruneClientUsesSafeCommands() async throws {
        let fake = try FakeContainerCLI()
        let client = ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory]))

        _ = try await client.pruneStoppedContainers()
        _ = try await client.pruneDanglingImages()

        let log = try fake.commandLog()
        #expect(log.contains("prune\n"))
        #expect(log.contains("image prune\n"))
        #expect(!log.contains("--all"))
    }

    @Test("cleanup plan estimates selected categories and command preview")
    func cleanupPlanEstimatesSelectedCategoriesAndCommandPreview() {
        let usage = DiskUsageSummary(
            containers: .init(active: 1, reclaimable: 500, sizeInBytes: 700, total: 3),
            images: .init(active: 2, reclaimable: 300, sizeInBytes: 1_300, total: 4),
            volumes: .init(active: 1, reclaimable: 900, sizeInBytes: 1_200, total: 2)
        )
        let plan = SystemCleanupPlan(categories: [.stoppedContainers, .unusedVolumes])

        #expect(SystemCleanupPlan.safeDefault.categories == [.stoppedContainers, .danglingImages])
        #expect(plan.estimatedReclaimableBytes(in: usage) == 1_400)
        #expect(plan.commandPreview == "container prune\ncontainer volume prune")
        #expect(plan.includesVolumes)
        #expect(SystemCleanupCategory.danglingImages.reclaimableBytes(in: usage) == 300)
    }

    @MainActor
    @Test("cleanup refreshes resources after success")
    func cleanupRefreshesResourcesAfterSuccess() async throws {
        let fake = try FakeContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.cleanupCache()

        #expect(!store.isCleanupRunning)
        #expect(!store.cleanupStatusIsError)
        #expect(store.cleanupStatusMessage?.contains("安全清理完成") == true)
        #expect(store.cleanupBeforeDiskUsage?.reclaimableSizeInBytes == 800)
        #expect(store.cleanupAfterDiskUsage?.reclaimableSizeInBytes == 0)
        #expect(store.diskUsage?.totalSizeInBytes == 1_000)
        #expect(store.containers.isEmpty)
        #expect(store.images.isEmpty)

        let log = try fake.commandLog()
        #expect(log.contains("list --all --format json\n"))
        #expect(log.contains("image list --format json\n"))
        #expect(log.contains("system df --format json\n"))
    }

    @MainActor
    @Test("cleanup selected volume category only prunes volumes")
    func cleanupSelectedVolumeCategoryOnlyPrunesVolumes() async throws {
        let fake = try FakeContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.cleanupCache(plan: SystemCleanupPlan(categories: [.unusedVolumes]))

        #expect(!store.isCleanupRunning)
        #expect(!store.cleanupStatusIsError)
        #expect(store.cleanupStatusMessage?.contains("清理完成") == true)

        let log = try fake.commandLog()
        #expect(log.contains("volume prune\n"))
        #expect(!log.contains("prune\nimage prune\n"))
        #expect(log.contains("volume list --format json\n"))
    }

    @MainActor
    @Test("cleanup selected categories require at least one category")
    func cleanupSelectedCategoriesRequireAtLeastOneCategory() async throws {
        let fake = try FakeContainerCLI()
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.cleanupCache(plan: SystemCleanupPlan(categories: []))

        #expect(store.cleanupStatusIsError)
        #expect(store.cleanupStatusMessage == "请选择至少一个要清理的分类。")
        #expect((try? fake.commandLog()) == nil)
    }

    @MainActor
    @Test("cleanup reports failure and refreshes disk status")
    func cleanupReportsFailureAndRefreshesDiskStatus() async throws {
        let fake = try FakeContainerCLI(failImagePrune: true)
        let store = RuntimeStore(client: ContainerCLIClient(runner: CommandRunner(searchRoots: [fake.directory])))

        await store.cleanupCache()

        #expect(!store.isCleanupRunning)
        #expect(store.cleanupStatusIsError)
        #expect(store.cleanupStatusMessage?.contains("安全清理失败") == true)
        #expect(store.errorMessage?.contains("image prune failed") == true)
        #expect(store.diskUsage != nil)

        let diskRefreshCount = try fake.commandLog()
            .split(separator: "\n")
            .filter { $0 == "system df --format json" }
            .count
        #expect(diskRefreshCount >= 2)
    }
}

private struct FakeContainerCLI {
    let directory: URL
    let logURL: URL

    init(failImagePrune: Bool = false) throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        logURL = directory.appending(path: "commands.log")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let executable = directory.appending(path: "container")
        let failImagePruneFlag = failImagePrune ? "1" : "0"
        try """
        #!/usr/bin/env bash
        set -euo pipefail
        log="\(logURL.path)"
        state_dir="\(directory.path)"
        printf '%s\\n' "$*" >> "$log"

        case "$*" in
          "prune")
            touch "$state_dir/pruned-containers"
            echo "stopped containers pruned"
            ;;
          "image prune")
            if [ "\(failImagePruneFlag)" = "1" ]; then
              echo "image prune failed" >&2
              exit 7
            fi
            touch "$state_dir/pruned-images"
            echo "dangling images pruned"
            ;;
          "volume prune")
            touch "$state_dir/pruned-volumes"
            echo "unused volumes pruned"
            ;;
          "list --all --format json")
            echo "[]"
            ;;
          "image list --format json")
            echo "[]"
            ;;
          "volume list --format json")
            echo "[]"
            ;;
          "system df --format json")
            if [ -f "$state_dir/pruned-volumes" ]; then
              cat <<'JSON'
        {
          "containers": { "active": 0, "reclaimable": 500, "sizeInBytes": 500, "total": 1 },
          "images": { "active": 1, "reclaimable": 300, "sizeInBytes": 1300, "total": 2 },
          "volumes": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 }
        }
        JSON
            elif [ -f "$state_dir/pruned-images" ]; then
              cat <<'JSON'
        {
          "containers": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 },
          "images": { "active": 0, "reclaimable": 0, "sizeInBytes": 1000, "total": 1 },
          "volumes": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 }
        }
        JSON
            else
              cat <<'JSON'
        {
          "containers": { "active": 0, "reclaimable": 500, "sizeInBytes": 500, "total": 1 },
          "images": { "active": 1, "reclaimable": 300, "sizeInBytes": 1300, "total": 2 },
          "volumes": { "active": 0, "reclaimable": 0, "sizeInBytes": 0, "total": 0 }
        }
        JSON
            fi
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
