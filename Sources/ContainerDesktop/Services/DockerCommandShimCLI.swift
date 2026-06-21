import Darwin
import Foundation

enum DockerCommandShimCLI {
    static let argumentFlag = "--containerdesktop-docker-shim"
    private static let verboseEnvironmentKey = "CONTAINERDESKTOP_DOCKER_SHIM_VERBOSE"

    static func runIfNeeded(arguments: [String] = CommandLine.arguments) -> Bool {
        guard arguments.count >= 3, arguments[1] == argumentFlag else {
            return false
        }

        let executable = arguments[2]
        let dockerArguments = Array(arguments.dropFirst(3))
        let result = DockerCommandConverter.convertInvocation(
            executable: executable,
            arguments: dockerArguments
        )

        if result.commands.isEmpty {
            writeFailure(result)
            exit(125)
        }

        postComposeProjectAutoRegistrationIfNeeded(
            executable: executable,
            arguments: dockerArguments
        )
        writeVerboseConversionIfNeeded(result, originalExecutable: executable, originalArguments: dockerArguments)

        if result.commands.count == 1, let command = result.commands.first {
            exec(command)
        }

        let code = runSequentially(result.commands)
        exit(code)
    }

    private static var isVerbose: Bool {
        let value = ProcessInfo.processInfo.environment[verboseEnvironmentKey] ?? ""
        return value == "1" || value.lowercased() == "true"
    }

    static func composeProjectRegistrationRequest(
        executable: String,
        arguments: [String],
        workingDirectory: URL
    ) -> DockerComposeProjectRegistrationRequest? {
        DockerComposeProjectRegistrationRequest.make(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory
        )
    }

    private static func postComposeProjectAutoRegistrationIfNeeded(
        executable: String,
        arguments: [String]
    ) {
        let workingDirectory = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        guard let request = composeProjectRegistrationRequest(
            executable: executable,
            arguments: arguments,
            workingDirectory: workingDirectory
        ) else {
            return
        }
        ComposeProjectAutoRegistrationNotification.post(request)
    }

    private static func writeFailure(_ result: DockerCommandConversionResult) {
        let notes = result.notes.isEmpty ? ["无法转换该 Docker 命令。"] : result.notes
        for note in notes {
            FileHandle.standardError.writeLine("ContainerDesktop docker shim: \(note)")
        }
    }

    private static func writeVerboseConversionIfNeeded(
        _ result: DockerCommandConversionResult,
        originalExecutable: String,
        originalArguments: [String]
    ) {
        guard isVerbose else { return }
        let original = AppOperationCommandPreview.make(
            executable: originalExecutable,
            arguments: originalArguments
        )
        FileHandle.standardError.writeLine("ContainerDesktop docker shim: \(original)")
        for command in result.commands {
            FileHandle.standardError.writeLine("  -> \(command.preview)")
        }
        for note in result.notes {
            FileHandle.standardError.writeLine("  ! \(note)")
        }
    }

    private static func exec(_ command: ConvertedContainerCommand) -> Never {
        let values = [command.executable] + command.arguments
        let cArguments = values.map { strdup($0) } + [nil]
        defer {
            for pointer in cArguments where pointer != nil {
                free(pointer)
            }
        }

        var mutableArguments = cArguments
        command.executable.withCString { executableName in
            execvp(executableName, &mutableArguments)
            perror(executableName)
        }
        exit(127)
    }

    private static func runSequentially(_ commands: [ConvertedContainerCommand]) -> Int32 {
        for command in commands {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command.executable] + command.arguments

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                FileHandle.standardError.writeLine("ContainerDesktop docker shim: \(error.localizedDescription)")
                return 127
            }

            guard process.terminationStatus == 0 else {
                return process.terminationStatus
            }
        }
        return 0
    }
}

private extension FileHandle {
    func writeLine(_ line: String) {
        guard let data = "\(line)\n".data(using: .utf8) else { return }
        write(data)
    }
}
