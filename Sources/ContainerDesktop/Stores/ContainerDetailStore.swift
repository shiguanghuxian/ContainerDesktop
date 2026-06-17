import Foundation
import Observation

@MainActor
@Observable
final class ContainerDetailStore {
    let containerID: String
    private let client: ContainerCLIClient
    private let maxLogCharacters = 160_000
    private let maxTerminalCharacters = 120_000
    private let maxTerminalOutputEvents = 500

    var selectedTab: ContainerDetailTab = .logs

    var inspectText = ""
    var inspectSearchText = ""
    var inspectRawJSON = false
    var inspectError: String?

    var bootLogs = false
    var followLogs = true
    var isLogsPaused = false
    var logsSearchText = ""
    var logsText = ""
    var logsError: String?
    var isStreamingLogs = false

    var terminalText = ""
    var terminalOutputChunk = ""
    var terminalOutputEvents: [TerminalOutputEvent] = []
    var terminalOutputSequence = 0
    var terminalResetSequence = 0
    var terminalState: TerminalSessionState = .disconnected

    var filePath = "/"
    var fileEntries: [ContainerFileEntry] = []
    var fileSearchText = ""
    var fileSort: ContainerFileSort = .name
    var selectedFile: ContainerFileEntry?
    var filePreviewText = ""
    var fileStatusText: String?
    var fileError: String?
    var isFileLoading = false
    var isFileSaving = false

    @ObservationIgnored private var logStream: ContainerProcessStream?
    @ObservationIgnored private var terminalSession: ContainerTerminalSession?
    @ObservationIgnored private var terminalColumns = 80
    @ObservationIgnored private var terminalRows = 24

    init(containerID: String, client: ContainerCLIClient = ContainerCLIClient()) {
        self.containerID = containerID
        self.client = client
    }

