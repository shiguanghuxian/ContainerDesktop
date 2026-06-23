import Foundation

enum LaunchAtLoginStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable(String)
    case unknown(String)

    var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .notRegistered, .unavailable, .unknown:
            false
        }
    }

    var canToggle: Bool {
        switch self {
        case .notRegistered, .enabled, .requiresApproval:
            true
        case .unavailable, .unknown:
            false
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .notRegistered:
            language.resolved == .zhHans ? "已关闭" : "Off"
        case .enabled:
            language.resolved == .zhHans ? "已开启" : "On"
        case .requiresApproval:
            language.resolved == .zhHans ? "需要系统批准" : "Needs approval"
        case .unavailable:
            language.resolved == .zhHans ? "当前运行方式不可用" : "Unavailable in this launch mode"
        case .unknown:
            language.resolved == .zhHans ? "未知状态" : "Unknown status"
        }
    }

    func message(language: AppLanguage) -> String {
        switch self {
        case .notRegistered:
            return language.resolved == .zhHans ? "登录 macOS 后不会自动打开应用。" : "The app will not open automatically after macOS login."
        case .enabled:
            return language.resolved == .zhHans ? "登录 macOS 后会自动打开主窗口。" : "The main window will open automatically after macOS login."
        case .requiresApproval:
            return language.resolved == .zhHans
                ? "请在系统设置的登录项中批准 \(AppBranding.displayName)。"
                : "Approve \(AppBranding.displayName) in System Settings Login Items."
        case .unavailable(let detail):
            if detail.isEmpty {
                return language.resolved == .zhHans
                    ? "请从标准 .app 应用包启动后再设置开机自启。"
                    : "Launch from the standard .app bundle before changing this setting."
            }
            return language.resolved == .zhHans
                ? "请从标准 .app 应用包启动后再设置开机自启。\(detail)"
                : "Launch from the standard .app bundle before changing this setting. \(detail)"
        case .unknown(let rawStatus):
            return language.resolved == .zhHans
                ? "macOS 返回了未知登录项状态：\(rawStatus)。"
                : "macOS returned an unknown login item status: \(rawStatus)."
        }
    }
}
