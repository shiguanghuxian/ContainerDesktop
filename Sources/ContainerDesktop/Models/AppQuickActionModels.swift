import Foundation

enum AppQuickActionKind: String, Codable, Hashable, Sendable {
    case navigate
    case execute
    case copyText
    case openURL
    case confirmDestructive
}

enum AppQuickActionGroup: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case pages
    case resources
    case actions
    case copy
    case recentOperations

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .pages:
            language.resolved == .zhHans ? "页面" : "Pages"
        case .resources:
            language.resolved == .zhHans ? "资源" : "Resources"
        case .actions:
            language.resolved == .zhHans ? "动作" : "Actions"
        case .copy:
            language.resolved == .zhHans ? "复制" : "Copy"
        case .recentOperations:
            language.resolved == .zhHans ? "最近操作" : "Recent Operations"
        }
    }
}

enum AppResourceRoute: Hashable, Sendable {
    case container(id: String, tab: ContainerDetailTab?)
    case image(reference: String, tab: ImageDetailTab?)
    case imageTag(reference: String)
    case imagePush(reference: String)
    case volume(name: String, tab: VolumeDetailTab?)
    case network(name: String, tab: NetworkDetailTab?)
    case composeProject(id: ComposeProject.ID?)
    case composeTasks
    case imageTasks
    case operationHistory
}

enum AppNavigationTarget: Hashable, Sendable {
    case section(AppSection)
    case resource(AppResourceRoute)
}

enum AppComposeQuickActionKind: String, Codable, Hashable, Sendable {
    case build
    case up
    case down
    case rebuild

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .build:
            language.resolved == .zhHans ? "Compose 构建" : "Compose build"
        case .up:
            language.resolved == .zhHans ? "Compose 启动" : "Compose up"
        case .down:
            language.resolved == .zhHans ? "Compose 停止" : "Compose down"
        case .rebuild:
            language.resolved == .zhHans ? "Compose 重建" : "Compose rebuild"
        }
    }

    func commandPreview(composePath: URL, options: ComposeOperationOptions) -> String {
        switch self {
        case .build:
            AppOperationCommandPreview.make(executable: "container-compose", arguments: options.buildArguments(composePath: composePath))
        case .up:
            AppOperationCommandPreview.make(executable: "container-compose", arguments: options.upArguments(composePath: composePath))
        case .down:
            AppOperationCommandPreview.make(executable: "container-compose", arguments: options.downArguments(composePath: composePath))
        case .rebuild:
            {
                var buildOptions = options
                buildOptions.noCache = true
                var upOptions = options
                upOptions.buildBeforeUp = true
                upOptions.noCache = true
                let build = AppOperationCommandPreview.make(executable: "container-compose", arguments: buildOptions.buildArguments(composePath: composePath))
                let up = AppOperationCommandPreview.make(executable: "container-compose", arguments: upOptions.upArguments(composePath: composePath))
                return "\(build) && \(up)"
            }()
        }
    }
}

enum AppQuickActionTarget: Hashable, Sendable {
    case navigate(AppNavigationTarget)
    case refreshAll
    case startSystem
    case stopSystem
    case openSettings
    case openDockerTerminal
    case startContainer(String)
    case stopContainer(String)
    case restartContainer(String)
    case runContainerImage(String)
    case runTemplate(DeveloperRunTemplate.ID)
    case pullImage(String)
    case tagImage(String)
    case pushImage(String)
    case compose(AppComposeQuickActionKind, projectID: ComposeProject.ID, serviceName: String?)
    case copyText(String)
    case openURL(String)
    case openOperationHistory
    case confirmDestructive(String)
}

struct AppQuickAction: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var systemImage: String
    var group: AppQuickActionGroup
    var kind: AppQuickActionKind
    var target: AppQuickActionTarget
    var keywords: [String]
    var rank: Int

    var searchText: String {
        ([title, subtitle] + keywords)
            .joined(separator: " ")
            .lowercased()
    }
}

enum AppQuickActionSearch {
    static func filter(_ actions: [AppQuickAction], query: String, limit: Int = 24) -> [AppQuickAction] {
        let tokens = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return Array(actions.sorted(by: actionSort).prefix(limit))
        }

