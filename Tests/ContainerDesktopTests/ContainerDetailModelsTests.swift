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
