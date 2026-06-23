import Foundation
import Testing
@testable import ContainerDesktop

@Suite("App operation store")
struct AppOperationStoreTests {
    @Test("quotes command previews only when needed")
    func quotesCommandPreview() {
        let preview = AppOperationCommandPreview.make(
            executable: "container",
            arguments: ["image", "save", "-o", "/tmp/app image.tar", "example/app:latest"]
        )

        #expect(preview == "container image save -o '/tmp/app image.tar' example/app:latest")
    }

    @Test("records and finishes operations")
    @MainActor
    func recordsAndFinishesOperations() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = AppOperationStore(persistenceURL: url, maxRecords: 5)
        let id = store.start(
            domain: .image,
            title: "Build image",
            target: "example/app:latest",
            commandPreview: "container build ."
        )
        store.finish(id: id, status: .succeeded, output: "done")

        #expect(store.records.count == 1)
        #expect(store.records.first?.status == .succeeded)
        #expect(store.records.first?.output == "done")
        #expect(store.records.first?.finishedAt != nil)
    }

    @Test("loads persisted history and clears finished records")
    @MainActor
    func loadsAndClearsHistory() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = AppOperationStore(persistenceURL: url, maxRecords: 5)
        let finishedID = store.start(domain: .compose, title: "Compose up", target: "demo", commandPreview: "container-compose up")
        store.finish(id: finishedID, status: .failed, output: "failed")
        _ = store.start(domain: .compose, title: "Compose build", target: "demo", commandPreview: "container-compose build")

        let loaded = AppOperationStore(persistenceURL: url, maxRecords: 5)
        loaded.load()

        #expect(loaded.records.count == 2)
        #expect(loaded.activeCount == 0)
        #expect(loaded.records.first?.status == .failed)
        #expect(loaded.records.first?.finishedAt != nil)
        #expect(loaded.records.first?.output.contains("任务未完成") == true)
        #expect(loaded.records.first?.output.contains("container-compose build") == true)
        loaded.clearFinished(domains: [.compose])
        #expect(loaded.records.isEmpty)
    }

    @Test("preserves finished records when repairing interrupted operations")
    @MainActor
    func preservesFinishedRecordsWhenRepairingInterruptedOperations() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = AppOperationStore(persistenceURL: url, maxRecords: 5)
        let succeededID = store.start(domain: .image, title: "Pull image", target: "alpine", commandPreview: "container image pull alpine")
        store.finish(id: succeededID, status: .succeeded, output: "pulled")
        let failedID = store.start(domain: .compose, title: "Compose up", target: "demo", commandPreview: "container-compose up")
        store.finish(id: failedID, status: .failed, output: "already failed")

        let loaded = AppOperationStore(persistenceURL: url, maxRecords: 5)
        loaded.load()

        #expect(loaded.records.count == 2)
        #expect(loaded.records.map(\.status) == [.failed, .succeeded])
        #expect(loaded.records.first?.output == "already failed")
        #expect(loaded.records.last?.output == "pulled")
    }

    @Test("diagnostic report includes command status target and output")
    func diagnosticReportIncludesCommandStatusTargetAndOutput() {
        let record = AppOperationRecord(
            id: UUID(),
            domain: .network,
            title: "Create network",
            target: "dev-net",
            commandPreview: "container network create dev-net",
            status: .failed,
            output: "line 1\nline 2\nline 3",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            finishedAt: Date(timeIntervalSince1970: 1_700_000_003)
        )

        let report = record.diagnosticReport(language: .en)

        #expect(record.outputPreview == "line 1\nline 2")
        #expect(record.durationText == "3s")
        #expect(report.contains("Domain: Network"))
        #expect(report.contains("Target: dev-net"))
        #expect(report.contains("Status: Failed"))
        #expect(report.contains("container network create dev-net"))
        #expect(report.contains("line 1\nline 2\nline 3"))
    }

    private func temporaryURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "containerdesktop-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "operations.json")
    }
}