        let ranked = actions.compactMap { action -> (AppQuickAction, Int)? in
            let text = action.searchText
            var score = action.rank
            for token in tokens {
                if action.title.lowercased().hasPrefix(token) {
                    score -= 80
                } else if text.contains(token) {
                    score -= 35
                } else {
                    return nil
                }
            }
            return (action, score)
        }

        return ranked
            .sorted {
                if $0.1 != $1.1 { return $0.1 < $1.1 }
                return actionSort($0.0, $1.0)
            }
            .map(\.0)
            .prefix(limit)
            .map { $0 }
    }

    private static func actionSort(_ lhs: AppQuickAction, _ rhs: AppQuickAction) -> Bool {
        if lhs.group != rhs.group {
            return groupOrder(lhs.group) < groupOrder(rhs.group)
        }
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func groupOrder(_ group: AppQuickActionGroup) -> Int {
        switch group {
        case .pages: 0
        case .resources: 1
        case .actions: 2
        case .copy: 3
        case .recentOperations: 4
        }
    }
}

@MainActor
enum AppQuickActionBuilder {
    static func make(
        language: AppLanguage,
        runtimeStore: RuntimeStore,
        composeStore: ComposeProjectStore,
        operationStore: AppOperationStore
    ) -> [AppQuickAction] {
        var actions: [AppQuickAction] = []
        actions.append(contentsOf: pageActions(language: language))
        actions.append(contentsOf: commandActions(language: language, runtimeStore: runtimeStore))
        actions.append(contentsOf: templateActions(language: language))
        actions.append(contentsOf: containerActions(language: language, runtimeStore: runtimeStore))
        actions.append(contentsOf: imageActions(language: language, runtimeStore: runtimeStore))
        actions.append(contentsOf: volumeActions(language: language, runtimeStore: runtimeStore))
        actions.append(contentsOf: composeActions(language: language, composeStore: composeStore))
        actions.append(contentsOf: operationActions(language: language, operationStore: operationStore))
        return actions
    }

    private static func pageActions(language: AppLanguage) -> [AppQuickAction] {
        AppSection.allCases.map { section in
            AppQuickAction(
                id: "page.\(section.rawValue)",
                title: section.title(language: language),
                subtitle: section.subtitle(language: language),
                systemImage: section.symbolName,
                group: .pages,
                kind: .navigate,
                target: .navigate(.section(section)),
                keywords: [section.rawValue, section.title, section.subtitle],
                rank: 20
            )
        }
    }

    private static func commandActions(language: AppLanguage, runtimeStore: RuntimeStore) -> [AppQuickAction] {
        let isChinese = language.resolved == .zhHans
        var actions = [
            AppQuickAction(
                id: "command.refresh",
                title: language.t(.refresh),
                subtitle: isChinese ? "刷新所有 container 资源" : "Refresh all container resources",
                systemImage: "arrow.clockwise",
                group: .actions,
                kind: .execute,
                target: .refreshAll,
                keywords: ["refresh", "reload", "刷新"],
                rank: 0
            ),
            AppQuickAction(
                id: "command.terminal",
                title: isChinese ? "打开 Docker 兼容终端" : "Open Docker Compatibility Terminal",
                subtitle: "docker / container",
                systemImage: "terminal",
                group: .actions,
                kind: .execute,
                target: .openDockerTerminal,
                keywords: ["terminal", "docker", "container", "终端"],
                rank: 2
            ),
            AppQuickAction(
                id: "command.settings",
                title: language.t(.settings),
                subtitle: language.t(.engineConfig),
                systemImage: "gearshape",
                group: .actions,
                kind: .execute,
                target: .openSettings,
                keywords: ["settings", "config", "设置", "配置"],
                rank: 3
            ),
            AppQuickAction(
                id: "command.operations",
                title: isChinese ? "打开操作历史" : "Open Operation History",
                subtitle: isChinese ? "最近任务、命令和输出摘要" : "Recent tasks, commands, and output",
                systemImage: "clock.arrow.circlepath",
                group: .actions,
                kind: .navigate,
                target: .openOperationHistory,
                keywords: ["history", "tasks", "operation", "任务", "历史"],
                rank: 4
            ),
            AppQuickAction(
                id: "command.image-tasks",
                title: isChinese ? "打开镜像任务" : "Open Image Tasks",
                subtitle: isChinese ? "镜像拉取、构建、导入导出任务" : "Image pull, build, import, and export tasks",
                systemImage: "photo.stack",
                group: .actions,
                kind: .navigate,
                target: .navigate(.resource(.imageTasks)),
                keywords: ["image", "tasks", "history", "镜像", "任务"],
                rank: 5
            ),
            AppQuickAction(
                id: "command.compose-tasks",
                title: isChinese ? "打开 Compose 任务" : "Open Compose Tasks",
                subtitle: isChinese ? "Compose up/down/build 输出" : "Compose up, down, and build output",
                systemImage: "square.stack.3d.up",
                group: .actions,
                kind: .navigate,
                target: .navigate(.resource(.composeTasks)),
                keywords: ["compose", "tasks", "history", "任务"],
                rank: 6
            ),
        ]

        if runtimeStore.environment.systemRunning {
            actions.append(AppQuickAction(
                id: "command.stop-system",
                title: language.t(.stopSystem),
                subtitle: "container system stop",
                systemImage: "stop.circle",
                group: .actions,
                kind: .execute,
                target: .stopSystem,
                keywords: ["stop", "system", "停止"],
                rank: 1
            ))
        } else {
            actions.append(AppQuickAction(
                id: "command.start-system",
                title: language.t(.startSystem),
                subtitle: "container system start",
                systemImage: "play.circle",
                group: .actions,
                kind: .execute,
                target: .startSystem,
                keywords: ["start", "system", "启动"],
                rank: 1
            ))
        }
        return actions
    }

