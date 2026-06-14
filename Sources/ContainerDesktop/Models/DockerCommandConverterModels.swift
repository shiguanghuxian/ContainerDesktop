import Foundation

enum DockerCommandConversionStatus: Int, Hashable, Sendable {
    case empty = 0
    case converted = 1
    case warning = 2
    case unsupported = 3
    case invalid = 4

    var tintName: String {
        switch self {
        case .empty: "secondary"
        case .converted: "success"
        case .warning: "warning"
        case .unsupported, .invalid: "danger"
        }
    }
}

struct ConvertedContainerCommand: Hashable, Sendable {
    var executable: String
    var arguments: [String]

    var preview: String {
        AppOperationCommandPreview.make(executable: executable, arguments: arguments)
    }
}

struct DockerCommandConversionResult: Hashable, Sendable {
    var status: DockerCommandConversionStatus
    var commands: [ConvertedContainerCommand]
    var notes: [String]

    var commandText: String {
        commands.map(\.preview).joined(separator: "\n")
    }

    static let empty = DockerCommandConversionResult(
        status: .empty,
        commands: [],
        notes: ["输入一条 docker 命令后会自动生成 apple/container 命令。"]
    )
}

enum DockerCommonCommandCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case containers
    case images
    case registry
    case system
    case compose

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        let isChinese = language.resolved == .zhHans
        switch self {
        case .containers:
            return isChinese ? "容器" : "Containers"
        case .images:
            return isChinese ? "镜像" : "Images"
        case .registry:
            return isChinese ? "仓库" : "Registry"
        case .system:
            return isChinese ? "系统与清理" : "System and cleanup"
        case .compose:
            return "Compose"
        }
    }
}

struct DockerCommonCommand: Identifiable, Hashable, Sendable {
    var id: String { dockerCommand }
    var category: DockerCommonCommandCategory
    var titleZH: String
    var titleEN: String
    var dockerCommand: String
    var containerCommand: String
    var noteZH: String?
    var noteEN: String?

    func title(language: AppLanguage) -> String {
        language.resolved == .zhHans ? titleZH : titleEN
    }

    func note(language: AppLanguage) -> String? {
        language.resolved == .zhHans ? noteZH : noteEN
    }
}

enum DockerCommandConverter {
    static let commonCommands: [DockerCommonCommand] = [
        .init(
            category: .containers,
            titleZH: "列出所有容器",
            titleEN: "List all containers",
            dockerCommand: "docker ps -a",
            containerCommand: "container list --all"
        ),
        .init(
            category: .containers,
            titleZH: "运行并发布端口",
            titleEN: "Run with a published port",
            dockerCommand: "docker run --name web -p 8080:80 nginx:latest",
            containerCommand: "container run --name web -p 8080:80 nginx:latest"
        ),
        .init(
            category: .containers,
            titleZH: "跟随最近日志",
            titleEN: "Follow recent logs",
            dockerCommand: "docker logs -f --tail 200 web",
            containerCommand: "container logs --follow -n 200 web"
        ),
        .init(
            category: .containers,
            titleZH: "进入容器 shell",
            titleEN: "Open a shell",
            dockerCommand: "docker exec -it web sh",
            containerCommand: "container exec -it web sh"
        ),
        .init(
            category: .containers,
            titleZH: "复制容器文件",
            titleEN: "Copy a container file",
            dockerCommand: "docker cp web:/etc/nginx/nginx.conf ./nginx.conf",
            containerCommand: "container copy web:/etc/nginx/nginx.conf ./nginx.conf"
        ),
        .init(
            category: .containers,
            titleZH: "检查容器",
            titleEN: "Inspect a container",
            dockerCommand: "docker inspect web",
            containerCommand: "container inspect web"
        ),
        .init(
            category: .images,
            titleZH: "列出镜像",
            titleEN: "List images",
            dockerCommand: "docker images",
            containerCommand: "container image list"
        ),
        .init(
            category: .images,
            titleZH: "拉取镜像",
            titleEN: "Pull an image",
            dockerCommand: "docker pull nginx:latest",
            containerCommand: "container image pull nginx:latest"
        ),
        .init(
            category: .images,
            titleZH: "构建镜像",
            titleEN: "Build an image",
            dockerCommand: "docker build -t demo:latest .",
            containerCommand: "container build -t demo:latest ."
        ),
        .init(
            category: .images,
            titleZH: "标记镜像",
            titleEN: "Tag an image",
            dockerCommand: "docker tag demo:latest registry.example.com/demo:latest",
            containerCommand: "container image tag demo:latest registry.example.com/demo:latest"
        ),
        .init(
            category: .images,
            titleZH: "推送镜像",
            titleEN: "Push an image",
            dockerCommand: "docker push registry.example.com/demo:latest",
            containerCommand: "container image push registry.example.com/demo:latest"
        ),
        .init(
            category: .images,
            titleZH: "删除镜像",
            titleEN: "Delete an image",
            dockerCommand: "docker rmi demo:latest",
            containerCommand: "container image delete demo:latest"
        ),
        .init(
            category: .registry,
            titleZH: "登录 Docker Hub",
            titleEN: "Login to Docker Hub",
            dockerCommand: "docker login docker.io",
            containerCommand: "container registry login docker.io",
            noteZH: "密码仍由 container CLI 写入 macOS 钥匙串。",
            noteEN: "Credentials are still written by the container CLI to macOS Keychain."
        ),
        .init(
            category: .system,
            titleZH: "查看磁盘占用",
            titleEN: "Show disk usage",
            dockerCommand: "docker system df",
            containerCommand: "container system df"
        ),
        .init(
            category: .system,
            titleZH: "安全清理缓存",
            titleEN: "Safe cleanup",
            dockerCommand: "docker system prune",
            containerCommand: "container prune\ncontainer image prune",
            noteZH: "第一行清停止容器，第二行清 dangling 镜像；不等同于 Docker 的所有 prune 选项。",
            noteEN: "First line prunes stopped containers, second line prunes dangling images; this is not equivalent to every Docker prune option."
        ),
        .init(
            category: .compose,
            titleZH: "启动 Compose 项目",
            titleEN: "Start a Compose project",
            dockerCommand: "docker compose up -d",
            containerCommand: "container-compose up -d",
            noteZH: "需要安装 container-compose。",
            noteEN: "Requires container-compose."
        ),
    ]

