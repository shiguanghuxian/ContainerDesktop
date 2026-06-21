import Foundation

enum ComposeProjectAutoRegistrationSource: String, Hashable, Sendable {
    case dockerCompatibilityTerminal
}

struct DockerComposeProjectRegistrationRequest: Hashable, Sendable {
    var composeFileURL: URL
    var source: ComposeProjectAutoRegistrationSource = .dockerCompatibilityTerminal

    static func make(
        executable: String,
        arguments: [String],
        workingDirectory: URL
    ) -> DockerComposeProjectRegistrationRequest? {
        let executableName = URL(fileURLWithPath: executable).lastPathComponent
        let composeArguments: [String]

        switch executableName {
        case "docker-compose":
            composeArguments = arguments
        case "docker":
            guard let arguments = dockerComposeArguments(from: arguments) else { return nil }
            composeArguments = arguments
        default:
            return nil
        }

        return make(composeArguments: composeArguments, workingDirectory: workingDirectory)
    }

    private static func dockerComposeArguments(from arguments: [String]) -> [String]? {
        var index = 0
        while index < arguments.count {
            let token = arguments[index]
            if token == "compose" {
                return Array(arguments.dropFirst(index + 1))
            }
            if token == "--help" || token == "-h" || token == "--version" || token == "-v" {
                return nil
            }
            if dockerGlobalOptionsWithValue.contains(token) {
                index += 2
                continue
            }
            if dockerGlobalOptionsWithoutValue.contains(token) || dockerGlobalOptionHasInlineValue(token) {
                index += 1
                continue
            }
            return nil
        }
        return nil
    }

    private static func make(
        composeArguments arguments: [String],
        workingDirectory: URL
    ) -> DockerComposeProjectRegistrationRequest? {
        var index = 0
        var composeFilePaths: [String] = []
        var subcommand: String?

        while index < arguments.count {
            let token = arguments[index]
            if supportedComposeSubcommands.contains(token) {
                subcommand = token
                break
            }
            if nonProjectComposeSubcommands.contains(token) || token == "--help" || token == "-h" || token == "--version" {
                return nil
            }
            if token == "-f" || token == "--file" {
                guard index + 1 < arguments.count else { return nil }
                composeFilePaths.append(arguments[index + 1])
                index += 2
                continue
            }
            if token.hasPrefix("--file=") {
                composeFilePaths.append(String(token.dropFirst("--file=".count)))
                index += 1
                continue
            }
            if token.hasPrefix("-f"), token.count > 2 {
                composeFilePaths.append(String(token.dropFirst(2)))
                index += 1
                continue
            }
            if composeOptionsWithValue.contains(token) {
                index += 2
                continue
            }
            if composeOptionHasInlineValue(token) || token.hasPrefix("-") {
                index += 1
                continue
            }
            subcommand = token
            break
        }

        guard let subcommand, supportedComposeSubcommands.contains(subcommand),
              let composeFileURL = resolveComposeFileURL(paths: composeFilePaths, workingDirectory: workingDirectory)
        else {
            return nil
        }

        return DockerComposeProjectRegistrationRequest(
            composeFileURL: composeFileURL,
            source: .dockerCompatibilityTerminal
        )
    }

    private static func resolveComposeFileURL(paths: [String], workingDirectory: URL) -> URL? {
        if !paths.isEmpty {
            for path in paths {
                if let url = existingFileURL(path: path, workingDirectory: workingDirectory) {
                    return url
                }
            }
            return nil
        }

        for filename in defaultComposeFilenames {
            if let url = existingFileURL(path: filename, workingDirectory: workingDirectory) {
                return url
            }
        }
        return nil
    }

    private static func existingFileURL(path: String, workingDirectory: URL) -> URL? {
        let rawURL = path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : workingDirectory.appending(path: path)
        let url = rawURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return nil
        }
        return url
    }

    private static func dockerGlobalOptionHasInlineValue(_ token: String) -> Bool {
        dockerGlobalOptionsWithInlineValue.contains { token.hasPrefix($0) }
    }

    private static func composeOptionHasInlineValue(_ token: String) -> Bool {
        composeOptionsWithInlineValue.contains { token.hasPrefix($0) }
    }

    private static let defaultComposeFilenames = [
        "compose.yaml",
        "compose.yml",
        "docker-compose.yaml",
        "docker-compose.yml",
    ]
    private static let supportedComposeSubcommands: Set<String> = ["up", "build", "down"]
    private static let nonProjectComposeSubcommands: Set<String> = ["version", "help"]
    private static let dockerGlobalOptionsWithoutValue: Set<String> = [
        "--debug",
        "--tls",
        "--tlsverify",
    ]
    private static let dockerGlobalOptionsWithValue: Set<String> = [
        "--config",
        "--context",
        "--host",
        "--log-level",
        "-H",
    ]
    private static let dockerGlobalOptionsWithInlineValue = [
        "--config=",
        "--context=",
        "--host=",
        "--log-level=",
    ]
    private static let composeOptionsWithValue: Set<String> = [
        "--ansi",
        "--env-file",
        "--parallel",
        "--profile",
        "--progress",
        "--project-directory",
        "--project-name",
        "-p",
    ]
    private static let composeOptionsWithInlineValue = [
        "--ansi=",
        "--env-file=",
        "--parallel=",
        "--profile=",
        "--progress=",
        "--project-directory=",
        "--project-name=",
    ]
}

enum ComposeProjectAutoRegistrationNotification {
    static let name = Notification.Name("com.shiguanghuxian.ContainerDesktop.Compose.autoRegisterProject")
    static let composeFilePathUserInfoKey = "composeFilePath"
    static let sourceUserInfoKey = "source"

    static func post(_ request: DockerComposeProjectRegistrationRequest) {
        DistributedNotificationCenter.default().postNotificationName(
            name,
            object: nil,
            userInfo: [
                composeFilePathUserInfoKey: request.composeFileURL.standardizedFileURL.path,
                sourceUserInfoKey: request.source.rawValue,
            ],
            deliverImmediately: true
        )
    }

    static func request(from userInfo: [AnyHashable: Any]?) -> DockerComposeProjectRegistrationRequest? {
        guard let path = userInfo?[composeFilePathUserInfoKey] as? String,
              let sourceRawValue = userInfo?[sourceUserInfoKey] as? String,
              let source = ComposeProjectAutoRegistrationSource(rawValue: sourceRawValue)
        else {
            return nil
        }

        return DockerComposeProjectRegistrationRequest(
            composeFileURL: URL(fileURLWithPath: path).standardizedFileURL,
            source: source
        )
    }
}