    private static func templateActions(language: AppLanguage) -> [AppQuickAction] {
        DeveloperRunTemplate.allCases.map { template in
            AppQuickAction(
                id: "template.\(template.id)",
                title: language.resolved == .zhHans ? "按模板运行 \(template.title)" : "Run \(template.title)",
                subtitle: template.summary(language: language),
                systemImage: template.systemImage,
                group: .actions,
                kind: .execute,
                target: .runTemplate(template.id),
                keywords: template.searchKeywords,
                rank: 22
            )
        }
    }

    private static func containerActions(language: AppLanguage, runtimeStore: RuntimeStore) -> [AppQuickAction] {
        let isChinese = language.resolved == .zhHans
        var actions: [AppQuickAction] = []
        for container in runtimeStore.containers.prefix(120) {
            actions.append(AppQuickAction(
                id: "container.\(container.id).open",
                title: container.id,
                subtitle: "\(container.imageName) · \(container.state)",
                systemImage: "shippingbox",
                group: .resources,
                kind: .navigate,
                target: .navigate(.resource(.container(id: container.id, tab: nil))),
                keywords: [container.id, container.imageName, container.state, "container", "容器"],
                rank: 40
            ))

            for tab in ContainerDetailTab.allCases {
                actions.append(AppQuickAction(
                    id: "container.\(container.id).tab.\(tab.rawValue)",
                    title: "\(tab.title(language: language)) · \(container.id)",
                    subtitle: container.imageName,
                    systemImage: tab.systemImage,
                    group: .actions,
                    kind: .navigate,
                    target: .navigate(.resource(.container(id: container.id, tab: tab))),
                    keywords: [container.id, container.imageName, tab.rawValue, tab.title(language: language)],
                    rank: 55
                ))
            }

            let lifecycle: [(String, String, String, AppQuickActionTarget, Bool)] = [
                (isChinese ? "启动容器" : "Start container", "play.fill", "start", .startContainer(container.id), container.state != "running"),
                (isChinese ? "停止容器" : "Stop container", "stop.fill", "stop", .stopContainer(container.id), container.state == "running"),
                (isChinese ? "重启容器" : "Restart container", "arrow.clockwise", "restart", .restartContainer(container.id), container.state == "running"),
            ]
            for (title, icon, keyword, target, enabled) in lifecycle where enabled {
                actions.append(AppQuickAction(
                    id: "container.\(container.id).\(keyword)",
                    title: "\(title) · \(container.id)",
                    subtitle: container.imageName,
                    systemImage: icon,
                    group: .actions,
                    kind: .execute,
                    target: target,
                    keywords: [container.id, container.imageName, keyword],
                    rank: 45
                ))
            }

            for target in runtimeStore.browserPortTargets(for: container).prefix(10) {
                actions.append(AppQuickAction(
                    id: "container.\(container.id).port.\(target.id)",
                    title: portActionTitle(target, language: language),
                    subtitle: "\(container.id) · \(target.endpointText)",
                    systemImage: target.systemImage,
                    group: target.action == .openURL ? .actions : .copy,
                    kind: target.action == .openURL ? .openURL : .copyText,
                    target: target.action == .openURL ? .openURL(target.url?.absoluteString ?? "") : .copyText(target.copyValue ?? ""),
                    keywords: [container.id, container.imageName, target.title, target.endpointText],
                    rank: 38
                ))
            }
        }
        return actions
    }