    static func convert(_ input: String) -> DockerCommandConversionResult {
        let lines = input
            .components(separatedBy: .newlines)
            .map(stripPrompt)
            .filter { !$0.trimmed.isEmpty }

        guard !lines.isEmpty else { return .empty }

        var commands: [ConvertedContainerCommand] = []
        var notes: [String] = []
        var status: DockerCommandConversionStatus = .converted

        for (index, line) in lines.enumerated() {
            let result = convertLine(line)
            commands.append(contentsOf: result.commands)
            let prefix = lines.count > 1 ? "第 \(index + 1) 行：" : ""
            notes.append(contentsOf: result.notes.map { "\(prefix)\($0)" })
            status = max(status, result.status)
        }

        if commands.isEmpty, status == .converted {
            status = .unsupported
        }

        return DockerCommandConversionResult(status: status, commands: commands, notes: notes)
    }

    private static func convertLine(_ line: String) -> DockerCommandConversionResult {
        do {
            var tokens = try CommandLineTokenizer.split(line)
            guard !tokens.isEmpty else { return .empty }

            var notes: [String] = []
            if tokens.first == "sudo" {
                tokens.removeFirst()
                notes.append("已移除 sudo；container 通常不需要用 sudo 执行。")
            }

            guard let executable = tokens.first else { return .empty }
            tokens.removeFirst()

            if executable == "container" || executable == "container-compose" {
                return .init(
                    status: .warning,
                    commands: [.init(executable: executable, arguments: tokens)],
                    notes: notes + ["输入已经是 apple/container 命令，保持不变。"]
                )
            }

            if executable == "docker-compose" {
                return .init(
                    status: .warning,
                    commands: [.init(executable: "container-compose", arguments: tokens)],
                    notes: notes + ["Docker Compose 已转换为 container-compose；请确认本机已安装 container-compose。"]
                )
            }

            guard executable == "docker" else {
                return .init(
                    status: .unsupported,
                    commands: [],
                    notes: notes + ["目前只支持 docker、docker-compose、container 和 container-compose 命令。"]
                )
            }

            let stripped = stripDockerGlobalOptions(tokens)
            notes.append(contentsOf: stripped.notes)
            tokens = stripped.arguments

            guard !tokens.isEmpty else {
                return .init(status: .unsupported, commands: [], notes: notes + ["缺少 docker 子命令。"])
            }

            if tokens.first == "compose" {
                tokens.removeFirst()
                return .init(
                    status: .warning,
                    commands: [.init(executable: "container-compose", arguments: tokens)],
                    notes: notes + ["Docker Compose 已转换为 container-compose；请确认本机已安装 container-compose。"]
                )
            }

            return mapDockerSubcommand(tokens, notes: notes)
        } catch {
            return .init(
                status: .invalid,
                commands: [],
                notes: ["命令解析失败：\(error.localizedDescription)"]
            )
        }
    }

