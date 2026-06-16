import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Container stats history store")
struct ContainerStatsHistoryStoreTests {
    @Test("loads cached samples and prunes expired entries")
    @MainActor
    func loadsCachedSamplesAndPrunesExpiredEntries() throws {
        let directory = try Self.makeTemporaryDirectory()
        let persistenceURL = directory.appending(path: "stats.json")
        let now = Date(timeIntervalSince1970: 100_000)
        let oldSample = ContainerStatsSample.make(
            snapshot: Self.makeSnapshot(id: "c1", cpuUsageUsec: 10),
            date: now.addingTimeInterval(-90_000)
        )
        let freshSample = ContainerStatsSample.make(
            snapshot: Self.makeSnapshot(id: "c1", cpuUsageUsec: 20),
            date: now.addingTimeInterval(-3_600),
            previous: oldSample
        )
        let expiredOnlySample = ContainerStatsSample.make(
            snapshot: Self.makeSnapshot(id: "expired", cpuUsageUsec: 30),
            date: now.addingTimeInterval(-90_000)
        )
        let payload = ContainerStatsHistoryPayload(
            version: ContainerStatsHistoryPayload.currentVersion,
            savedAt: now.addingTimeInterval(-10),
            samplesByContainerID: [
                "c1": [oldSample, freshSample],
                "expired": [expiredOnlySample],
            ]
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder.containerDesktop.encode(payload).write(to: persistenceURL, options: [.atomic])

        let store = ContainerStatsHistoryStore(
            persistenceURL: persistenceURL,
            dateProvider: { now },
            statsLoader: { _ in [] }
        )

        store.load()

        #expect(store.samples(for: "c1") == [freshSample])
        #expect(store.samples(for: "expired").isEmpty)

        let persisted = try JSONDecoder.containerDesktop.decode(
            ContainerStatsHistoryPayload.self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(persisted.samplesByContainerID["c1"] == [freshSample])
        #expect(persisted.samplesByContainerID["expired"] == nil)
    }

    @Test("appends samples computes CPU and persists forced refresh")
    @MainActor
    func appendsSamplesComputesCPUAndPersistsForcedRefresh() async throws {
        let directory = try Self.makeTemporaryDirectory()
        let persistenceURL = directory.appending(path: "stats.json")
        let loader = StatsHistoryLoader()
        let store = ContainerStatsHistoryStore(
            persistenceURL: persistenceURL,
            dateProvider: { loader.now },
            statsLoader: { ids in
                await loader.load(ids: ids)
            }
        )

        loader.now = Date(timeIntervalSince1970: 10)
        loader.snapshots = [Self.makeSnapshot(id: "c1", cpuUsageUsec: 1_000_000)]
        await store.sampleNow(containerIDs: [" c1 "], forcePersist: true)

        loader.now = Date(timeIntervalSince1970: 20)
        loader.snapshots = [Self.makeSnapshot(id: "c1", cpuUsageUsec: 2_000_000)]
        await store.sampleNow(containerIDs: ["c1"], forcePersist: true)

        let samples = store.samples(for: "c1")
        #expect(loader.requestedIDs == [["c1"], ["c1"]])
        #expect(samples.count == 2)
        #expect(samples[0].cpuPercent == 0)
        #expect(samples[1].cpuPercent == 10)

        let persisted = try JSONDecoder.containerDesktop.decode(
            ContainerStatsHistoryPayload.self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(persisted.samplesByContainerID["c1"]?.count == 2)
        #expect(persisted.savedAt == loader.now)
    }

    @Test("throttles background persistence and shutdown forces pending save")
    @MainActor
    func throttlesBackgroundPersistenceAndShutdownForcesPendingSave() async throws {
        let directory = try Self.makeTemporaryDirectory()
        let persistenceURL = directory.appending(path: "stats.json")
        let loader = StatsHistoryLoader()
        let store = ContainerStatsHistoryStore(
            persistenceURL: persistenceURL,
            persistInterval: 60,
            dateProvider: { loader.now },
            statsLoader: { _ in
                await loader.load(ids: [])
            }
        )

        loader.now = Date(timeIntervalSince1970: 10)
        loader.snapshots = [Self.makeSnapshot(id: "c1", cpuUsageUsec: 1_000_000)]
        await store.sampleNow(forcePersist: false)

        var persisted = try JSONDecoder.containerDesktop.decode(
            ContainerStatsHistoryPayload.self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(persisted.savedAt == Date(timeIntervalSince1970: 10))
        #expect(persisted.samplesByContainerID["c1"]?.count == 1)

        loader.now = Date(timeIntervalSince1970: 20)
        loader.snapshots = [Self.makeSnapshot(id: "c1", cpuUsageUsec: 2_000_000)]
        await store.sampleNow(forcePersist: false)

        persisted = try JSONDecoder.containerDesktop.decode(
            ContainerStatsHistoryPayload.self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(persisted.savedAt == Date(timeIntervalSince1970: 10))
        #expect(persisted.samplesByContainerID["c1"]?.count == 1)

        store.shutdown()

        persisted = try JSONDecoder.containerDesktop.decode(
            ContainerStatsHistoryPayload.self,
            from: Data(contentsOf: persistenceURL)
        )
        #expect(persisted.savedAt == Date(timeIntervalSince1970: 20))
        #expect(persisted.samplesByContainerID["c1"]?.count == 2)
    }

    private static func makeSnapshot(
        id: String,
        blockReadBytes: Int64 = 0,
        blockWriteBytes: Int64 = 0,
        cpuUsageUsec: Int64 = 0,
        memoryLimitBytes: Int64 = 1_073_741_824,
        memoryUsageBytes: Int64 = 0,
        networkRxBytes: Int64 = 0,
        networkTxBytes: Int64 = 0,
        numProcesses: Int = 1
    ) -> ContainerStatsSnapshot {
        ContainerStatsSnapshot(
            id: id,
            blockReadBytes: blockReadBytes,
            blockWriteBytes: blockWriteBytes,
            cpuUsageUsec: cpuUsageUsec,
            memoryLimitBytes: memoryLimitBytes,
            memoryUsageBytes: memoryUsageBytes,
            networkRxBytes: networkRxBytes,
            networkTxBytes: networkTxBytes,
            numProcesses: numProcesses
        )
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
private final class StatsHistoryLoader {
    var now = Date(timeIntervalSince1970: 0)
    var snapshots: [ContainerStatsSnapshot] = []
    var requestedIDs: [[String]] = []

    func load(ids: [String]) async -> [ContainerStatsSnapshot] {
        requestedIDs.append(ids)
        return snapshots
    }
}
