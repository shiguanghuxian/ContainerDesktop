import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Container detail models")
struct ContainerDetailModelsTests {
    @Test("escapes shell values with single quotes")
    func escapesShellValues() {
        #expect(ShellEscaper.singleQuoted("/tmp/a b") == "'/tmp/a b'")
        #expect(ShellEscaper.singleQuoted("a'b") == "'a'\\''b'")
        #expect(ShellEscaper.singleQuoted("") == "''")
    }

    @Test("parses file listing lines")
    func parsesFileListingLines() throws {
        let line = "hosts\t/etc/hosts\tregular file\t-rw-r--r--\troot\troot\t42\t1781233546\t"
        let entry = try #require(ContainerFileEntry.parseListingLine(line))

        #expect(entry.name == "hosts")
        #expect(entry.path == "/etc/hosts")
        #expect(entry.kind == .regularFile)
        #expect(entry.mode == "-rw-r--r--")
        #expect(entry.size == 42)
        #expect(entry.modifiedAt == Date(timeIntervalSince1970: 1_781_233_546))
    }

    @Test("computes CPU percent from stats deltas")
    func computesStatsCPUPercent() {
        let firstSnapshot = ContainerStatsSnapshot(
            id: "c1",
            blockReadBytes: 0,
            blockWriteBytes: 0,
            cpuUsageUsec: 1_000_000,
            memoryLimitBytes: 1_000_000_000,
            memoryUsageBytes: 10_000,
            networkRxBytes: 0,
            networkTxBytes: 0,
            numProcesses: 1
        )
        let secondSnapshot = ContainerStatsSnapshot(
            id: "c1",
            blockReadBytes: 0,
            blockWriteBytes: 0,
            cpuUsageUsec: 1_500_000,
            memoryLimitBytes: 1_000_000_000,
            memoryUsageBytes: 20_000,
            networkRxBytes: 0,
            networkTxBytes: 0,
            numProcesses: 1
        )

        let first = ContainerStatsSample.make(snapshot: firstSnapshot, date: Date(timeIntervalSince1970: 10))
        let second = ContainerStatsSample.make(snapshot: secondSnapshot, date: Date(timeIntervalSince1970: 12), previous: first)

        #expect(first.cpuPercent == 0)
        #expect(second.cpuPercent == 25)
    }

    @Test("round trips stats samples through JSON")
    func roundTripsStatsSamplesThroughJSON() throws {
        let sample = ContainerStatsSample.make(
            snapshot: Self.makeStatsSnapshot(id: "c1", cpuUsageUsec: 42, memoryUsageBytes: 256),
            date: Date(timeIntervalSince1970: 1_781_233_546)
        )

        let data = try JSONEncoder.containerDesktop.encode(sample)
        let decoded = try JSONDecoder.containerDesktop.decode(ContainerStatsSample.self, from: data)

        #expect(decoded.id == sample.id)
        #expect(decoded.date == sample.date)
        #expect(decoded.snapshot == sample.snapshot)
        #expect(decoded.cpuPercent == sample.cpuPercent)
    }

    @Test("finds nearest stats sample by time")
    func findsNearestStatsSampleByTime() {
        let samples = [
            ContainerStatsSample.make(snapshot: Self.makeStatsSnapshot(id: "c1"), date: Date(timeIntervalSince1970: 10)),
            ContainerStatsSample.make(snapshot: Self.makeStatsSnapshot(id: "c1"), date: Date(timeIntervalSince1970: 20)),
            ContainerStatsSample.make(snapshot: Self.makeStatsSnapshot(id: "c1"), date: Date(timeIntervalSince1970: 40)),
        ]

        #expect(samples.nearest(to: Date(timeIntervalSince1970: 19))?.date == Date(timeIntervalSince1970: 20))
        #expect(samples.nearest(to: Date(timeIntervalSince1970: 31))?.date == Date(timeIntervalSince1970: 40))
        #expect(samples.nearest(to: Date(timeIntervalSince1970: 25))?.date == Date(timeIntervalSince1970: 20))
    }

    @Test("downsamples stats samples while keeping endpoints")
    func downsamplesStatsSamplesWhileKeepingEndpoints() {
        let samples = (0..<10).map {
            ContainerStatsSample.make(
                snapshot: Self.makeStatsSnapshot(id: "c1", cpuUsageUsec: Int64($0)),
                date: Date(timeIntervalSince1970: TimeInterval($0))
            )
        }

        let downsampled = samples.downsampled(maxCount: 4)

        #expect(downsampled.count == 4)
        #expect(downsampled.first?.date == samples.first?.date)
        #expect(downsampled.last?.date == samples.last?.date)
    }

    @Test("stops terminal sessions and reports termination")
    func stopsTerminalSession() throws {
        let terminated = LockedValue<Int32?>(nil)
        let session = ContainerTerminalSession(executable: "/bin/sh", arguments: ["-lc", "sleep 5"])
        let semaphore = DispatchSemaphore(value: 0)

        try session.start { _ in
        } onTermination: { code in
            terminated.set(code)
            semaphore.signal()
        }

        session.stop()
        let result = semaphore.wait(timeout: .now() + 2)

        #expect(result == .success)
        #expect(terminated.value != nil)
    }

    private static func makeStatsSnapshot(
        id: String,
        blockReadBytes: Int64 = 0,
        blockWriteBytes: Int64 = 0,
        cpuUsageUsec: Int64 = 0,
        memoryLimitBytes: Int64 = 1_000_000_000,
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
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value

    init(_ value: Value) {
        storedValue = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func set(_ value: Value) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }
}