    private static func mapDockerSubcommand(_ tokens: [String], notes: [String]) -> DockerCommandConversionResult {
        var tokens = tokens
        let subcommand = tokens.removeFirst()
        var notes = notes + riskNotes(for: tokens)

        switch subcommand {
        case "ps":
            return command(["list"] + mapListArguments(tokens, notes: &notes), notes: notes)
        case "images":
            return command(["image", "list"] + mapListArguments(tokens, notes: &notes), notes: notes)
        case "pull":
            return command(["image", "pull"] + tokens, notes: notes)
        case "push":
            return command(["image", "push"] + tokens, notes: notes)
        case "tag":
            return command(["image", "tag"] + tokens, notes: notes)
        case "rmi":
            return command(["image", "delete"] + dropDockerRemoveFlags(tokens, notes: &notes), notes: notes)
        case "build":
            notes.append("Docker BuildKit 专属参数可能需要手动核对。")
            return command(["build"] + tokens, notes: notes)
        case "run", "create", "start", "stop", "restart", "kill", "exec", "stats":
            return command([subcommand] + tokens, notes: notes)
        case "rm":
            return command(["delete"] + dropDockerRemoveFlags(tokens, notes: &notes), notes: notes)
        case "logs":
            return command(["logs"] + mapLogArguments(tokens, notes: &notes), notes: notes)
        case "cp":
            return command(["copy"] + tokens, notes: notes)
        case "inspect":
            notes.append("如果目标是镜像，请改用 container image inspect <image>。")
            return command(["inspect"] + tokens, notes: notes)
        case "login":
            return command(["registry", "login"] + tokens, notes: notes)
        case "logout":
            return command(["registry", "logout"] + tokens, notes: notes)
        case "container":
            return mapNestedCommand(tokens, namespace: nil, notes: notes)
        case "image":
            return mapNestedCommand(tokens, namespace: "image", notes: notes)
        case "network":
            return mapNestedCommand(tokens, namespace: "network", notes: notes)
        case "volume":
            return mapNestedCommand(tokens, namespace: "volume", notes: notes)
        case "system":
            return mapSystemCommand(tokens, notes: notes)
        default:
            return .init(
                status: .unsupported,
                commands: [],
                notes: notes + ["暂不支持 docker \(subcommand)。可以先查看常用命令或手动改写。"]
            )
        }
    }

    private static func mapNestedCommand(
        _ tokens: [String],
        namespace: String?,
        notes: [String]
    ) -> DockerCommandConversionResult {
        guard let commandName = tokens.first else {
            return .init(status: .unsupported, commands: [], notes: notes + ["缺少子命令。"])
        }

        let rest = Array(tokens.dropFirst())
        let mappedName: String
        switch commandName {
        case "ls":
            mappedName = "list"
        case "rm", "remove":
            mappedName = "delete"
        case "prune":
            if namespace == nil {
                return command(["prune"] + rest, notes: notes)
            }
            mappedName = "prune"
        default:
            mappedName = commandName
        }

        var arguments: [String] = []
        if let namespace {
            arguments.append(namespace)
        }
        arguments.append(mappedName)

        var notes = notes
        let mappedRest: [String]
        if mappedName == "list" {
            mappedRest = mapListArguments(rest, notes: &notes)
        } else if namespace == nil, mappedName == "logs" {
            mappedRest = mapLogArguments(rest, notes: &notes)
        } else if mappedName == "delete" {
            mappedRest = dropDockerRemoveFlags(rest, notes: &notes)
        } else {
            mappedRest = rest
        }
        return command(arguments + mappedRest, notes: notes)
    }

    private static func mapSystemCommand(_ tokens: [String], notes: [String]) -> DockerCommandConversionResult {
        guard let commandName = tokens.first else {
            return .init(status: .unsupported, commands: [], notes: notes + ["缺少 system 子命令。"])
        }

        let rest = Array(tokens.dropFirst())
        switch commandName {
        case "df":
            return command(["system", "df"] + rest, notes: notes)
        case "prune":
            return .init(
                status: .warning,
                commands: [
                    .init(executable: "container", arguments: ["prune"]),
                    .init(executable: "container", arguments: ["image", "prune"]),
                ],
                notes: notes + ["已转换为安全清理：删除停止容器和 dangling 镜像；不会删除 volume，也不会等同于 docker system prune --volumes。"]
            )
        default:
            return .init(status: .unsupported, commands: [], notes: notes + ["暂不支持 docker system \(commandName)。"])
        }
    }

