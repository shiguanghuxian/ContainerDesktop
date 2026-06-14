import Foundation

enum DependencyInstallTarget: String, CaseIterable, Identifiable, Hashable, Sendable {
    case container
    case containerCompose

    var id: String { rawValue }

    static func missing(in environment: EnvironmentProbe) -> [DependencyInstallTarget] {
        var targets: [DependencyInstallTarget] = []
        if !environment.containerAvailable {
            targets.append(.container)
        }
        if !environment.containerComposeAvailable {
            targets.append(.containerCompose)
        }
        return targets
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .container:
            "apple/container"
        case .containerCompose:
            "Container-Compose"
        }
    }

    func description(language: AppLanguage) -> String {
        switch self {
        case .container:
            return language.resolved == .zhHans
                ? "安装 container CLI 和系统服务，安装后会启动 container system。"
                : "Install the container CLI and system service, then start container system."
        case .containerCompose:
            return language.resolved == .zhHans
                ? "安装 container-compose，用于 Compose build、up、down 和 rebuild。"
                : "Install container-compose for Compose build, up, down, and rebuild."
        }
    }

    var systemImage: String {
        switch self {
        case .container: "terminal"
        case .containerCompose: "square.stack.3d.up"
        }
    }

    var documentationURL: URL {
        switch self {
        case .container:
            URL(string: "https://github.com/apple/container")!
        case .containerCompose:
            URL(string: "https://github.com/Mcrich23/Container-Compose")!
        }
    }

    var displayCommand: String {
        switch self {
        case .container:
            """
            CONTAINER_PKG_URL=$(curl -fsSL https://api.github.com/repos/apple/container/releases/latest | /usr/bin/awk -F '"' '/browser_download_url/ && /\\.pkg"/ {print $4; exit}')
            curl -fL "$CONTAINER_PKG_URL" -o /tmp/apple-container.pkg
            sudo installer -pkg /tmp/apple-container.pkg -target /
            container system start
            """
        case .containerCompose:
            "brew update && brew install container-compose"
        }
    }
}
