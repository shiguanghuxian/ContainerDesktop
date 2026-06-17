import Darwin
import Foundation

@_silgen_name("fork")
private func c_fork() -> pid_t

enum ContainerProcessError: LocalizedError, Sendable {
    case executableNotFound(String)
    case processLaunchFailed(String)
    case pseudoTerminalUnavailable

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let executable):
            return "未找到可执行文件：\(executable)"
        case .processLaunchFailed(let reason):
            return "进程启动失败：\(reason)"
        case .pseudoTerminalUnavailable:
            return "无法创建交互式终端。"
        }
    }
}

final class ContainerProcessStream: @unchecked Sendable {
    private let executable: String
    private let arguments: [String]
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let lock = NSLock()
    private var didStop = false

    init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    func start(
        onOutput: @escaping @Sendable (String) -> Void,
        onTermination: @escaping @Sendable (Int32) -> Void
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        let searchPath = CommandRunner.defaultSearchRoots().map(\.path).joined(separator: ":")
        let inheritedPath = environment["PATH"] ?? ""
        environment["PATH"] = inheritedPath.isEmpty ? searchPath : "\(searchPath):\(inheritedPath)"
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let emit: @Sendable (Data) -> Void = { data in
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput(text)
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            emit(handle.availableData)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            emit(handle.availableData)
        }
        process.terminationHandler = { [weak self] process in
            self?.clearHandlers()
            onTermination(process.terminationStatus)
        }

        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        do {
            try process.run()
        } catch {
            clearHandlers()
            throw ContainerProcessError.processLaunchFailed(error.localizedDescription)
        }
    }

    func stop() {
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        didStop = true
        let process = self.process
        lock.unlock()

        clearHandlers()
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func clearHandlers() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
    }

    deinit {
        stop()
    }
}

final class ContainerTerminalSession: @unchecked Sendable {
    private let executable: String
    private let arguments: [String]
    private let workingDirectory: URL?
    private let environmentOverrides: [String: String]
    private var masterHandle: FileHandle?
    private var childPID: pid_t?
    private var masterFD: Int32 = -1
    private var terminalColumns: Int
    private var terminalRows: Int
    private let lock = NSLock()
    private var didStop = false

    init(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environmentOverrides: [String: String] = [:],
        initialColumns: Int = 80,
        initialRows: Int = 24
    ) {
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentOverrides = environmentOverrides
        terminalColumns = max(1, initialColumns)
        terminalRows = max(1, initialRows)
    }

