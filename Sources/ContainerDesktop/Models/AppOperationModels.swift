import Foundation

enum AppOperationDomain: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case image
    case compose

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .image:
            language.resolved == .zhHans ? "镜像" : "Image"
        case .compose:
            "Compose"
        }
    }
}

enum AppOperationStatus: String, Codable, Hashable, Sendable {
    case running
    case succeeded
    case failed

    var isFinished: Bool {
        self == .succeeded || self == .failed
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .running:
            language.resolved == .zhHans ? "运行中" : "Running"
        case .succeeded:
            language.resolved == .zhHans ? "成功" : "Succeeded"
        case .failed:
            language.resolved == .zhHans ? "失败" : "Failed"
        }
    }
}

struct AppOperationRecord: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var domain: AppOperationDomain
    var title: String
    var target: String
    var commandPreview: String
    var status: AppOperationStatus
    var output: String
    var startedAt: Date
    var finishedAt: Date?

    var duration: TimeInterval? {
        guard let finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }

    var outputPreview: String {
        let trimmed = output.trimmed
        guard !trimmed.isEmpty else { return "—" }
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).prefix(2)
        return lines.joined(separator: "\n")
    }

    var durationText: String {
        guard let duration else { return "—" }
        if duration < 1 {
            return "<1s"
        }
        return "\(Int(duration.rounded()))s"
    }
}

enum AppOperationCommandPreview {
    static func make(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).map(quoteIfNeeded).joined(separator: " ")
    }

    private static func quoteIfNeeded(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        let safeCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:@%+=,-")
        if value.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return value
        }
        return ShellEscaper.singleQuoted(value)
    }
}
