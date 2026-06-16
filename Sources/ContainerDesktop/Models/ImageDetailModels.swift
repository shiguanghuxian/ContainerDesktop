import Foundation

enum ImageDetailTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case layers
    case inspect

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return language.resolved == .zhHans ? "概览" : "Overview"
        case .layers:
            return language.resolved == .zhHans ? "层" : "Layers"
        case .inspect:
            return "Inspect"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "info.circle"
        case .layers: "square.3.layers.3d"
        case .inspect: "curlybraces"
        }
    }
}