    private static func imageActions(language: AppLanguage, runtimeStore: RuntimeStore) -> [AppQuickAction] {
        let isChinese = language.resolved == .zhHans
        return runtimeStore.images.prefix(160).flatMap { image in
            [
                AppQuickAction(
                    id: "image.\(image.reference).open",
                    title: image.reference,
                    subtitle: image.sizeDisplay,
                    systemImage: "photo.stack",
                    group: .resources,
                    kind: .navigate,
                    target: .navigate(.resource(.image(reference: image.reference, tab: nil))),
                    keywords: [image.reference, image.tag, image.digest, "image", "镜像"],
                    rank: 42
                ),
                AppQuickAction(
                    id: "image.\(image.reference).run",
                    title: isChinese ? "运行镜像 · \(image.reference)" : "Run image · \(image.reference)",
                    subtitle: "container run -d \(image.reference)",
                    systemImage: "play.circle",
                    group: .actions,
                    kind: .execute,
                    target: .runContainerImage(image.reference),
                    keywords: [image.reference, "run", "运行"],
                    rank: 50
                ),
                AppQuickAction(
                    id: "image.\(image.reference).pull",
                    title: isChinese ? "拉取镜像 · \(image.reference)" : "Pull image · \(image.reference)",
                    subtitle: "container image pull \(image.reference)",
                    systemImage: "arrow.down.circle",
                    group: .actions,
                    kind: .execute,
                    target: .pullImage(image.reference),
                    keywords: [image.reference, "pull", "update", "拉取", "更新"],
                    rank: 51
                ),
                AppQuickAction(
                    id: "image.\(image.reference).tag",
                    title: isChinese ? "标记镜像 · \(image.reference)" : "Tag image · \(image.reference)",
                    subtitle: isChinese ? "打开已预填的 tag 表单" : "Open the prefilled tag form",
                    systemImage: "tag",
                    group: .actions,
                    kind: .execute,
                    target: .tagImage(image.reference),
                    keywords: [image.reference, "tag", "retag", "标记"],
                    rank: 52
                ),
                AppQuickAction(
                    id: "image.\(image.reference).push",
                    title: isChinese ? "推送镜像 · \(image.reference)" : "Push image · \(image.reference)",
                    subtitle: isChinese ? "打开已预填的 push 表单" : "Open the prefilled push form",
                    systemImage: "arrow.up.circle",
                    group: .actions,
                    kind: .execute,
                    target: .pushImage(image.reference),
                    keywords: [image.reference, "push", "registry", "推送"],
                    rank: 53
                ),
                AppQuickAction(
                    id: "image.\(image.reference).copy",
                    title: isChinese ? "复制镜像引用" : "Copy image reference",
                    subtitle: image.reference,
                    systemImage: "doc.on.doc",
                    group: .copy,
                    kind: .copyText,
                    target: .copyText(image.reference),
                    keywords: [image.reference, "copy", "复制"],
                    rank: 58
                ),
            ]
        }
    }

    private static func volumeActions(language: AppLanguage, runtimeStore: RuntimeStore) -> [AppQuickAction] {
        runtimeStore.volumes.prefix(120).flatMap { volume in
            [
                AppQuickAction(
                    id: "volume.\(volume.name).open",
                    title: volume.name,
                    subtitle: "\(volume.typeText) · \(volume.sizeDisplay)",
                    systemImage: "externaldrive",
                    group: .resources,
                    kind: .navigate,
                    target: .navigate(.resource(.volume(name: volume.name, tab: nil))),
                    keywords: [volume.name, volume.source, "volume", "卷"],
                    rank: 46
                ),
                AppQuickAction(
                    id: "volume.\(volume.name).files",
                    title: language.resolved == .zhHans ? "打开卷文件 · \(volume.name)" : "Open volume files · \(volume.name)",
                    subtitle: volume.source,
                    systemImage: "folder",
                    group: .actions,
                    kind: .navigate,
                    target: .navigate(.resource(.volume(name: volume.name, tab: .files))),
                    keywords: [volume.name, volume.source, "files", "文件"],
                    rank: 58
                ),
                AppQuickAction(
                    id: "volume.\(volume.name).source",
                    title: language.resolved == .zhHans ? "复制卷源目录" : "Copy volume source path",
                    subtitle: volume.source,
                    systemImage: "doc.on.doc",
                    group: .copy,
                    kind: .copyText,
                    target: .copyText(volume.source),
                    keywords: [volume.name, volume.source, "copy", "path"],
                    rank: 60
                ),
            ]
        }
    }

