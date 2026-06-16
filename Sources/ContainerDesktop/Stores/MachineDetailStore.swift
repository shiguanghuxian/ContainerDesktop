import Foundation
import Observation

@MainActor
@Observable
final class MachineDetailStore {
    let machineID: String
    private let client: ContainerCLIClient
    private let maxTerminalCharacters = 120_000
    private let maxTerminalOutputEvents = 500

    var selectedTab: MachineDetailTab = .overview

    var inspection: MachineInspection?
    var inspectText = ""
    var inspectSearchText = ""
    var inspectError: String?

    var bootLogs = false
    var logsSearchText = ""
    var logsText = ""
    var logsError: String?

    var commandText = "uname -a"
    var commandOutput = ""
    var commandError: String?
    var isCommandRunning = false

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
    var isSelectedFileEditable = false
    var filePreviewText = ""
    var fileStatusText: String?
    var fileError: String?
    var isFileLoading = false
    var isFileSaving = false
    var fileUsesRoot = false
    private var hasLoadedFiles = false

    init(machineID: String, client: ContainerCLIClient = ContainerCLIClient()) {
        self.machineID = machineID
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

    var visibleInspectText: String {
        let query = inspectSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return inspectText }
        return inspectText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .joined(separator: "\n")
    }

    @ObservationIgnored private var terminalSession: ContainerTerminalSession?

    func bootstrap() async {
        await refreshInspect()
        await loadLogs()
    }

    func refreshInspect() async {
        inspectError = nil
        inspectText = "加载详情..."
        do {
            let result = try await client.inspectMachine(machineID)
            inspection = result.details.first
            inspectText = result.rawText
        } catch {
            inspectError = error.localizedDescription
            inspectText = error.localizedDescription
        }
    }

    func loadLogs() async {
        logsError = nil
        logsText = "加载日志..."
        do {
            logsText = try await client.machineLogs(machineID, boot: bootLogs, lines: 300)
            if logsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logsText = "暂无日志。"
            }
        } catch {
            logsError = error.localizedDescription
            logsText = error.localizedDescription
        }
    }

    func clearLogs() {
        logsText = ""
        logsError = nil
    }

    func runCommand() async {
        let trimmed = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            commandOutput = "请填写要执行的命令。"
            return
        }

        isCommandRunning = true
        commandError = nil
        commandOutput = "执行命令..."
        defer { isCommandRunning = false }

        do {
            let arguments = try CommandLineTokenizer.split(trimmed)
            let output = try await client.runMachineCommand(id: machineID, command: arguments)
            commandOutput = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "命令执行完成，没有输出。" : output
        } catch {
            commandError = error.localizedDescription
            commandOutput = error.localizedDescription
        }
    }

    func clearCommandOutput() {
        commandOutput = ""
        commandError = nil
    }

    func loadFilesIfNeeded() async {
        guard !hasLoadedFiles, !isFileLoading else { return }
        await loadFiles(path: filePath)
    }

    func setFileUsesRoot(_ enabled: Bool) async {
        guard fileUsesRoot != enabled else { return }
        fileUsesRoot = enabled
        selectedFile = nil
        isSelectedFileEditable = false
        filePreviewText = ""
        fileStatusText = enabled ? "Root 模式已开启，文件操作将使用管理员权限。" : nil
        fileError = nil
        if hasLoadedFiles {
            await loadFiles(path: filePath)
        }
    }

    func loadFiles(path: String? = nil) async {
        let targetPath = normalizeDirectory(path ?? filePath)
        isFileLoading = true
        fileError = nil
        fileStatusText = fileUsesRoot ? "Root 模式已开启，文件操作将使用管理员权限。" : nil
        defer { isFileLoading = false }
        do {
            fileEntries = try await client.listMachineFiles(id: machineID, path: targetPath, asRoot: fileUsesRoot)
            filePath = targetPath
            selectedFile = nil
            isSelectedFileEditable = false
            filePreviewText = ""
            hasLoadedFiles = true
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
        isSelectedFileEditable = false
        filePreviewText = ""
        fileError = nil

        guard entry.kind.isPreviewableFile else {
            fileStatusText = "该文件类型暂不支持预览。"
            return
        }
        guard entry.size <= 1_000_000 else {
            fileStatusText = "文件超过 1 MB，默认不预览。"
            return
        }

        do {
            filePreviewText = try await client.machineFileContent(id: machineID, path: entry.path, asRoot: fileUsesRoot)
            isSelectedFileEditable = true
            fileStatusText = fileUsesRoot ? "Root 模式已开启，文件操作将使用管理员权限。" : nil
        } catch {
            fileError = error.localizedDescription
        }
    }

    func saveSelectedFile() async {
        guard let selectedFile else { return }
        guard isSelectedFileEditable else { return }
        isFileSaving = true
        fileError = nil
        defer { isFileSaving = false }
        do {
            try await client.writeMachineFile(
                id: machineID,
                path: selectedFile.path,
                contents: filePreviewText,
                asRoot: fileUsesRoot
            )
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
            try await client.createMachineDirectory(
                id: machineID,
                path: childPath(trimmed, in: filePath),
                asRoot: fileUsesRoot
            )
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
            try await client.renameMachinePath(
                id: machineID,
                source: entry.path,
                destination: childPath(trimmed, in: parentPath(of: entry.path)),
                asRoot: fileUsesRoot
            )
            fileStatusText = "已重命名为 \(trimmed)"
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func delete(_ entry: ContainerFileEntry) async {
        do {
            try await client.deleteMachinePath(id: machineID, path: entry.path, asRoot: fileUsesRoot)
            fileStatusText = "已删除 \(entry.name)"
            if selectedFile?.path == entry.path {
                selectedFile = nil
                isSelectedFileEditable = false
                filePreviewText = ""
            }
            await loadFiles(path: filePath)
        } catch {
            fileError = error.localizedDescription
        }
    }

    func goToParentDirectory() async {
        guard filePath != "/" else { return }
        await loadFiles(path: parentPath(of: filePath))
    }

    func startTerminal() async {
        guard !terminalState.isConnected else { return }
        stopTerminal()
        terminalState = .connecting
        resetTerminalOutput()
        terminalResetSequence += 1
        appendTerminalChunk("Connecting to \(machineID) with sh...\r\n")
        do {
            let session = try await client.makeMachineShellSession(id: machineID, shell: "sh")
            terminalSession = session
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

    func sendTerminalInputData(_ data: Data) {
        guard terminalState.isConnected else { return }
        terminalSession?.send(data)
    }

    func clearTerminal() {
        resetTerminalOutput()
        terminalResetSequence += 1
    }

    func stopTerminal() {
        terminalSession?.stop()
        terminalSession = nil
        if terminalState.isConnected || terminalState == .connecting {
            terminalState = .disconnected
        }
    }

    func stopAll() {
        stopTerminal()
    }

    private func resetTerminalOutput() {
        terminalText = ""
        terminalOutputChunk = ""
        terminalOutputEvents = []
        terminalOutputSequence = 0
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
        terminalSession?.stop()
    }
}
