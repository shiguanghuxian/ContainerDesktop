import Foundation
import Observation

@MainActor
@Observable
final class AppOperationStore {
    private let persistenceURL: URL
    private let maxRecords: Int

    var records: [AppOperationRecord] = []
    var errorMessage: String?
    var hasLoaded = false

    init(
        persistenceURL: URL = AppPaths.operationHistoryURL,
        maxRecords: Int = 80
    ) {
        self.persistenceURL = persistenceURL
        self.maxRecords = maxRecords
    }

    var activeCount: Int {
        records.filter { $0.status == .running }.count
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }

        do {
            let data = try Data(contentsOf: persistenceURL)
            records = try JSONDecoder.containerDesktop.decode([AppOperationRecord].self, from: data)
                .prefix(maxRecords)
                .map { $0 }
        } catch {
            errorMessage = error.localizedDescription
            records = []
        }
    }

    @discardableResult
    func start(
        domain: AppOperationDomain,
        title: String,
        target: String,
        commandPreview: String
    ) -> UUID {
        let id = UUID()
        let record = AppOperationRecord(
            id: id,
            domain: domain,
            title: title,
            target: target,
            commandPreview: commandPreview,
            status: .running,
            output: "",
            startedAt: Date(),
            finishedAt: nil
        )
        records.insert(record, at: 0)
        trim()
        persist()
        return id
    }

    func finish(id: UUID, status: AppOperationStatus, output: String) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].status = status
        records[index].output = limitedOutput(output)
        records[index].finishedAt = Date()
        persist()
    }

    func recent(domains: Set<AppOperationDomain>, limit: Int = 6) -> [AppOperationRecord] {
        records
            .filter { domains.contains($0.domain) }
            .prefix(limit)
            .map { $0 }
    }

    func clearFinished(domains: Set<AppOperationDomain>) {
        records.removeAll { domains.contains($0.domain) && $0.status.isFinished }
        persist()
    }

    private func trim() {
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.containerDesktop.encode(records)
            try data.write(to: persistenceURL, options: [.atomic])
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func limitedOutput(_ output: String) -> String {
        let maxCharacters = 40_000
        guard output.count > maxCharacters else { return output }
        return String(output.suffix(maxCharacters))
    }
}
