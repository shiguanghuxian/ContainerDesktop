import Foundation

enum VolumeDetailTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case files
    case metadata
    case inspect

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            language.t(.overview)
        case .files:
            language.resolved == .zhHans ? "文件" : "Files"
        case .metadata:
            language.resolved == .zhHans ? "元数据" : "Metadata"
        case .inspect:
            "Inspect"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .files: "folder"
        case .metadata: "tag"
        case .inspect: "curlybraces"
        }
    }
}