    func start(
        onOutput: @escaping @Sendable (String) -> Void,
        onTermination: @escaping @Sendable (Int32) -> Void
    ) throws {
        var environment = ProcessInfo.processInfo.environment
        let searchPath = CommandRunner.defaultSearchRoots().map(\.path).joined(separator: ":")
        let inheritedPath = environment["PATH"] ?? ""
        environment["PATH"] = inheritedPath.isEmpty ? searchPath : "\(searchPath):\(inheritedPath)"
        if environment["TERM"] == nil {
            environment["TERM"] = "xterm-256color"
        }
        for (key, value) in environmentOverrides {
            environment[key] = value
        }

        var argv = CStrings([executable] + arguments)
        defer { argv.deallocate() }
        var envp = CStrings(environment.map { "\($0.key)=\($0.value)" })
        defer { envp.deallocate() }
        let executableCString = strdup(executable)
        defer { free(executableCString) }
        let workingDirectoryCString = workingDirectory.map { strdup($0.path) } ?? nil
        defer {
            if let workingDirectoryCString {
                free(workingDirectoryCString)
            }
        }
        let launchFailureMessage = strdup("container desktop: exec failed\r\n")
        defer { free(launchFailureMessage) }

        lock.lock()
        let columns = terminalColumns
        let rows = terminalRows
        lock.unlock()

        var windowSize = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        var masterFD: Int32 = -1
        var slaveFD: Int32 = -1
        let openedPTY = openpty(&masterFD, &slaveFD, nil, nil, &windowSize)
        let pid: pid_t
        if openedPTY == 0 {
            pid = argv.withMutablePointer { argvPointer in
                envp.withMutablePointer { envPointer in
                    c_fork().withChildProcess {
                        close(masterFD)
                        Self.restoreDefaultInteractiveSignals()
                        _ = setsid()
                        _ = ioctl(slaveFD, TIOCSCTTY, 0)
                        _ = tcsetpgrp(slaveFD, getpgrp())
                        if slaveFD != STDIN_FILENO {
                            _ = dup2(slaveFD, STDIN_FILENO)
                        }
                        if slaveFD != STDOUT_FILENO {
                            _ = dup2(slaveFD, STDOUT_FILENO)
                        }
                        if slaveFD != STDERR_FILENO {
                            _ = dup2(slaveFD, STDERR_FILENO)
                        }
                        if slaveFD > STDERR_FILENO {
                            close(slaveFD)
                        }
                        if let workingDirectoryCString {
                            _ = chdir(workingDirectoryCString)
                        }
                        execve(executableCString, argvPointer, envPointer)
                        if let launchFailureMessage {
                            _ = write(STDERR_FILENO, launchFailureMessage, strlen(launchFailureMessage))
                        }
                        _exit(127)
                    }
                }
            }
        } else {
            pid = -1
        }
        guard pid >= 0, masterFD >= 0 else {
            if masterFD >= 0 {
                close(masterFD)
            }
            if slaveFD >= 0 {
                close(slaveFD)
            }
            throw ContainerProcessError.pseudoTerminalUnavailable
        }
        if slaveFD >= 0 {
            close(slaveFD)
        }

        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        masterHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput(text)
        }

