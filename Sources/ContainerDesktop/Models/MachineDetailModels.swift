import Foundation

enum MachineDetailTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case logs
    case inspect
    case exec
    case run
    case settings

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            language.t(.overview)
        case .logs:
            language.t(.logs)
        case .inspect:
            "Inspect"
        case .exec:
            "Exec"
        case .run:
            "Run"
        case .settings:
            language.resolved == .zhHans ? "配置" : "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .logs: "doc.plaintext"
        case .inspect: "curlybraces"
        case .exec: "terminal"
        case .run: "play.rectangle"
        case .settings: "slider.horizontal.3"
        }
    }
}

enum MachineHomeMountOption: String, CaseIterable, Identifiable, Hashable {
    case rw
    case ro
    case none

    var id: String { rawValue }
    var title: String { rawValue }
}
