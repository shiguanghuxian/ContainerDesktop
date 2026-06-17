import AppKit
import SwiftUI

struct TerminalColorComponents: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct TerminalStyleConfiguration: Equatable {
    var foreground: TerminalColorComponents
    var background: TerminalColorComponents
    var caret: TerminalColorComponents
    var caretText: TerminalColorComponents
    var selection: TerminalColorComponents
    var fontSize: CGFloat

    static let containerDefault = TerminalStyleConfiguration(
        foreground: TerminalColorComponents(red: 0.82, green: 0.94, blue: 0.88),
        background: TerminalColorComponents(red: 0.035, green: 0.045, blue: 0.055),
        caret: TerminalColorComponents(red: 1, green: 1, blue: 1),
        caretText: TerminalColorComponents(red: 0.035, green: 0.045, blue: 0.055),
        selection: TerminalColorComponents(red: 0.16, green: 0.46, blue: 0.72, alpha: 0.58),
        fontSize: 12
    )
}

enum DockerCompatibilityTerminalStyle: String, CaseIterable, Identifiable {
    case containerDark
    case graphite
    case classicGreen
    case amber
    case paper

    static let defaultsKey = "containerdesktop.dockerCompatibilityTerminal.style"
    static let defaultStyle: DockerCompatibilityTerminalStyle = .containerDark

    var id: String { rawValue }

    var configuration: TerminalStyleConfiguration {
        switch self {
        case .containerDark:
            .containerDefault
        case .graphite:
            TerminalStyleConfiguration(
                foreground: TerminalColorComponents(red: 0.86, green: 0.89, blue: 0.92),
                background: TerminalColorComponents(red: 0.06, green: 0.065, blue: 0.075),
                caret: TerminalColorComponents(red: 0.45, green: 0.85, blue: 1),
                caretText: TerminalColorComponents(red: 0.06, green: 0.065, blue: 0.075),
                selection: TerminalColorComponents(red: 0.32, green: 0.48, blue: 0.68, alpha: 0.52),
                fontSize: 12
            )
        case .classicGreen:
            TerminalStyleConfiguration(
                foreground: TerminalColorComponents(red: 0.48, green: 1, blue: 0.56),
                background: TerminalColorComponents(red: 0.005, green: 0.055, blue: 0.025),
                caret: TerminalColorComponents(red: 0.72, green: 1, blue: 0.42),
                caretText: TerminalColorComponents(red: 0.005, green: 0.055, blue: 0.025),
                selection: TerminalColorComponents(red: 0.1, green: 0.44, blue: 0.2, alpha: 0.62),
                fontSize: 12
            )
        case .amber:
            TerminalStyleConfiguration(
                foreground: TerminalColorComponents(red: 1, green: 0.76, blue: 0.38),
                background: TerminalColorComponents(red: 0.115, green: 0.065, blue: 0.025),
                caret: TerminalColorComponents(red: 1, green: 0.92, blue: 0.58),
                caretText: TerminalColorComponents(red: 0.115, green: 0.065, blue: 0.025),
                selection: TerminalColorComponents(red: 0.62, green: 0.34, blue: 0.12, alpha: 0.58),
                fontSize: 12
            )
        case .paper:
            TerminalStyleConfiguration(
                foreground: TerminalColorComponents(red: 0.07, green: 0.09, blue: 0.11),
                background: TerminalColorComponents(red: 0.95, green: 0.96, blue: 0.94),
                caret: TerminalColorComponents(red: 0.04, green: 0.24, blue: 0.58),
                caretText: TerminalColorComponents(red: 0.95, green: 0.96, blue: 0.94),
                selection: TerminalColorComponents(red: 0.32, green: 0.55, blue: 0.86, alpha: 0.34),
                fontSize: 12
            )
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .containerDark:
            language.resolved == .zhHans ? "Container 深色" : "Container Dark"
        case .graphite:
            language.resolved == .zhHans ? "石墨" : "Graphite"
        case .classicGreen:
            language.resolved == .zhHans ? "经典绿屏" : "Classic Green"
        case .amber:
            language.resolved == .zhHans ? "琥珀" : "Amber"
        case .paper:
            language.resolved == .zhHans ? "浅色纸面" : "Paper"
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .containerDark:
            language.resolved == .zhHans ? "默认容器终端配色" : "Default container terminal colors"
        case .graphite:
            language.resolved == .zhHans ? "低对比深灰界面" : "Low-contrast dark gray"
        case .classicGreen:
            language.resolved == .zhHans ? "复古绿色命令行" : "Retro green command line"
        case .amber:
            language.resolved == .zhHans ? "暖色日志阅读风格" : "Warm log-reading palette"
        case .paper:
            language.resolved == .zhHans ? "适合明亮环境" : "For bright environments"
        }
    }

    static func stored(in defaults: UserDefaults = .containerDesktopShared) -> DockerCompatibilityTerminalStyle {
        let rawValue = defaults.string(forKey: defaultsKey) ?? defaultStyle.rawValue
        return DockerCompatibilityTerminalStyle(rawValue: rawValue) ?? defaultStyle
    }
}