    private static func composeActions(language: AppLanguage, composeStore: ComposeProjectStore) -> [AppQuickAction] {
        var actions: [AppQuickAction] = []
        for project in composeStore.projects.prefix(80) {
            actions.append(AppQuickAction(
                id: "compose.\(project.id).open",
                title: project.name,
                subtitle: project.path.path,
                systemImage: "square.stack.3d.up",
                group: .resources,
                kind: .navigate,
                target: .navigate(.resource(.composeProject(id: project.id))),
                keywords: [project.name, project.path.path, "compose"],
                rank: 44
            ))

            for action in [AppComposeQuickActionKind.up, .build, .down] {
                actions.append(AppQuickAction(
                    id: "compose.\(project.id).\(action.id)",
                    title: "\(action.title(language: language)) · \(project.name)",
                    subtitle: action.commandPreview(composePath: project.path, options: ComposeOperationOptions()),
                    systemImage: action == .down ? "stop.circle" : "play.circle",
                    group: .actions,
                    kind: action == .down ? .confirmDestructive : .execute,
                    target: .compose(action, projectID: project.id, serviceName: nil),
                    keywords: [project.name, action.id, "compose"],
                    rank: 48
                ))
            }

            for service in project.services.prefix(12) {
                for action in [AppComposeQuickActionKind.up, .build, .down] {
                    actions.append(AppQuickAction(
                        id: "compose.\(project.id).service.\(service.name).\(action.id)",
                        title: "\(action.title(language: language)) · \(service.name)",
                        subtitle: project.name,
                        systemImage: action == .down ? "stop.circle" : "play.circle",
                        group: .actions,
                        kind: action == .down ? .confirmDestructive : .execute,
                        target: .compose(action, projectID: project.id, serviceName: service.name),
                        keywords: [project.name, service.name, action.id, "compose"],
                        rank: 54
                    ))
                }
            }
        }
        return actions
    }

    private static func operationActions(language: AppLanguage, operationStore: AppOperationStore) -> [AppQuickAction] {
        operationStore.records.prefix(20).map { record in
            AppQuickAction(
                id: "operation.\(record.id)",
                title: record.title,
                subtitle: "\(record.status.title(language: language)) · \(record.target)",
                systemImage: record.status == .failed ? "exclamationmark.triangle" : "clock.arrow.circlepath",
                group: .recentOperations,
                kind: .copyText,
                target: .copyText(record.diagnosticReport(language: language)),
                keywords: [record.title, record.target, record.commandPreview, record.outputPreview],
                rank: record.status == .failed ? 25 : 70
            )
        }
    }

    private static func portActionTitle(_ target: ContainerBrowserPortTarget, language: AppLanguage) -> String {
        switch target.action {
        case .openURL:
            return language.resolved == .zhHans ? "打开 \(target.title)" : "Open \(target.title)"
        case .copyURL:
            return language.resolved == .zhHans ? "复制 URL · \(target.title)" : "Copy URL · \(target.title)"
        case .copyAddress:
            return language.resolved == .zhHans ? "复制地址 · \(target.title)" : "Copy address · \(target.title)"
        case .copyConnectionString:
            return language.resolved == .zhHans ? "复制连接串 · \(target.title)" : "Copy connection string · \(target.title)"
        case .copyEnvironmentSnippet:
            return language.resolved == .zhHans ? "复制环境变量 · \(target.title)" : "Copy env snippet · \(target.title)"
        case .copyCLICommand:
            return language.resolved == .zhHans ? "复制客户端命令 · \(target.title)" : "Copy client command · \(target.title)"
        case .copyHealthCheckCommand:
            return language.resolved == .zhHans ? "复制检查命令 · \(target.title)" : "Copy check command · \(target.title)"
        }
    }
}
