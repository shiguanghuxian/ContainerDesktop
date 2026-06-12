import Foundation

enum CommandRunnerError: LocalizedError, Sendable {
    case executableNotFound(String)
    case timeout(String)
    case nonZeroExit(code: Int32, stderr: String, command: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let executable):
            return "未找到可执行文件：\(executable)"
        case .timeout(let command):
            return "命令超时：\(command)"
        case .nonZeroExit(let code, let stderr, let command):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "命令失败（退出码 \(code)）：\(command)"
            }
            return "命令失败（退出码 \(code)）：\(command)\n\(trimmed)"
        }
    }
}

struct CommandResult: Sendable, Hashable {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

private final class ProcessBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func value() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

actor CommandRunner {
    private let searchRoots: [URL]

    init(searchRoots: [URL] = CommandRunner.defaultSearchRoots()) {
        self.searchRoots = searchRoots
    }

    static func defaultSearchRoots() -> [URL] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        var roots: [URL] = [
            homeDirectory.appendingPathComponent(".local/bin", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/bin", isDirectory: true),
            URL(fileURLWithPath: "/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/sbin", isDirectory: true),
            URL(fileURLWithPath: "/sbin", isDirectory: true),
        ]

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for entry in path.split(separator: ":") {
                roots.append(URL(fileURLWithPath: String(entry), isDirectory: true))
            }
        }

        return roots
    }

    func resolveExecutable(named name: String) -> String? {
        if name.contains("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        for root in searchRoots {
            let candidate = root.appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    func run(
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 120,
        standardInput: String? = nil
    ) async throws -> CommandResult {
        guard let resolved = resolveExecutable(named: executable) else {
            throw CommandRunnerError.executableNotFound(executable)
        }

        let searchRoots = self.searchRoots
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: resolved)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory
            var environment = ProcessInfo.processInfo.environment
            let searchPath = searchRoots.map(\.path).joined(separator: ":")
            let inheritedPath = environment["PATH"] ?? ""
            environment["PATH"] = inheritedPath.isEmpty ? searchPath : "\(searchPath):\(inheritedPath)"
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            let stdinPipe = standardInput == nil ? nil : Pipe()
            if let stdinPipe {
                process.standardInput = stdinPipe
            }

            let stdoutBuffer = ProcessBuffer()
            let stderrBuffer = ProcessBuffer()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stdoutBuffer.append(data)
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stderrBuffer.append(data)
                }
            }

            try process.run()

            if let standardInput, let stdinPipe {
                let inputData = Data(standardInput.utf8)
                stdinPipe.fileHandleForWriting.write(inputData)
                try? stdinPipe.fileHandleForWriting.close()
            }

            if timeout > 0 {
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning {
                    if Date() >= deadline {
                        process.terminate()
                        throw CommandRunnerError.timeout(([resolved] + arguments).joinedCommand)
                    }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
            } else {
                process.waitUntilExit()
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            let stdout = String(data: stdoutBuffer.value(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrBuffer.value(), encoding: .utf8) ?? ""
            let result = CommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
            if process.terminationStatus != 0 {
                throw CommandRunnerError.nonZeroExit(
                    code: result.exitCode,
                    stderr: result.stderr,
                    command: ([resolved] + arguments).joinedCommand
                )
            }
            return result
        }.value
    }
}

private extension Array where Element == String {
    var joinedCommand: String {
        joined(separator: " ")
    }
}
