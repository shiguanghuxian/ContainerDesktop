import Foundation
import Observation

@MainActor
@Observable
final class DockerCompatibilityTerminalStore {
    private let service: DockerCompatibilityTerminalService
    private let historyDefaults: UserDefaults
    private let maxTerminalCharacters = 180_000
    private let terminalOutputFlushDelayNanoseconds: UInt64 = 16_000_000
    let openRequest: DockerCompatibilityTerminalOpenRequest
    let workingDirectory: URL
    let shellTarget: TerminalShellTarget?

    var terminalText = ""
    var terminalOutputEvents: [TerminalOutputEvent] = []
    var terminalOutputSequence = 0
    var terminalResetSequence = 0
    var terminalState: TerminalSessionState = .disconnected
    var lastEnvironment: DockerCompatibilityTerminalEnvironment?
    var verboseConversions = false

    @ObservationIgnored private var terminalSession: ContainerTerminalSession?
    @ObservationIgnored private var terminalColumns = 80
    @ObservationIgnored private var terminalRows = 24
    @ObservationIgnored private var pendingTerminalOutput = ""
    @ObservationIgnored private var pendingTerminalFlushTask: Task<Void, Never>?

    init(
        service: DockerCompatibilityTerminalService = DockerCompatibilityTerminalService(),
        historyDefaults: UserDefaults = .containerDesktopShared,
        workingDirectory: URL = AppPaths.homeDirectory,
        shellTarget: TerminalShellTarget? = nil
    ) {
        self.service = service
        self.historyDefaults = historyDefaults
        let request = DockerCompatibilityTerminalOpenRequest(
            workingDirectory: workingDirectory,
            shellTarget: shellTarget
        )
        openRequest = request
        self.workingDirectory = request.workingDirectory
        self.shellTarget = request.shellTarget
    }

    init(
        service: DockerCompatibilityTerminalService = DockerCompatibilityTerminalService(),
        historyDefaults: UserDefaults = .containerDesktopShared,
        openRequest: DockerCompatibilityTerminalOpenRequest
    ) {
        self.service = service
        self.historyDefaults = historyDefaults
        self.openRequest = openRequest
        workingDirectory = openRequest.workingDirectory
        shellTarget = openRequest.shellTarget
    }

    var shimPathText: String {
        lastEnvironment?.shimBinDirectory.path ?? AppPaths.dockerCompatibilityShimBinDirectory.path
    }

    var workingDirectoryText: String {
        workingDirectory.path
    }

    func startTerminal() async {
        guard !terminalState.isConnected, terminalState != .connecting else { return }
        stopTerminal()
        terminalState = .connecting
        resetTerminalOutput()
        terminalResetSequence += 1

        do {
            let prepared = try service.makeSession(
                verboseConversions: verboseConversions,
                request: openRequest
            )
            lastEnvironment = prepared.environment
            terminalSession = prepared.session
            prepared.session.resize(columns: terminalColumns, rows: terminalRows)
            try prepared.session.start { [weak self] chunk in
                Task { @MainActor in
                    self?.appendTerminalChunk(chunk)
                }
            } onTermination: { [weak self, weak session = prepared.session] code in
                Task { @MainActor in
                    guard let self, let session, self.terminalSession === session else { return }
                    self.flushPendingTerminalOutput()
                    self.terminalState = code == 0 ? .disconnected : .failed("Shell 已退出（退出码 \(code)）。")
                    self.terminalSession = nil
                }
            }
            terminalState = .connected
        } catch {
            terminalState = .failed(error.localizedDescription)
            terminalSession = nil
            appendTerminalChunk("\r\n\(error.localizedDescription)\r\n", flushImmediately: true)
        }
    }

    func restartTerminal() async {
        stopTerminal()
        await startTerminal()
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
        flushPendingTerminalOutput()
        resetTerminalOutput()
        terminalResetSequence += 1
    }

    func stopTerminal() {
        flushPendingTerminalOutput()
        terminalSession?.stop()
        terminalSession = nil
        if terminalState.isConnected || terminalState == .connecting {
            terminalState = .disconnected
        }
    }

    private func resetTerminalOutput() {
        cancelPendingTerminalFlush()
        pendingTerminalOutput = ""
        terminalText = ""
        terminalOutputEvents = []
        terminalOutputSequence = 0
    }

    func appendTerminalChunk(_ chunk: String, flushImmediately: Bool = false) {
        guard !chunk.isEmpty else { return }
        pendingTerminalOutput.append(chunk)
        if flushImmediately {
            flushPendingTerminalOutput()
        } else {
            schedulePendingTerminalFlush()
        }
    }

    func flushPendingTerminalOutput() {
        cancelPendingTerminalFlush()
        guard !pendingTerminalOutput.isEmpty else { return }
        let chunk = pendingTerminalOutput
        pendingTerminalOutput = ""
        appendTerminalFrame(chunk)
    }

    private func schedulePendingTerminalFlush() {
        guard pendingTerminalFlushTask == nil else { return }
        let delay = terminalOutputFlushDelayNanoseconds
        pendingTerminalFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.flushPendingTerminalOutput()
        }
    }

    private func cancelPendingTerminalFlush() {
        pendingTerminalFlushTask?.cancel()
        pendingTerminalFlushTask = nil
    }

    private func appendTerminalFrame(_ chunk: String) {
        terminalText.append(chunk)
        terminalOutputSequence &+= 1
        terminalOutputEvents.append(TerminalOutputEvent(sequence: terminalOutputSequence, text: chunk))
        let maxTerminalOutputEvents = DockerCompatibilityTerminalHistorySettings.storedOutputEventLimit(in: historyDefaults)
        if terminalOutputEvents.count > maxTerminalOutputEvents {
            terminalOutputEvents.removeFirst(terminalOutputEvents.count - maxTerminalOutputEvents)
        }
        if terminalText.count > maxTerminalCharacters {
            terminalText.removeFirst(terminalText.count - maxTerminalCharacters)
        }
    }

    deinit {
        pendingTerminalFlushTask?.cancel()
        terminalSession?.stop()
    }
}