    var filteredFileEntries: [ContainerFileEntry] {
        let query = fileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = fileEntries.sorted(by: fileSort)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.name.lowercased().contains(query)
                || $0.path.lowercased().contains(query)
                || $0.mode.lowercased().contains(query)
        }
    }

    var filteredLogsText: String {
        let query = logsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return logsText }
        return logsText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .joined(separator: "\n")
    }

    var inspectSections: [String] {
        guard let json = inspectJSON else { return [] }
        switch json {
        case .array(let values):
            guard let first = values.first else { return [] }
            if case .object(let object) = first {
                return object.keys.sorted()
            }
        case .object(let object):
            return object.keys.sorted()
        default:
            break
        }
        return []
    }

    var inspectJSON: JSONValue? {
        guard let data = inspectText.data(using: .utf8) else { return nil }
        return try? JSONDecoder.containerDesktop.decode(JSONValue.self, from: data)
    }

    func bootstrap() async {
        await refreshInspect()
        await loadLogs()
        await loadFiles(path: filePath)
    }

    func refreshInspect() async {
        inspectError = nil
        inspectText = "加载详情..."
        do {
            inspectText = try await client.inspectContainer(containerID).prettyString
        } catch {
            inspectError = error.localizedDescription
            inspectText = error.localizedDescription
        }
    }

    func loadLogs() async {
        stopLogStream()
        logsError = nil
        logsText = "加载日志..."
        do {
            logsText = try await client.containerLogs(containerID, boot: bootLogs, lines: 300)
            if logsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logsText = "暂无日志。"
            }
            if followLogs {
                await startLogStream()
            }
        } catch {
            logsError = error.localizedDescription
            logsText = error.localizedDescription
        }
    }

    func startLogStream() async {
        stopLogStream()
        guard followLogs else { return }
        do {
            let stream = try await client.makeContainerLogStream(id: containerID, boot: bootLogs, lines: 20)
            logStream = stream
            isStreamingLogs = true
            try stream.start { [weak self] chunk in
                Task { @MainActor in
                    self?.appendLogChunk(chunk)
                }
            } onTermination: { [weak self] code in
                Task { @MainActor in
                    self?.isStreamingLogs = false
                    if code != 0, self?.followLogs == true {
                        self?.logsError = "日志流已断开（退出码 \(code)）。"
                    }
                }
            }
        } catch {
            isStreamingLogs = false
            logsError = error.localizedDescription
        }
    }

    func stopLogStream() {
        logStream?.stop()
        logStream = nil
        isStreamingLogs = false
    }

    func clearLogs() {
        logsText = ""
        logsError = nil
    }

    func toggleFollowLogs() async {
        followLogs.toggle()
        if followLogs {
            await startLogStream()
        } else {
            stopLogStream()
        }
    }

    func startTerminal() async {
        guard !terminalState.isConnected else { return }
        stopTerminal()
        terminalState = .connecting
        terminalText = ""
        terminalOutputChunk = ""
        terminalOutputEvents = []
        terminalOutputSequence = 0
        terminalResetSequence += 1
        appendTerminalChunk("Connecting to \(containerID) with sh...\r\n")
        do {
            let session = try await client.makeContainerShellSession(id: containerID, shell: "sh")
            terminalSession = session
            session.resize(columns: terminalColumns, rows: terminalRows)
            try session.start { [weak self] chunk in
                Task { @MainActor in
                    self?.appendTerminalChunk(chunk)
                }
            } onTermination: { [weak self, weak session] code in
                Task { @MainActor in
                    guard let self, let session, self.terminalSession === session else { return }
                    self.terminalState = code == 0 ? .disconnected : .failed("Shell 已退出（退出码 \(code)）。")
                    self.terminalSession = nil
                }
            }
            terminalState = .connected
        } catch {
            terminalState = .failed(error.localizedDescription)
            terminalSession = nil
            appendTerminalChunk("\n\(error.localizedDescription)\n")
        }
    }

    func sendTerminalInput(_ input: String) {
        guard terminalState.isConnected else { return }
        terminalSession?.send(input)
    }

    func sendTerminalInputData(_ data: Data) {
        guard terminalState.isConnected else { return }
        terminalSession?.send(data)
    }

    func resizeTerminal(columns: Int, rows: Int) {
        terminalColumns = columns
        terminalRows = rows
        terminalSession?.resize(columns: columns, rows: rows)
    }

    func clearTerminal() {
        terminalText = ""
        terminalOutputChunk = ""
        terminalOutputEvents = []
        terminalResetSequence += 1
    }

    func stopTerminal() {
        terminalSession?.stop()
        terminalSession = nil
        if terminalState.isConnected || terminalState == .connecting {
            terminalState = .disconnected
        }
    }

    func loadFiles(path: String? = nil) async {
        let targetPath = normalizeDirectory(path ?? filePath)
        isFileLoading = true
        fileError = nil
        fileStatusText = nil
        defer { isFileLoading = false }
        do {
            fileEntries = try await client.listContainerFiles(id: containerID, path: targetPath)
            filePath = targetPath
            selectedFile = nil
            filePreviewText = ""
        } catch {
            fileError = error.localizedDescription
        }
    }

    func openFileEntry(_ entry: ContainerFileEntry) async {
        if entry.isDirectory {
            await loadFiles(path: entry.path)
            return
        }
        selectedFile = entry
        filePreviewText = ""
        fileError = nil

        guard entry.kind.isPreviewableFile else {
            fileStatusText = "该文件类型只能下载，暂不预览。"
            return
        }
        guard entry.size <= 1_000_000 else {
            fileStatusText = "文件超过 1 MB，默认只允许下载。"
            return
        }

        do {
            filePreviewText = try await client.containerFileContent(id: containerID, path: entry.path)
            fileStatusText = nil
        } catch {
            fileError = error.localizedDescription
        }
    }

    func saveSelectedFile() async {
        guard let selectedFile else { return }
        isFileSaving = true
        fileError = nil
        defer { isFileSaving = false }
        do {
            try await client.writeContainerFile(id: containerID, path: selectedFile.path, contents: filePreviewText)
            fileStatusText = "已保存 \(selectedFile.name)"
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func createDirectory(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await client.createContainerDirectory(id: containerID, path: childPath(trimmed, in: filePath))
            fileStatusText = "已创建目录 \(trimmed)"
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func rename(_ entry: ContainerFileEntry, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != entry.name else { return }
        do {
            try await client.renameContainerPath(id: containerID, source: entry.path, destination: childPath(trimmed, in: parentPath(of: entry.path)))
            fileStatusText = "已重命名为 \(trimmed)"
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func delete(_ entry: ContainerFileEntry) async {
        do {
            try await client.deleteContainerPath(id: containerID, path: entry.path)
            fileStatusText = "已删除 \(entry.name)"
            if selectedFile?.path == entry.path {
                selectedFile = nil
                filePreviewText = ""
            }
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func upload(localURL: URL) async {
        let destination = childPath(localURL.lastPathComponent, in: filePath)
        do {
            try await client.copyToContainer(id: containerID, localPath: localURL.path, remotePath: destination)
            fileStatusText = "已上传 \(localURL.lastPathComponent)"
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func download(_ entry: ContainerFileEntry, to localURL: URL) async {
        do {
            try await client.copyFromContainer(id: containerID, remotePath: entry.path, localPath: localURL.path)
            fileStatusText = "已下载到 \(localURL.path)"
        } catch {
            fileError = error.localizedDescription
        }
    }

    func goToParentDirectory() async {
        guard filePath != "/" else { return }
        await loadFiles(path: parentPath(of: filePath))
    }

    func stopAll() {
        stopLogStream()
        stopTerminal()
    }

    private func appendLogChunk(_ chunk: String) {
        guard !isLogsPaused else { return }
        if logsText == "加载日志..." || logsText == "暂无日志。" {
            logsText = ""
        }
        logsText.append(chunk)
        if logsText.count > maxLogCharacters {
            logsText.removeFirst(logsText.count - maxLogCharacters)
        }
    }

    private func appendTerminalChunk(_ chunk: String) {
        terminalText.append(chunk)
        terminalOutputChunk = chunk
        terminalOutputSequence &+= 1
        terminalOutputEvents.append(TerminalOutputEvent(sequence: terminalOutputSequence, text: chunk))
        if terminalOutputEvents.count > maxTerminalOutputEvents {
            terminalOutputEvents.removeFirst(terminalOutputEvents.count - maxTerminalOutputEvents)
        }
        if terminalText.count > maxTerminalCharacters {
            terminalText.removeFirst(terminalText.count - maxTerminalCharacters)
        }
    }

    private func normalizeDirectory(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "/" }
        if trimmed == "/" { return "/" }
        let withLeadingSlash = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        return String(withLeadingSlash.drop(while: { $0 == "/" })).isEmpty
            ? "/"
            : "/" + withLeadingSlash.split(separator: "/").joined(separator: "/")
    }

    private func childPath(_ name: String, in directory: String) -> String {
        let cleanName = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if directory == "/" {
            return "/\(cleanName)"
        }
        return "\(directory)/\(cleanName)"
    }

    private func parentPath(of path: String) -> String {
        let normalized = normalizeDirectory(path)
        guard normalized != "/" else { return "/" }
        let url = URL(fileURLWithPath: normalized)
        let parent = url.deletingLastPathComponent().path
        return parent.isEmpty ? "/" : parent
    }

    deinit {
        logStream?.stop()
        terminalSession?.stop()
    }
}
