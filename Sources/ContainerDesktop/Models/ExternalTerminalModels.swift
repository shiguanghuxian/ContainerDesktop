import Foundation

enum ExternalTerminalDestination: String, CaseIterable, Identifiable, Hashable, Sendable {
    case systemTerminal
    case dockerCompatibilityTerminal

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .systemTerminal: "macwindow"
        case .dockerCompatibilityTerminal: "terminal"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .systemTerminal:
            language.resolved == .zhHans ? "系统终端" : "System Terminal"
        case .dockerCompatibilityTerminal:
            language.resolved == .zhHans ? "Docker 兼容终端" : "Docker Compatibility Terminal"
        }
    }
}

enum TerminalShellTarget: Hashable, Sendable {
    case container(id: String)
    case machine(id: String)

    enum Kind: String, Hashable, Sendable {
        case container
        case machine
    }

    init?(kindRawValue: String?, id: String?) {
        guard let kindRawValue,
              let kind = Kind(rawValue: kindRawValue),
              let id = id?.trimmed,
              !id.isEmpty
        else {
            return nil
        }

        switch kind {
        case .container:
            self = .container(id: id)
        case .machine:
            self = .machine(id: id)
        }
    }

    var kind: Kind {
        switch self {
        case .container: .container
        case .machine: .machine
        }
    }

    var resourceID: String {
        switch self {
        case .container(let id), .machine(let id):
            id
        }
    }

    var containerCLIArguments: [String] {
        switch self {
        case .container(let id):
            ["container", "exec", "-it", id, "sh"]
        case .machine(let id):
            ["container", "machine", "run", "-n", id, "-i", "-t", "--", "sh"]
        }
    }

    var tabTitle: String {
        switch self {
        case .container(let id):
            "Container \(Self.shortID(id))"
        case .machine(let id):
            "Machine \(Self.shortID(id))"
        }
    }

    var systemTerminalWindowTitle: String {
        switch self {
        case .container(let id):
            "\(AppBranding.displayName) - Container \(id)"
        case .machine(let id):
            "\(AppBranding.displayName) - Machine \(id)"
        }
    }

    var systemTerminalScriptFileName: String {
        switch self {
        case .container(let id):
            "container-\(Self.safeFileComponent(id))-exec.command"
        case .machine(let id):
            "machine-\(Self.safeFileComponent(id))-shell.command"
        }
    }

    private static func shortID(_ value: String) -> String {
        let trimmed = value.trimmed
        guard trimmed.count > 16 else { return trimmed }
        return String(trimmed.prefix(12))
    }

    private static func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "resource" : result
    }
}

struct DockerCompatibilityTerminalOpenRequest: Hashable, Sendable {
    var workingDirectory: URL
    var shellTarget: TerminalShellTarget?

    init(
        workingDirectory: URL = AppPaths.homeDirectory,
        shellTarget: TerminalShellTarget? = nil
    ) {
        self.workingDirectory = workingDirectory.standardizedFileURL
        self.shellTarget = shellTarget
    }
}
