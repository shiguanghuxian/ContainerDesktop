import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Container detail models", .serialized)
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

    @Test("builds browser targets from published TCP ports")
    func buildsBrowserTargetsFromPublishedTCPPorts() {
        let container = Self.makeContainer(ipv4Address: "192.168.64.2")
        let inspect = """
        [{
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" },
              { "host": "::", "hostPort": "8443", "containerPort": "443", "protocol": "tcp" }
            ]
          }
        }]
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

        #expect(targets.compactMap { $0.url?.absoluteString } == [
            "http://127.0.0.1:8080",
            "http://192.168.64.2:80",
            "https://127.0.0.1:8443",
            "https://192.168.64.2:443",
        ])
        #expect(values(in: targets, action: .copyURL) == [
            "http://127.0.0.1:8080",
            "http://192.168.64.2:80",
            "https://127.0.0.1:8443",
            "https://192.168.64.2:443",
        ])
        #expect(values(in: targets, action: .copyHealthCheckCommand) == [
            "curl -fsS http://127.0.0.1:8080",
            "curl -fsS http://192.168.64.2:80",
            "curl -fsS https://127.0.0.1:8443",
            "curl -fsS https://192.168.64.2:443",
        ])
        #expect(targets.filter { $0.action == .openURL }.map(\.source) == [.host, .container, .host, .container])
        #expect(ContainerBrowserPortTarget.portSummary(from: inspect) == "8080:80/tcp, 8443:443/tcp")
    }

    @Test("builds database copy actions from common images")
    func buildsDatabaseCopyActionsFromCommonImages() {
        let container = Self.makeContainer(imageName: "postgres:16", ipv4Address: "192.168.64.2")
        let inspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 15432, "containerPort": 5432, "protocol": "tcp" }
            ]
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

        #expect(values(in: targets, action: .copyAddress) == [
            "127.0.0.1:15432",
            "192.168.64.2:5432",
        ])
        #expect(values(in: targets, action: .copyConnectionString) == [
            "postgresql://postgres@127.0.0.1:15432/postgres",
            "postgresql://postgres@192.168.64.2:5432/postgres",
        ])
        #expect(values(in: targets, action: .copyEnvironmentSnippet).first == """
        PGHOST=127.0.0.1
        PGPORT=15432
        PGUSER=postgres
        PGDATABASE=postgres
        DATABASE_URL=postgresql://postgres@127.0.0.1:15432/postgres
        """)
        #expect(values(in: targets, action: .copyCLICommand).contains("psql 'postgresql://postgres@127.0.0.1:15432/postgres'"))
        #expect(values(in: targets, action: .copyHealthCheckCommand).contains("pg_isready -h 127.0.0.1 -p 15432 -U postgres"))
        #expect(targets.compactMap(\.url).isEmpty)
    }

    @Test("builds client commands for database services")
    func buildsClientCommandsForDatabaseServices() {
        let cases: [(String, Int, String, String, String)] = [
            ("mysql:8", 3306, "mysql -h 127.0.0.1 -P 3306 -u root -p", "MYSQL_HOST=127.0.0.1\nMYSQL_TCP_PORT=3306\nMYSQL_USER=root\nDATABASE_URL=mysql://root@127.0.0.1:3306", "mysql://root@127.0.0.1:3306"),
            ("redis:7", 6379, "redis-cli -u 'redis://127.0.0.1:6379'", "REDIS_URL=redis://127.0.0.1:6379", "redis://127.0.0.1:6379"),
            ("mongo:7", 27017, "mongosh 'mongodb://127.0.0.1:27017'", "MONGODB_URI=mongodb://127.0.0.1:27017", "mongodb://127.0.0.1:27017"),
        ]

        for (imageName, containerPort, command, environment, connectionString) in cases {
            let container = Self.makeContainer(imageName: imageName, ipv4Address: "192.168.64.2")
            let inspect = """
            {
              "configuration": {
                "publishedPorts": [
                  { "hostIP": "0.0.0.0", "hostPort": \(containerPort), "containerPort": \(containerPort), "protocol": "tcp" }
                ]
              }
            }
            """

            let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

            #expect(values(in: targets, action: .copyConnectionString).contains(connectionString))
            #expect(values(in: targets, action: .copyEnvironmentSnippet).contains(environment))
            #expect(values(in: targets, action: .copyCLICommand).contains(command))
        }
    }

    @Test("builds distinct actions for common multi-port images")
    func buildsDistinctActionsForCommonMultiPortImages() {
        let container = Self.makeContainer(imageName: "rabbitmq:3-management", ipv4Address: "192.168.64.3")
        let inspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 15672, "containerPort": 15672, "protocol": "tcp" },
              { "hostIP": "0.0.0.0", "hostPort": 5672, "containerPort": 5672, "protocol": "tcp" }
            ]
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

        #expect(targets.compactMap { $0.url?.absoluteString } == [
            "http://127.0.0.1:15672",
            "http://192.168.64.3:15672",
        ])
        #expect(values(in: targets, action: .copyConnectionString) == [
            "amqp://guest@127.0.0.1:5672",
            "amqp://guest@192.168.64.3:5672",
        ])
        #expect(values(in: targets, action: .copyAddress).contains("127.0.0.1:5672"))
        #expect(values(in: targets, action: .copyEnvironmentSnippet).contains("AMQP_URL=amqp://guest@127.0.0.1:5672"))
        #expect(values(in: targets, action: .copyHealthCheckCommand).contains("nc -vz 127.0.0.1 5672"))
        #expect(ContainerBrowserPortTarget.portSummary(from: inspect) == "15672:15672/tcp, 5672:5672/tcp")
    }

    @Test("builds quick actions for admin and protocol ports")
    func buildsQuickActionsForAdminAndProtocolPorts() {
        let container = Self.makeContainer(imageName: "minio/minio:latest", ipv4Address: "192.168.64.5")
        let inspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 19000, "containerPort": 9000, "protocol": "tcp" },
              { "hostIP": "0.0.0.0", "hostPort": 19001, "containerPort": 9001, "protocol": "tcp" }
            ]
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)
        let minioURLs = targets.compactMap { target in target.url?.absoluteString }

        #expect(minioURLs.contains("http://127.0.0.1:19001"))
        #expect(values(in: targets, action: .copyEnvironmentSnippet).contains("MINIO_ENDPOINT=http://127.0.0.1:19000"))
        #expect(values(in: targets, action: .copyCLICommand).contains("mc alias set local http://127.0.0.1:19000 '<access-key>' '<secret-key>'"))

        let neo4j = Self.makeContainer(imageName: "neo4j:latest", ipv4Address: "192.168.64.6")
        let neo4jInspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 17687, "containerPort": 7687, "protocol": "tcp" }
            ]
          }
        }
        """
        let neo4jTargets = ContainerBrowserPortTarget.targets(from: neo4jInspect, container: neo4j)

        #expect(values(in: neo4jTargets, action: .copyConnectionString).contains("bolt://127.0.0.1:17687"))
        #expect(values(in: neo4jTargets, action: .copyEnvironmentSnippet).contains("NEO4J_URI=bolt://127.0.0.1:17687"))
        #expect(values(in: neo4jTargets, action: .copyCLICommand).contains("cypher-shell -a 'bolt://127.0.0.1:17687'"))
    }

    @Test("builds address and nc command for unknown TCP ports")
    func buildsAddressAndNCCommandForUnknownTCPPorts() {
        let container = Self.makeContainer(imageName: "example/custom:latest", ipv4Address: "192.168.64.7")
        let inspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "hostIP": "0.0.0.0", "hostPort": 11234, "containerPort": 12345, "protocol": "tcp" }
            ]
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

        #expect(values(in: targets, action: .copyAddress) == [
            "127.0.0.1:11234",
            "192.168.64.7:12345",
        ])
        #expect(values(in: targets, action: .copyHealthCheckCommand) == [
            "nc -vz 127.0.0.1 11234",
            "nc -vz 192.168.64.7 12345",
        ])
        #expect(targets.map(\.action) == [
            .copyAddress,
            .copyHealthCheckCommand,
            .copyAddress,
            .copyHealthCheckCommand,
        ])
    }

    @Test("parses docker network settings and exposed ports")
    func parsesDockerNetworkSettingsAndExposedPorts() {
        let container = Self.makeContainer(imageName: "redis:7", ipv4Address: "192.168.64.4")
        let inspect = """
        {
          "NetworkSettings": {
            "Ports": {
              "6379/tcp": [{ "HostIp": "0.0.0.0", "HostPort": "16379" }],
              "8081/tcp": null
            }
          },
          "Config": {
            "ExposedPorts": {
              "6379/tcp": {},
              "8081/tcp": {}
            }
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)
        let urls = targets.compactMap { target in target.url?.absoluteString }

        #expect(targets.compactMap(\.copyValue).contains("redis://127.0.0.1:16379"))
        #expect(targets.compactMap(\.copyValue).contains("redis://192.168.64.4:6379"))
        #expect(urls.contains("http://192.168.64.4:8081"))
        #expect(ContainerBrowserPortTarget.portSummary(from: inspect) == "16379:6379/tcp, 8081/tcp")
    }

    @Test("filters invalid duplicate and non TCP browser targets")
    func filtersInvalidDuplicateAndNonTCPBrowserTargets() {
        let container = Self.makeContainer(ipv4Address: "10.0.0.8")
        let inspect = """
        {
          "configuration": {
            "publishedPorts": [
              { "host": "127.0.0.1", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" },
              { "host": "127.0.0.1", "hostPort": 8080, "containerPort": 80, "protocol": "tcp" },
              { "hostPort": 5353, "containerPort": 53, "protocol": "udp" },
              { "hostPort": "bad", "containerPort": "bad", "protocol": "tcp" },
              { "hostPort": 9000, "containerPort": 70000, "protocol": "tcp" }
            ]
          }
        }
        """

        let targets = ContainerBrowserPortTarget.targets(from: inspect, container: container)

        #expect(targets.compactMap { $0.url?.absoluteString } == [
            "http://127.0.0.1:8080",
            "http://10.0.0.8:80",
        ])
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

    @Test("terminal sessions expose configured pseudo-terminal size")
    func terminalSessionUsesConfiguredPseudoTerminalSize() throws {
        let output = LockedValue("")
        let semaphore = DispatchSemaphore(value: 0)
        let session = ContainerTerminalSession(executable: "/bin/sh", arguments: ["-lc", "stty size"])
        session.resize(columns: 101, rows: 33)

        try session.start { chunk in
            output.mutate { $0 += chunk }
        } onTermination: { _ in
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + 2)

        #expect(result == .success)
        #expect(output.value.contains("33 101"))
    }

    @Test("terminal sessions preserve carriage-return progress output")
    func terminalSessionPreservesProgressCarriageReturns() throws {
        let output = LockedValue("")
        let semaphore = DispatchSemaphore(value: 0)
        let session = ContainerTerminalSession(
            executable: "/bin/sh",
            arguments: ["-lc", "test -t 1 && printf 'TTY_OK\\n'; printf '0%%\\r50%%\\r100%%\\n'"]
        )

        try session.start { chunk in
            output.mutate { $0 += chunk }
        } onTermination: { _ in
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + 2)

        #expect(result == .success)
        #expect(output.value.contains("TTY_OK"))
        #expect(output.value.contains("\r50%"))
        #expect(output.value.contains("\r100%"))
    }

    @Test("terminal sessions deliver Ctrl-C to the foreground process group")
    func terminalSessionCtrlCInterruptsForegroundCommand() throws {
        let output = LockedValue("")
        let semaphore = DispatchSemaphore(value: 0)
        let session = ContainerTerminalSession(
            executable: "/bin/sh",
            arguments: ["-i"]
        )

        try session.start { chunk in
            output.mutate { $0 += chunk }
        } onTermination: { _ in
            semaphore.signal()
        }

        Thread.sleep(forTimeInterval: 0.3)
        session.send("sleep 10\n")
        Thread.sleep(forTimeInterval: 1.0)
        session.send(Data([0x03]))
        Thread.sleep(forTimeInterval: 1.0)
        session.send("echo AFTER_INT\nexit\n")
        let result = semaphore.wait(timeout: .now() + 6)
        session.stop()

        #expect(result == .success)
        #expect(output.value.contains("AFTER_INT"))
    }

    @Test("terminal sessions support zsh tab completion")
    func terminalSessionSupportsZshTabCompletion() throws {
        let output = LockedValue("")
        let semaphore = DispatchSemaphore(value: 0)
        let session = ContainerTerminalSession(
            executable: "/bin/zsh",
            arguments: ["-f", "-i"]
        )

        try session.start { chunk in
            output.mutate { $0 += chunk }
        } onTermination: { _ in
            semaphore.signal()
        }

        Thread.sleep(forTimeInterval: 0.8)
        session.send("autoload -Uz compinit; compinit -u -D\n")
        Thread.sleep(forTimeInterval: 1.0)
        session.send("cd /Us")
        session.send(Data([0x09]))
        Thread.sleep(forTimeInterval: 0.5)
        session.send("\npwd\nexit\n")
        let result = semaphore.wait(timeout: .now() + 6)
        session.stop()

        let lines = output.value
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        #expect(result == .success)
        #expect(lines.contains("/Users"))
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

    private func values(
        in targets: [ContainerBrowserPortTarget],
        action: ContainerPortQuickActionKind
    ) -> [String] {
        targets
            .filter { $0.action == action }
            .compactMap(\.copyValue)
    }

    private static func makeContainer(imageName: String = "nginx:latest", ipv4Address: String) -> ContainerSummary {
        ContainerSummary(
            configuration: .init(
                id: "web",
                image: .init(reference: imageName),
                platform: .init(os: "linux", architecture: "arm64"),
                resources: .init(cpus: 1, memoryInBytes: 1_073_741_824),
                creationDate: nil,
                labels: [:]
            ),
            status: .init(
                state: "running",
                networks: [.init(ipv4Address: ipv4Address)],
                startedDate: nil
            )
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

    func mutate(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&storedValue)
        lock.unlock()
    }
}
