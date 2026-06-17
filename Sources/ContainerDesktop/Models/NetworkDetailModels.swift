import Foundation

enum NetworkDetailTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case metadata
    case inspect

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            language.resolved == .zhHans ? "概览" : "Overview"
        case .metadata:
            language.resolved == .zhHans ? "元数据" : "Metadata"
        case .inspect:
            "Inspect"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .metadata: "tag"
        case .inspect: "curlybraces"
        }
    }
}