        lock.lock()
        if didStop {
            lock.unlock()
            clearHandlers()
            try? masterHandle.close()
            _ = kill(-pid, SIGHUP)
            _ = kill(pid, SIGHUP)
            return
        }
        self.childPID = pid
        self.masterFD = masterFD
        self.masterHandle = masterHandle
        lock.unlock()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var status: Int32 = 0
            let waitResult = Self.waitForChild(pid, status: &status)
            let exitCode = Self.exitCode(waitResult: waitResult, status: status)
            self?.clearHandlers()
            onTermination(exitCode)
        }
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        send(data)
    }

    func send(_ data: Data) {
        lock.lock()
        let fd = masterFD
        let stopped = didStop
        lock.unlock()
        guard !stopped, fd >= 0, !data.isEmpty else { return }

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var bytesWritten = 0
            while bytesWritten < data.count {
                let result = write(fd, baseAddress.advanced(by: bytesWritten), data.count - bytesWritten)
                if result > 0 {
                    bytesWritten += result
                    continue
                }
                if result == -1, errno == EINTR {
                    continue
                }
                break
            }
        }
        if data.contains(0x03) {
            sendInterruptSignal()
        }
    }

    func resize(columns: Int, rows: Int) {
        let columns = max(1, columns)
        let rows = max(1, rows)
        lock.lock()
        terminalColumns = columns
        terminalRows = rows
        let fd = masterFD
        let pid = childPID
        let stopped = didStop
        lock.unlock()

        guard !stopped, fd >= 0 else { return }
        applyWindowSize(columns: columns, rows: rows, fileDescriptor: fd)
        if let pid, pid > 0 {
            if kill(-pid, SIGWINCH) != 0 {
                _ = kill(pid, SIGWINCH)
            }
        }
    }

    func stop() {
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        didStop = true
        let pid = childPID
        let handle = masterHandle
        lock.unlock()

        clearHandlers()
        let foregroundProcessGroup = pid.flatMap(Self.ttyForegroundProcessGroup(for:)) ?? -1
        if let pid, pid > 0 {
            Self.signal(pid: pid, foregroundProcessGroup: foregroundProcessGroup, signal: SIGHUP)
            Self.signal(pid: pid, foregroundProcessGroup: foregroundProcessGroup, signal: SIGTERM)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35) {
                Self.signal(pid: pid, foregroundProcessGroup: foregroundProcessGroup, signal: SIGKILL)
            }
        }
        try? handle?.close()
    }

    private func clearHandlers() {
        lock.lock()
        let handle = masterHandle
        lock.unlock()
        handle?.readabilityHandler = nil
    }

    private func applyWindowSize(columns: Int, rows: Int, fileDescriptor: Int32) {
        var windowSize = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: columns),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(fileDescriptor, TIOCSWINSZ, &windowSize)
    }

    private static func waitForChild(_ pid: pid_t, status: inout Int32) -> pid_t {
        var result = waitpid(pid, &status, 0)
        while result == -1, errno == EINTR {
            result = waitpid(pid, &status, 0)
        }
        return result
    }

    private static func exitCode(waitResult: pid_t, status: Int32) -> Int32 {
        guard waitResult >= 0 else { return 1 }
        let signal = status & 0x7f
        if signal == 0 {
            return (status >> 8) & 0xff
        }
        if signal != 0x7f {
            return 128 + signal
        }
        return 1
    }

    private static func signal(pid: pid_t, foregroundProcessGroup: pid_t, signal: Int32) {
        if foregroundProcessGroup > 0 {
            _ = kill(-foregroundProcessGroup, signal)
        }
        _ = kill(-pid, signal)
        _ = kill(pid, signal)
    }

    private static func restoreDefaultInteractiveSignals() {
        var emptySignalSet = sigset_t()
        _ = sigemptyset(&emptySignalSet)
        _ = sigprocmask(SIG_SETMASK, &emptySignalSet, nil)
        _ = Darwin.signal(SIGHUP, SIG_DFL)
        _ = Darwin.signal(SIGINT, SIG_DFL)
        _ = Darwin.signal(SIGQUIT, SIG_DFL)
        _ = Darwin.signal(SIGTERM, SIG_DFL)
        _ = Darwin.signal(SIGTSTP, SIG_DFL)
        _ = Darwin.signal(SIGTTIN, SIG_DFL)
        _ = Darwin.signal(SIGTTOU, SIG_DFL)
        _ = Darwin.signal(SIGPIPE, SIG_DFL)
    }

    private func sendInterruptSignal() {
        lock.lock()
        let pid = childPID
        let stopped = didStop
        lock.unlock()
        guard !stopped else { return }

        let foregroundProcessGroup = pid.flatMap(Self.ttyForegroundProcessGroup(for:)) ?? -1
        if foregroundProcessGroup > 0 {
            _ = kill(-foregroundProcessGroup, SIGINT)
        } else if let pid, pid > 0 {
            _ = kill(-pid, SIGINT)
            _ = kill(pid, SIGINT)
        }
    }

    private static func ttyForegroundProcessGroup(for pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let result = proc_pidinfo(
            pid,
            PROC_PIDTBSDINFO,
            0,
            &info,
            Int32(MemoryLayout<proc_bsdinfo>.size)
        )
        guard result == MemoryLayout<proc_bsdinfo>.size else { return nil }
        let foregroundProcessGroup = pid_t(info.e_tpgid)
        return foregroundProcessGroup > 0 ? foregroundProcessGroup : nil
    }

    deinit {
        stop()
    }
}

private struct CStrings {
    private var cStrings: [UnsafeMutablePointer<CChar>?]
    private var pointers: [UnsafeMutablePointer<CChar>?]

    init(_ strings: [String]) {
        cStrings = strings.map { strdup($0) }
        pointers = cStrings
        pointers.append(nil)
    }

    mutating func withMutablePointer<Result>(
        _ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> Result
    ) -> Result {
        pointers.withUnsafeMutableBufferPointer { buffer in
            body(buffer.baseAddress)
        }
    }

    mutating func deallocate() {
        for cString in cStrings {
            free(cString)
        }
        cStrings.removeAll()
        pointers.removeAll()
    }
}

private extension Int32 {
    func withChildProcess(_ body: () -> Never) -> Int32 {
        if self == 0 {
            body()
        }
        return self
    }
}
