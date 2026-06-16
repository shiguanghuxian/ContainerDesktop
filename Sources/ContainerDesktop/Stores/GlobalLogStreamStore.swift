import Foundation
import Observation

@MainActor
@Observable
final class GlobalLogStreamStore {
    private let client: ContainerCLIClient
    private let maxStreams: Int
    private let maxLogCharacters: Int

    var logsText = ""
    var isStarting = false
    var isStreaming = false
    var errorMessage: String?
    var followedContainerIDs: [String] = []
    var startedAt: Date?

    @ObservationIgnored private var streams: [String: ContainerProcessStream] = [:]

    init(
        client: ContainerCLIClient = ContainerCLIClient(),
        maxStreams: Int = 8,
        maxLogCharacters: Int = 160_000
    ) {
        self.client = client
        self.maxStreams = maxStreams
        self.maxLogCharacters = maxLogCharacters
    }

    func start(containers: [ContainerSummary], boot: Bool = false, lines: Int = 80) async {
        stop()
        isStarting = true
        errorMessage = nil
        logsText = "启动实时日志..."
        followedContainerIDs = []
        startedAt = Date()
        defer { isStarting = false }

        let selected = containers
            .filter { $0.state == "running" }
            .prefix(maxStreams)
            .map { $0 }

        guard !selected.isEmpty else {
            logsText = "没有可跟随的运行中容器。"
            return
        }

        logsText = ""
        let resolvedLines = max(min(lines, 300), 20)
        for container in selected {
            do {
                let stream = try await client.makeContainerLogStream(id: container.id, boot: boot, lines: resolvedLines)
                try stream.start { [weak self] chunk in
                    Task { @MainActor in
                        self?.append(chunk: chunk, from: container)
                    }
                } onTermination: { [weak self] code in
                    Task { @MainActor in
                        self?.handleTermination(containerID: container.id, imageName: container.imageName, code: code)
                    }
                }
                streams[container.id] = stream
                followedContainerIDs.append(container.id)
            } catch {
                appendSystemLine("无法跟随 \(container.id)：\(error.localizedDescription)")
            }
        }

        if containers.filter({ $0.state == "running" }).count > maxStreams {
            appendSystemLine("已限制实时跟随前 \(maxStreams) 个运行中容器，避免同时启动过多日志进程。")
        }

        isStreaming = !streams.isEmpty
        if !isStreaming, logsText.trimmed.isEmpty {
            logsText = "实时日志未启动。"
        }
    }

    func startSystemLogs(last: String = "5m") async {
        stop()
        isStarting = true
        errorMessage = nil
        logsText = "启动系统实时日志..."
        followedContainerIDs = []
        startedAt = Date()
        defer { isStarting = false }

        do {
            let stream = try await client.makeSystemLogStream(last: last)
            try stream.start { [weak self] chunk in
                Task { @MainActor in
                    self?.appendSystemChunk(chunk)
                }
            } onTermination: { [weak self] code in
                Task { @MainActor in
                    self?.handleSystemTermination(code: code)
                }
            }
            streams["__system__"] = stream
            isStreaming = true
        } catch {
            errorMessage = error.localizedDescription
            logsText = error.localizedDescription
        }
    }

    func stop() {
        streams.values.forEach { $0.stop() }
        streams.removeAll()
        isStreaming = false
        isStarting = false
    }

    func clear() {
        logsText = ""
        errorMessage = nil
    }

    private func append(chunk: String, from container: ContainerSummary) {
        if logsText == "启动实时日志..." {
            logsText = ""
        }
        let formatted = GlobalLogStreamFormatter.prefix(
            chunk: chunk,
            containerID: container.id,
            imageName: container.imageName
        )
        logsText.append(formatted)
        if !logsText.hasSuffix("\n") {
            logsText.append("\n")
        }
        logsText = GlobalLogStreamFormatter.limited(logsText, maxCharacters: maxLogCharacters)
    }

    private func appendSystemChunk(_ chunk: String) {
        if logsText == "启动系统实时日志..." {
            logsText = ""
        }
        logsText.append(GlobalLogStreamFormatter.prefixSystem(chunk: chunk))
        if !logsText.hasSuffix("\n") {
            logsText.append("\n")
        }
        logsText = GlobalLogStreamFormatter.limited(logsText, maxCharacters: maxLogCharacters)
    }

    private func appendSystemLine(_ message: String) {
        logsText.append("\(AppBranding.logPrefix) \(message)\n")
        logsText = GlobalLogStreamFormatter.limited(logsText, maxCharacters: maxLogCharacters)
    }

    private func handleTermination(containerID: String, imageName: String, code: Int32) {
        streams.removeValue(forKey: containerID)
        if code != 0 {
            appendSystemLine("\(containerID) 日志流已断开（退出码 \(code)）。")
            errorMessage = "\(imageName) 日志流已断开（退出码 \(code)）。"
        }
        if streams.isEmpty {
            isStreaming = false
        }
    }

    private func handleSystemTermination(code: Int32) {
        streams.removeValue(forKey: "__system__")
        if code != 0 {
            appendSystemLine("系统日志流已断开（退出码 \(code)）。")
            errorMessage = "系统日志流已断开（退出码 \(code)）。"
        }
        isStreaming = !streams.isEmpty
    }

    deinit {
        streams.values.forEach { $0.stop() }
    }
}
