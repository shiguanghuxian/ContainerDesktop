import Darwin
import Foundation

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
    private var process: Process?
    private var masterHandle: FileHandle?
    private var slaveHandle: FileHandle?
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
        let masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        guard masterFD >= 0 else {
            throw ContainerProcessError.pseudoTerminalUnavailable
        }
        guard grantpt(masterFD) == 0, unlockpt(masterFD) == 0, let slaveName = ptsname(masterFD) else {
            close(masterFD)
            throw ContainerProcessError.pseudoTerminalUnavailable
        }

        let slaveFD = open(String(cString: slaveName), O_RDWR | O_NOCTTY)
        guard slaveFD >= 0 else {
            close(masterFD)
            throw ContainerProcessError.pseudoTerminalUnavailable
        }

        let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var environment = ProcessInfo.processInfo.environment
        let searchPath = CommandRunner.defaultSearchRoots().map(\.path).joined(separator: ":")
        let inheritedPath = environment["PATH"] ?? ""
        environment["PATH"] = inheritedPath.isEmpty ? searchPath : "\(searchPath):\(inheritedPath)"
        process.environment = environment
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        masterHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput(text)
        }
        process.terminationHandler = { [weak self] process in
            self?.clearHandlers()
            onTermination(process.terminationStatus)
        }

        self.process = process
        self.masterHandle = masterHandle
        self.slaveHandle = slaveHandle

        do {
            try process.run()
        } catch {
            clearHandlers()
            throw ContainerProcessError.processLaunchFailed(error.localizedDescription)
        }
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        send(data)
    }

    func send(_ data: Data) {
        do {
            try masterHandle?.write(contentsOf: data)
        } catch {
            // The terminal can close while SwiftUI is still sending a final key event.
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
        try? masterHandle?.close()
        try? slaveHandle?.close()
    }

    private func clearHandlers() {
        masterHandle?.readabilityHandler = nil
    }

    deinit {
        stop()
    }
}