    private static func command(_ arguments: [String], notes: [String]) -> DockerCommandConversionResult {
        let status: DockerCommandConversionStatus = notes.isEmpty ? .converted : .warning
        return .init(status: status, commands: [.init(executable: "container", arguments: arguments)], notes: notes)
    }

    private static func mapListArguments(_ arguments: [String], notes: inout [String]) -> [String] {
        var output: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-a":
                output.append("--all")
            case "--format":
                if index + 1 < arguments.count {
                    let value = arguments[index + 1]
                    if value != "json" {
                        notes.append("Docker Go template --format 与 container 的 JSON 输出不完全兼容，请核对。")
                    }
                    output.append(contentsOf: ["--format", value])
                    index += 1
                } else {
                    output.append(argument)
                }
            default:
                output.append(argument)
            }
            index += 1
        }
        return output
    }

    private static func mapLogArguments(_ arguments: [String], notes: inout [String]) -> [String] {
        var output: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "-f" {
                output.append("--follow")
            } else if argument == "--tail", index + 1 < arguments.count {
                output.append(contentsOf: ["-n", arguments[index + 1]])
                index += 1
            } else if argument.hasPrefix("--tail=") {
                output.append(contentsOf: ["-n", String(argument.dropFirst("--tail=".count))])
            } else if argument == "--timestamps" || argument == "-t" {
                notes.append("container logs 没有完全等价的 Docker 时间戳格式，已保留/请核对。")
                output.append(argument)
            } else {
                output.append(argument)
            }
            index += 1
        }
        return output
    }

    private static func dropDockerRemoveFlags(_ arguments: [String], notes: inout [String]) -> [String] {
        var output: [String] = []
        for argument in arguments {
            if argument == "-v" || argument == "--volumes" {
                notes.append("已忽略 Docker 删除 volume 的参数；apple/container 的 volume 建议单独确认后删除。")
            } else {
                output.append(argument)
            }
        }
        return output
    }

    private static func stripDockerGlobalOptions(_ arguments: [String]) -> (arguments: [String], notes: [String]) {
        var output = arguments
        var notes: [String] = []

        while let first = output.first, first.hasPrefix("-") {
            if first == "-D" || first == "--debug" {
                output.removeFirst()
                notes.append("已忽略 Docker 全局调试参数 \(first)。")
            } else if first == "--context" || first == "--host" || first == "-H" || first == "--config" || first == "--log-level" {
                let option = output.removeFirst()
                if !output.isEmpty { output.removeFirst() }
                notes.append("已忽略 Docker 全局参数 \(option)，container CLI 不使用 Docker daemon context。")
            } else if first.hasPrefix("--context=") || first.hasPrefix("--host=") || first.hasPrefix("--config=") || first.hasPrefix("--log-level=") {
                output.removeFirst()
                notes.append("已忽略 Docker daemon 相关全局参数 \(first)。")
            } else {
                break
            }
        }

        return (output, notes)
    }

    private static func riskNotes(for arguments: [String]) -> [String] {
        let riskyFlags = [
            "--privileged": "apple/container 对特权容器能力与 Docker 不完全一致，请核对。",
            "--restart": "Docker restart policy 没有直接等价项，请手动确认运行策略。",
            "--gpus": "GPU 参数没有直接等价项，请手动确认。",
            "--device": "设备映射参数可能不适用于 apple/container。",
            "--network=host": "host network 在 apple/container 中可能没有直接等价行为。",
        ]

        return riskyFlags.compactMap { flag, note in
            arguments.contains { argument in
                argument == flag || argument.hasPrefix("\(flag)=")
            } ? note : nil
        }
    }

    private static func stripPrompt(_ line: String) -> String {
        var value = line.trimmed
        for prompt in ["$", "%", "❯", ">"] where value.hasPrefix("\(prompt) ") {
            value.removeFirst(prompt.count)
            return value.trimmed
        }
        return value
    }
}

private func max(_ lhs: DockerCommandConversionStatus, _ rhs: DockerCommandConversionStatus) -> DockerCommandConversionStatus {
    lhs.rawValue >= rhs.rawValue ? lhs : rhs
}
