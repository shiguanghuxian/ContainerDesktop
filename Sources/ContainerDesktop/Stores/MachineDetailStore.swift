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

    var configCPUs = 4
    var configMemory = ""
    var homeMount = MachineHomeMountOption.rw
    var configStatusText: String?
    var configError: String?

    init(machineID: String, client: ContainerCLIClient = ContainerCLIClient()) {
        self.machineID = machineID
        self.client = client
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
            syncSettingsFromInspection()
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

    func saveConfig() async {
        let nextCPUs = String(configCPUs)
        let nextMemory = configMemory.nilIfBlank
        let nextHomeMount = homeMount.rawValue

        configStatusText = nil
        configError = nil

        guard nextMemory != nil || inspection?.cpus != configCPUs || inspection?.homeMount != nextHomeMount else {
            configError = "请至少修改一个配置项。"
            return
        }

        do {
            try await client.setMachineConfig(
                id: machineID,
                cpus: nextCPUs,
                memory: nextMemory,
                homeMount: nextHomeMount
            )
            configStatusText = "配置已保存，下次停启后生效。"
            configMemory = ""
            await refreshInspect()
        } catch {
            configError = error.localizedDescription
        }
    }

    private func syncSettingsFromInspection() {
        guard let inspection else { return }
        configCPUs = inspection.cpus
        homeMount = MachineHomeMountOption(rawValue: inspection.homeMount) ?? .rw
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

    deinit {
        terminalSession?.stop()
    }
}
