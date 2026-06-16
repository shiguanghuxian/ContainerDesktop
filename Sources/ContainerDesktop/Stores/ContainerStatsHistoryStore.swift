import Foundation
import Observation

struct ContainerStatsHistoryPayload: Codable, Hashable, Sendable {
    static let currentVersion = 1

    var version: Int
    var savedAt: Date
    var samplesByContainerID: [String: [ContainerStatsSample]]
}

@MainActor
@Observable
final class ContainerStatsHistoryStore {
    typealias StatsLoader = ([String]) async throws -> [ContainerStatsSnapshot]
    typealias DateProvider = () -> Date

    private let persistenceURL: URL
    private let retentionInterval: TimeInterval
    private let persistInterval: TimeInterval
    private let dateProvider: DateProvider
    private let statsLoader: StatsLoader

    var samplesByContainerID: [String: [ContainerStatsSample]] = [:]
    var errorMessage: String?
    var isMonitoring = false
    var isSampling = false
    var lastSampledAt: Date?
    var lastSavedAt: Date?

    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var hasPendingPersistence = false

    init(
        client: ContainerCLIClient = ContainerCLIClient(),
        persistenceURL: URL = AppPaths.containerStatsHistoryURL,
        retentionInterval: TimeInterval = 24 * 60 * 60,
        persistInterval: TimeInterval = 60,
        dateProvider: @escaping DateProvider = Date.init,
        statsLoader: StatsLoader? = nil
    ) {
        self.persistenceURL = persistenceURL
        self.retentionInterval = retentionInterval
        self.persistInterval = persistInterval
        self.dateProvider = dateProvider
        self.statsLoader = statsLoader ?? { ids in
            try await client.containerStats(ids)
        }
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: persistenceURL)
            let payload = try JSONDecoder.containerDesktop.decode(ContainerStatsHistoryPayload.self, from: data)
            samplesByContainerID = payload.samplesByContainerID.mapValues {
                $0.sorted { $0.date < $1.date }
            }
            lastSavedAt = payload.savedAt

            if pruneExpired(referenceDate: dateProvider()) {
                persistIfNeeded(force: true, referenceDate: dateProvider())
            }
            errorMessage = nil
        } catch {
            samplesByContainerID = [:]
            errorMessage = error.localizedDescription
        }
    }

    func startMonitoring(interval: TimeInterval = 10) {
        load()
        guard !isMonitoring else { return }

        isMonitoring = true
        monitorTask = Task { [weak self] in
            await self?.sampleNow(forcePersist: false)

            while !Task.isCancelled {
                let seconds = max(interval, 1)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.sampleNow(forcePersist: false)
            }

            await MainActor.run {
                self?.isMonitoring = false
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    func shutdown() {
        stopMonitoring()
        persistIfNeeded(force: true, referenceDate: dateProvider())
    }

    func samples(for containerID: String) -> [ContainerStatsSample] {
        let key = containerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return samplesByContainerID[key, default: []].sorted { $0.date < $1.date }
    }

    func latestSample(for containerID: String) -> ContainerStatsSample? {
        samples(for: containerID).last
    }

    @discardableResult
    func sampleNow(containerIDs: [String] = [], forcePersist: Bool = true) async -> Bool {
        load()
        guard !isSampling else { return false }

        isSampling = true
        defer { isSampling = false }

        let date = dateProvider()
        _ = pruneExpired(referenceDate: date)

        do {
            let snapshots = try await statsLoader(Self.normalizedContainerIDs(containerIDs))
            append(snapshots: snapshots, date: date)
            lastSampledAt = date
            errorMessage = nil
            persistIfNeeded(force: forcePersist, referenceDate: date)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    private func append(snapshots: [ContainerStatsSnapshot], date: Date) -> Bool {
        guard !snapshots.isEmpty else { return false }

        var didChange = false
        for snapshot in snapshots {
            let previous = samplesByContainerID[snapshot.id]?.last
            let sample = ContainerStatsSample.make(snapshot: snapshot, date: date, previous: previous)
            samplesByContainerID[snapshot.id, default: []].append(sample)
            didChange = true
        }

        if didChange {
            _ = pruneExpired(referenceDate: date)
            hasPendingPersistence = true
        }
        return didChange
    }

    @discardableResult
    private func pruneExpired(referenceDate: Date) -> Bool {
        let cutoff = referenceDate.addingTimeInterval(-retentionInterval)
        var pruned: [String: [ContainerStatsSample]] = [:]
        var didChange = false

        for (containerID, samples) in samplesByContainerID {
            let retained = samples
                .filter { $0.date >= cutoff }
                .sorted { $0.date < $1.date }
            if retained.count != samples.count {
                didChange = true
            }
            if !retained.isEmpty {
                pruned[containerID] = retained
            } else {
                didChange = true
            }
        }

        if didChange {
            samplesByContainerID = pruned
            hasPendingPersistence = true
        }

        return didChange
    }

    private func persistIfNeeded(force: Bool, referenceDate: Date) {
        guard force || hasPendingPersistence else { return }
        if !force, let lastSavedAt, referenceDate.timeIntervalSince(lastSavedAt) < persistInterval {
            return
        }
        persist(referenceDate: referenceDate)
    }

    private func persist(referenceDate: Date) {
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let payload = ContainerStatsHistoryPayload(
                version: ContainerStatsHistoryPayload.currentVersion,
                savedAt: referenceDate,
                samplesByContainerID: samplesByContainerID
            )
            let data = try JSONEncoder.containerDesktop.encode(payload)
            try data.write(to: persistenceURL, options: [.atomic])
            lastSavedAt = referenceDate
            hasPendingPersistence = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func normalizedContainerIDs(_ containerIDs: [String]) -> [String] {
        containerIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    deinit {
        monitorTask?.cancel()
    }
}
