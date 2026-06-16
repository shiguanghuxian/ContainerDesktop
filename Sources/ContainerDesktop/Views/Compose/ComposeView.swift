import SwiftUI
import UniformTypeIdentifiers

private enum ComposeActiveDrawer: Equatable {
    case project(ComposeProject.ID)
    case tasks
}

struct ComposeView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore
    @Bindable var operationStore: AppOperationStore
    @Bindable var statsHistoryStore: ContainerStatsHistoryStore

    @State private var showImporter = false
    @State private var searchText = ""
    @State private var expandedProjectIDs: Set<ComposeProject.ID> = []
    @State private var activeDrawer: ComposeActiveDrawer?
    @State private var detailContainerID: String?
    @State private var pendingRemove: ComposeProject?
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var serviceObservationStore = ComposeServiceObservationStore()
    @State private var noCacheBuild = false
    @State private var composeBuildBeforeUp = false
    @State private var composeInteractive = false
    @State private var composeTTY = false
    @State private var composeUser = ""
    @State private var composeWorkdir = ""
    @State private var composeEnvText = ""
    @State private var composeEnvFilesText = ""
    @State private var composeUlimitsText = ""
    @State private var activeComposeOperationKey: String?
    @State private var activeComposeContainerActionKey: String?

    private var composeTypes: [UTType] {
        [
            UTType(filenameExtension: "yml") ?? .data,
            UTType(filenameExtension: "yaml") ?? .data,
            .data,
        ]
    }

    private var selectedProject: ComposeProject? {
        guard case .project(let projectID) = activeDrawer else { return nil }
        return composeStore.projects.first { $0.id == projectID }
    }

    private var detailContainer: ContainerSummary? {
        guard let detailContainerID else { return nil }
        return runtimeStore.containers.first { $0.id == detailContainerID }
    }

    private var filteredProjects: [ComposeProject] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return composeStore.projects }
        return composeStore.projects.filter {
            $0.name.lowercased().contains(query)
                || $0.path.path.lowercased().contains(query)
                || $0.services.contains { $0.name.lowercased().contains(query) }
        }
    }

    private var isDrawerPresented: Bool {
        activeDrawer != nil
    }

    private var drawerWidth: CGFloat {
        activeDrawer == .tasks ? 620 : 430
    }

    var body: some View {
        Group {
            if let container = detailContainer {
                ContainerDetailPage(
                    runtimeStore: runtimeStore,
                    statsHistoryStore: statsHistoryStore,
                    containerID: detailContainerID ?? container.id,
                    parentTitle: language.t(.compose),
                    isPresented: Binding(
                        get: { detailContainerID != nil },
                        set: { if !$0 { detailContainerID = nil } }
                    )
                )
            } else {
                DrawerPageLayout(
                    isDrawerPresented: isDrawerPresented,
                    onDismiss: closeActiveDrawer,
                    drawerWidth: drawerWidth
                ) {
                    pageContent
                } drawer: {
                    switch activeDrawer {
                    case .project:
                        if let selectedProject {
                            projectDetailDrawer(selectedProject)
                        }
                    case .tasks:
                        ComposeTasksDrawer(
                            operationStore: operationStore,
                            statusMessage: composeStore.errorMessage?.nilIfBlank,
                            statusIsError: composeStore.errorMessage?.nilIfBlank != nil,
                            lastOutput: composeStore.lastOutput,
                            onClose: closeActiveDrawer
                        )
                    case nil:
                        EmptyView()
                    }
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: composeTypes, allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await composeStore.addProject(fileURL: url) }
        }
        .alert("移除 Compose 项目？", isPresented: Binding(
            get: { pendingRemove != nil },
            set: { if !$0 { pendingRemove = nil } }
        )) {
            if let project = pendingRemove {
                Button(language.t(.remove), role: .destructive) {
                    composeStore.removeProject(project)
                    pendingRemove = nil
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会从 \(AppBranding.displayName) 列表中移除 \(pendingRemove?.name ?? "该项目")，不会删除文件。")
        }
    }

    private func projectDetailDrawer(_ selectedProject: ComposeProject) -> some View {
        DetailDrawer(
            mode: $drawerMode,
            title: selectedProject.name,
            subtitle: selectedProject.path.path,
            systemImage: "square.stack.3d.up",
            rawText: rawComposeText(for: selectedProject),
            rawLabel: "YAML",
            onClose: closeActiveDrawer
        ) {
            ComposeProjectOverview(
                project: selectedProject,
                runtimeSummaries: selectedProject.runtimeSummaries(containers: runtimeStore.containers),
                lastOutput: composeStore.lastOutput,
                observationStore: serviceObservationStore,
                onOpenContainer: { container in
                    detailContainerID = container.id
                },
                onOpenServiceTerminal: { summary in
                    openServiceTerminal(summary)
                },
                onObserveProject: { summaries in
                    Task {
                        await serviceObservationStore.loadProject(
                            projectName: selectedProject.name,
                            summaries: summaries
                        )
                    }
                },
                onObserveService: { summary in
                    Task {
                        await serviceObservationStore.load(summary: summary)
                    }
                },
                isComposeAvailable: runtimeStore.environment.containerComposeAvailable,
                activeOperationKey: activeComposeOperationKey,
                activeContainerActionKey: activeComposeContainerActionKey,
                onStartContainers: { summary in
                    runComposeContainerAction(.start, project: selectedProject, summary: summary)
                },
                onStopContainers: { summary in
                    runComposeContainerAction(.stop, project: selectedProject, summary: summary)
                },
                onRestartContainers: { summary in
                    runComposeContainerAction(.restart, project: selectedProject, summary: summary)
                },
                onBuildService: { service in
                    runComposeOperation(.build, project: selectedProject, services: [service.name])
                },
                onUpService: { service in
                    runComposeOperation(.up, project: selectedProject, services: [service.name])
                },
                onDownService: { service in
                    runComposeOperation(.down, project: selectedProject, services: [service.name])
                },
                onRebuildService: { service in
                    runComposeOperation(.rebuild, project: selectedProject, services: [service.name])
                }
            )
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.compose),
                subtitle: language.t(.composeSubtitle),
                systemImage: "square.stack.3d.up"
            ) {
                HStack(spacing: 8) {
                    Button {
                        showImporter = true
                    } label: {
                        Label(language.t(.addProject), systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help(language.resolved == .zhHans ? "添加 Compose 项目" : "Add Compose project")
                    Button {
                        Task { await composeStore.reloadProjects() }
                    } label: {
                        Label(language.t(.reload), systemImage: "arrow.clockwise")
                    }
                    .help(language.resolved == .zhHans ? "重新加载 Compose 项目" : "Reload Compose projects")
                    Button {
                        Task { await composeStore.refreshVersion() }
                    } label: {
                        Label(language.t(.version), systemImage: "number")
                    }
                    .help(language.resolved == .zhHans ? "刷新 Compose 版本" : "Refresh Compose version")
                    Button {
                        openTasksDrawer()
                    } label: {
                        Label(language.resolved == .zhHans ? "Compose 任务" : "Compose Tasks", systemImage: "clock.arrow.circlepath")
                    }
                    .help(language.resolved == .zhHans ? "打开 Compose 任务列表" : "Open Compose tasks")
                }
            }

            HStack(spacing: 10) {
                Toggle("--no-cache", isOn: $noCacheBuild)
                    .toggleStyle(.switch)
                Toggle("-b / --build", isOn: $composeBuildBeforeUp)
                    .toggleStyle(.switch)
                Toggle("-i", isOn: $composeInteractive)
                    .toggleStyle(.switch)
                Toggle("-t", isOn: $composeTTY)
                    .toggleStyle(.switch)
                StatusPill(title: composeStore.composeVersion, systemImage: "square.stack.3d.up", tint: CDTheme.dockerBlue)
                    .lineLimit(1)
                Spacer()
            }

            DisclosureGroup(language.resolved == .zhHans ? "Compose 运行参数" : "Compose Operation Options") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        TextField("-u / --user", text: $composeUser)
                            .textFieldStyle(.roundedBorder)
                        TextField("-w / --workdir", text: $composeWorkdir)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("-e / --env, one per line", text: $composeEnvText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    TextField("--env-file, one per line", text: $composeEnvFilesText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    TextField("--ulimit, one per line", text: $composeUlimitsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                .padding(.top, 8)
            }

            if let errorMessage = composeStore.errorMessage?.nilIfBlank {
                StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            if let warning = staleSystemImageConfigurationWarning {
                StatusBanner(text: warning, systemImage: "hammer.circle", tint: CDTheme.violet)
            }

            if !runtimeStore.environment.containerComposeAvailable {
                DependencyInstallGuideView(environment: runtimeStore.environment) {
                    Task {
                        await runtimeStore.refreshAll()
                        await composeStore.refreshVersion()
                    }
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Text(language.itemCount(filteredProjects.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ResourceTable {
                projectHeader
            } rows: {
                if filteredProjects.isEmpty {
                    EmptyStateView(title: language.t(.noCompose), message: "添加 compose.yml 或 docker-compose.yml 后，可预览服务并运行 up/down/build。", systemImage: "square.stack.3d.up")
                        .padding(18)
                } else {
                    ForEach(filteredProjects) { project in
                        let runtimeSummaries = project.runtimeSummaries(containers: runtimeStore.containers)
                        VStack(spacing: 0) {
                            ResourceTableRow(isSelected: selectedProject?.id == project.id) {
                                let buildKey = composeOperationKey(action: .build, projectID: project.id)
                                let rebuildKey = composeOperationKey(action: .rebuild, projectID: project.id)
                                let upKey = composeOperationKey(action: .up, projectID: project.id)
                                let downKey = composeOperationKey(action: .down, projectID: project.id)

                                Button {
                                    toggleExpanded(project)
                                } label: {
                                    Image(systemName: expandedProjectIDs.contains(project.id) ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(CDTheme.dockerBlue)
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help(expandedProjectIDs.contains(project.id)
                                    ? (language.resolved == .zhHans ? "收起服务容器" : "Collapse service containers")
                                    : (language.resolved == .zhHans ? "展开服务容器" : "Expand service containers"))

                                ResourceStatusDot(tint: composeStore.busyProjectID == project.id ? CDTheme.ember : composeProjectTint(runtimeSummaries))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    Text(project.path.deletingLastPathComponent().path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text("\(project.services.count)")
                                    .font(.callout.monospacedDigit())
                                    .frame(width: 72, alignment: .trailing)

                                StatusPill(
                                    title: composeProjectStatusText(runtimeSummaries),
                                    systemImage: "shippingbox",
                                    tint: composeProjectTint(runtimeSummaries)
                                )
                                .frame(width: 112, alignment: .leading)

                                Text("\(project.volumes.count) / \(project.networks.count)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 96, alignment: .trailing)

                                Text(project.lastModified.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 140, alignment: .leading)

                                HStack(spacing: 7) {
                                    RowActionButton(
                                        systemImage: "sidebar.right",
                                        help: language.resolved == .zhHans ? "打开项目详情抽屉" : "Open project details drawer"
                                    ) {
                                        selectProject(project)
                                    }
                                    RowActionButton(
                                        systemImage: "hammer",
                                        isLoading: activeComposeOperationKey == buildKey,
                                        isDisabled: isComposeOperationBlocked(except: buildKey),
                                        help: language.resolved == .zhHans ? "构建项目镜像" : "Build project images"
                                    ) {
                                        runComposeOperation(.build, project: project)
                                    }
                                    RowActionButton(
                                        systemImage: "arrow.triangle.2.circlepath",
                                        tint: CDTheme.violet,
                                        isLoading: activeComposeOperationKey == rebuildKey,
                                        isDisabled: isComposeOperationBlocked(except: rebuildKey),
                                        help: language.resolved == .zhHans ? "重新构建并启动项目" : "Rebuild and start project"
                                    ) {
                                        runComposeOperation(.rebuild, project: project)
                                    }
                                    RowActionButton(
                                        systemImage: "play.fill",
                                        tint: CDTheme.lime,
                                        isLoading: activeComposeOperationKey == upKey,
                                        isDisabled: isComposeOperationBlocked(except: upKey),
                                        help: language.resolved == .zhHans ? "启动项目" : "Start project"
                                    ) {
                                        runComposeOperation(.up, project: project)
                                    }
                                    RowActionButton(
                                        systemImage: "stop.fill",
                                        tint: CDTheme.ember,
                                        isLoading: activeComposeOperationKey == downKey,
                                        isDisabled: isComposeOperationBlocked(except: downKey),
                                        help: language.resolved == .zhHans ? "停止项目" : "Stop project"
                                    ) {
                                        runComposeOperation(.down, project: project)
                                    }
                                    DestructiveRowActionButton(
                                        help: language.resolved == .zhHans ? "移除项目" : "Remove project"
                                    ) {
                                        pendingRemove = project
                                    }
                                }
                                .frame(width: 208, alignment: .trailing)
                            }

                            if expandedProjectIDs.contains(project.id) {
                                ComposeProjectExpandedRows(
                                    project: project,
                                    runtimeSummaries: runtimeSummaries,
                                    activeContainerActionKey: activeComposeContainerActionKey,
                                    activeRuntimeOperationKey: runtimeStore.activeOperationKey,
                                    onOpenContainer: { container in
                                        detailContainerID = container.id
                                    },
                                    onOpenTerminal: { summary in
                                        openServiceTerminal(summary)
                                    },
                                    onObserveService: { summary in
                                        Task { await serviceObservationStore.load(summary: summary) }
                                    },
                                    onStartContainers: { summary in
                                        runComposeContainerAction(.start, project: project, summary: summary)
                                    },
                                    onStopContainers: { summary in
                                        runComposeContainerAction(.stop, project: project, summary: summary)
                                    },
                                    onRestartContainers: { summary in
                                        runComposeContainerAction(.restart, project: project, summary: summary)
                                    },
                                    onStartContainer: { container in
                                        Task { await runtimeStore.startContainer(container.id) }
                                    },
                                    onStopContainer: { container in
                                        Task { await runtimeStore.stopContainer(container.id) }
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
        }
    }

    private var staleSystemImageConfigurationWarning: String? {
        var warnings: [String] = []
        if composeStore.projects.contains(where: \.hasBuildConfiguredServices),
           ContainerBuilderImageDefaults.isLegacyLatestImageLoosely(systemConfigStore.config.build.image) {
            warnings.append(ContainerBuilderImageDefaults.staleConfigurationWarning(language: language))
        }
        if !composeStore.projects.isEmpty,
           ContainerVminitImageDefaults.isLegacyLatestImageLoosely(systemConfigStore.config.vminit.image) {
            warnings.append(ContainerVminitImageDefaults.staleConfigurationWarning(language: language))
        }
        return warnings.joined(separator: "\n").nilIfBlank
    }

    private var projectHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 28)
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.services), width: 72, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.status), width: 112)
            ResourceTableHeaderLabel(title: "Vol / Net", width: 96, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.modified), width: 140)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 208, alignment: .trailing)
        }
    }

    private func selectProject(_ project: ComposeProject) {
        if activeDrawer != .project(project.id) {
            serviceObservationStore.clear()
        }
        activeDrawer = .project(project.id)
        drawerMode = .overview
    }

    private func openTasksDrawer() {
        serviceObservationStore.clear()
        activeDrawer = .tasks
    }

    private func closeActiveDrawer() {
        if case .project = activeDrawer {
            serviceObservationStore.clear()
        }
        activeDrawer = nil
    }

    private func toggleExpanded(_ project: ComposeProject) {
        withAnimation(.snappy(duration: 0.18)) {
            if expandedProjectIDs.contains(project.id) {
                expandedProjectIDs.remove(project.id)
            } else {
                expandedProjectIDs.insert(project.id)
            }
        }
    }

    private func rawComposeText(for project: ComposeProject) -> String {
        (try? String(contentsOf: project.path, encoding: .utf8)) ?? "Unable to read \(project.path.path)"
    }

    private func composeOptions(services: [String] = []) -> ComposeOperationOptions {
        ComposeOperationOptions(
            services: services,
            buildBeforeUp: composeBuildBeforeUp,
            noCache: noCacheBuild,
            interactive: composeInteractive,
            tty: composeTTY,
            user: composeUser,
            workdir: composeWorkdir,
            env: lines(from: composeEnvText),
            envFiles: lines(from: composeEnvFilesText),
            ulimits: lines(from: composeUlimitsText)
        )
    }

    private func runComposeOperation(_ action: ComposeTaskAction, project: ComposeProject, services: [String] = []) {
        guard runtimeStore.environment.containerComposeAvailable else {
            composeStore.errorMessage = language.t(.emptyInstallCompose)
            composeStore.lastOutput = language.t(.emptyInstallCompose)
            return
        }
        let activeKey = composeOperationKey(action: action, projectID: project.id, services: services)
        guard activeComposeOperationKey == nil else { return }
        activeComposeOperationKey = activeKey

        let options = composeOptions(services: services)
        let id = operationStore.start(
            domain: .compose,
            title: action.title(language: language),
            target: composeOperationTarget(project: project, services: services),
            commandPreview: action.commandPreview(composePath: project.path, options: options)
        )

        Task {
            defer {
                if activeComposeOperationKey == activeKey {
                    activeComposeOperationKey = nil
                }
            }
            switch action {
            case .build:
                await composeStore.build(project, options: options)
            case .up:
                await composeStore.up(project, options: options)
            case .down:
                await composeStore.down(project, options: options)
            case .rebuild:
                await composeStore.rebuild(project, options: options)
            }
            await runtimeStore.refreshAll()
            operationStore.finish(
                id: id,
                status: composeStore.errorMessage == nil ? .succeeded : .failed,
                output: composeStore.lastOutput
            )
        }
    }

    private func isComposeOperationBlocked(except key: String) -> Bool {
        guard runtimeStore.environment.containerComposeAvailable else { return true }
        if let activeComposeOperationKey {
            return activeComposeOperationKey != key
        }
        return composeStore.busyProjectID != nil
    }

    private func runComposeContainerAction(
        _ action: ComposeServiceContainerAction,
        project: ComposeProject,
        summary: ComposeServiceRuntimeSummary
    ) {
        let activeKey = composeContainerOperationKey(projectID: project.id, serviceName: summary.service.name)
        guard activeComposeContainerActionKey == nil else { return }
        activeComposeContainerActionKey = activeKey

        let containerIDs = summary.containers.map(\.id)
        let id = operationStore.start(
            domain: .compose,
            title: action.title(language: language),
            target: "\(project.name) / \(summary.service.name)",
            commandPreview: action.commandPreview(containerIDs: containerIDs)
        )

        Task {
            defer {
                if activeComposeContainerActionKey == activeKey {
                    activeComposeContainerActionKey = nil
                }
            }
            let result: (succeeded: Bool, output: String)
            switch action {
            case .start:
                result = await runtimeStore.startContainers(containerIDs)
            case .stop:
                result = await runtimeStore.stopContainers(containerIDs)
            case .restart:
                result = await runtimeStore.restartContainers(containerIDs)
            }
            operationStore.finish(
                id: id,
                status: result.succeeded ? .succeeded : .failed,
                output: result.output
            )
        }
    }

    private func openServiceTerminal(_ summary: ComposeServiceRuntimeSummary) {
        guard let container = summary.primaryRunningContainer else {
            runtimeStore.errorMessage = language.resolved == .zhHans ? "服务没有运行中的容器，无法进入终端。" : "The service has no running container."
            return
        }

        do {
            try SystemTerminalLauncher.openContainerShell(id: container.id)
        } catch {
            runtimeStore.errorMessage = error.localizedDescription
        }
    }

    private func composeOperationTarget(project: ComposeProject, services: [String]) -> String {
        let resolvedServices = services.map(\.trimmed).filter { !$0.isEmpty }
        guard !resolvedServices.isEmpty else { return project.name }
        return "\(project.name) / \(resolvedServices.joined(separator: ", "))"
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private func composeProjectStatusText(_ summaries: [ComposeServiceRuntimeSummary]) -> String {
        guard !summaries.isEmpty else { return "—" }
        let running = summaries.filter { $0.state == .running || $0.state == .mixed }.count
        return "\(running)/\(summaries.count)"
    }

    private func composeProjectTint(_ summaries: [ComposeServiceRuntimeSummary]) -> Color {
        guard !summaries.isEmpty else { return .secondary }
        if summaries.allSatisfy({ $0.state == .running }) { return CDTheme.lime }
        if summaries.contains(where: { $0.state == .running || $0.state == .mixed }) { return CDTheme.violet }
        if summaries.contains(where: { $0.state == .stopped }) { return CDTheme.ember }
        return .secondary
    }
}

private enum ComposeTaskAction {
    case build
    case up
    case down
    case rebuild

    var id: String {
        switch self {
        case .build: "build"
        case .up: "up"
        case .down: "down"
        case .rebuild: "rebuild"
        }
    }

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
            return AppOperationCommandPreview.make(executable: "container-compose", arguments: options.buildArguments(composePath: composePath))
        case .up:
            return AppOperationCommandPreview.make(executable: "container-compose", arguments: options.upArguments(composePath: composePath))
        case .down:
            return AppOperationCommandPreview.make(executable: "container-compose", arguments: options.downArguments(composePath: composePath))
        case .rebuild:
            var buildOptions = options
            buildOptions.noCache = true
            var upOptions = options
            upOptions.buildBeforeUp = true
            upOptions.noCache = true
            let build = AppOperationCommandPreview.make(executable: "container-compose", arguments: buildOptions.buildArguments(composePath: composePath))
            let up = AppOperationCommandPreview.make(executable: "container-compose", arguments: upOptions.upArguments(composePath: composePath))
            return "\(build) && \(up)"
        }
    }
}

private func composeOperationKey(action: ComposeTaskAction, projectID: String, services: [String] = []) -> String {
    let serviceKey = services.map(\.trimmed).filter { !$0.isEmpty }.joined(separator: ",")
    return "\(projectID):\(action.id):\(serviceKey)"
}

func composeContainerOperationKey(projectID: String, serviceName: String) -> String {
    "\(projectID):containers:\(serviceName)"
}

private extension ComposeProject {
    var hasBuildConfiguredServices: Bool {
        services.contains { $0.buildContext?.nilIfBlank != nil }
    }
}

private struct ComposeProjectOverview: View {
    @Environment(\.appLanguage) private var language
    var project: ComposeProject
    var runtimeSummaries: [ComposeServiceRuntimeSummary]
    var lastOutput: String
    var observationStore: ComposeServiceObservationStore
    var onOpenContainer: (ContainerSummary) -> Void
    var onOpenServiceTerminal: (ComposeServiceRuntimeSummary) -> Void
    var onObserveProject: ([ComposeServiceRuntimeSummary]) -> Void
    var onObserveService: (ComposeServiceRuntimeSummary) -> Void
    var isComposeAvailable: Bool
    var activeOperationKey: String?
    var activeContainerActionKey: String?
    var onStartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStopContainers: (ComposeServiceRuntimeSummary) -> Void
    var onRestartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onBuildService: (ComposeProject.Service) -> Void
    var onUpService: (ComposeProject.Service) -> Void
    var onDownService: (ComposeProject.Service) -> Void
    var onRebuildService: (ComposeProject.Service) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "项目" : "Project") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: project.name)
                    DetailInfoRow(title: language.t(.services), value: "\(project.services.count)")
                    DetailInfoRow(title: language.t(.running), value: runtimeStatusSummary)
                    DetailInfoRow(title: language.t(.volumes), value: project.volumes.isEmpty ? "—" : project.volumes.joined(separator: ", "))
                    DetailInfoRow(title: language.t(.networks), value: project.networks.isEmpty ? "—" : project.networks.joined(separator: ", "))
                    DetailInfoRow(title: language.t(.modified), value: project.lastModified.formatted(date: .abbreviated, time: .shortened))
                    HStack {
                        Spacer()
                        Button {
                            onObserveProject(runtimeSummaries)
                        } label: {
                            Label(language.resolved == .zhHans ? "读取项目日志和 Stats" : "Load project logs and stats", systemImage: "waveform.path.ecg")
                        }
                        .buttonStyle(.bordered)
                        .disabled(projectMatchedContainerCount == 0 || observationStore.isLoading)
                        .help(language.resolved == .zhHans ? "读取项目日志和资源 Stats" : "Load project logs and resource stats")
                    }
                }
            }

            DetailSection(title: language.t(.services)) {
                if project.services.isEmpty {
                    DetailInfoCard {
                        Text("No services")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(project.services) { service in
                        let runtime = runtimeSummaries.first { $0.service.name == service.name }
                        DetailInfoCard {
                            HStack(spacing: 8) {
                                Text(service.name)
                                    .font(.callout.weight(.semibold))
                                if let runtime {
                                    StatusPill(
                                        title: runtime.state.displayText,
                                        systemImage: "shippingbox",
                                        tint: tint(for: runtime.state)
                                    )
                                }
                                Spacer()
                                if let runtime {
                                    ComposeServiceRuntimeMenu(
                                        summary: runtime,
                                        onOpenContainer: onOpenContainer,
                                        onOpenTerminal: onOpenServiceTerminal,
                                        onObserveService: onObserveService,
                                        onStartContainers: onStartContainers,
                                        onStopContainers: onStopContainers,
                                        onRestartContainers: onRestartContainers,
                                        isBusy: activeContainerActionKey == composeContainerOperationKey(projectID: project.id, serviceName: service.name)
                                    )
                                }
                                let buildKey = composeOperationKey(action: .build, projectID: project.id, services: [service.name])
                                let rebuildKey = composeOperationKey(action: .rebuild, projectID: project.id, services: [service.name])
                                let upKey = composeOperationKey(action: .up, projectID: project.id, services: [service.name])
                                let downKey = composeOperationKey(action: .down, projectID: project.id, services: [service.name])
                                RowActionButton(
                                    systemImage: "hammer",
                                    isLoading: activeOperationKey == buildKey,
                                    isDisabled: isOperationBlocked(except: buildKey),
                                    help: language.resolved == .zhHans ? "构建服务镜像" : "Build service image"
                                ) { onBuildService(service) }
                                RowActionButton(
                                    systemImage: "arrow.triangle.2.circlepath",
                                    tint: CDTheme.violet,
                                    isLoading: activeOperationKey == rebuildKey,
                                    isDisabled: isOperationBlocked(except: rebuildKey),
                                    help: language.resolved == .zhHans ? "重新构建并启动服务" : "Rebuild and start service"
                                ) { onRebuildService(service) }
                                RowActionButton(
                                    systemImage: "play.fill",
                                    tint: CDTheme.lime,
                                    isLoading: activeOperationKey == upKey,
                                    isDisabled: isOperationBlocked(except: upKey),
                                    help: language.resolved == .zhHans ? "启动服务" : "Start service"
                                ) { onUpService(service) }
                                RowActionButton(
                                    systemImage: "stop.fill",
                                    tint: CDTheme.ember,
                                    isLoading: activeOperationKey == downKey,
                                    isDisabled: isOperationBlocked(except: downKey),
                                    help: language.resolved == .zhHans ? "停止服务" : "Stop service"
                                ) { onDownService(service) }
                            }
                            DetailInfoRow(title: language.t(.image), value: service.image ?? service.buildContext ?? "—")
                            DetailInfoRow(title: "Ports", value: service.ports.isEmpty ? "—" : service.ports.joined(separator: ", "), monospaced: true)
                            DetailInfoRow(title: "Volumes", value: service.volumes.isEmpty ? "—" : service.volumes.joined(separator: ", "))
                            DetailInfoRow(title: "Env", value: service.environment.isEmpty ? "—" : service.environment.keys.sorted().joined(separator: ", "))
                            DetailInfoRow(title: "Containers", value: runtime?.containerIDsText ?? "—", monospaced: true)
                            DetailInfoRow(title: "Platform", value: service.platform ?? "—")
                            DetailInfoRow(title: "Depends", value: service.dependsOn.isEmpty ? "—" : service.dependsOn.joined(separator: ", "))
                        }
                    }
                }
            }

            ComposeServiceObservationPanel(store: observationStore)

            DetailSection(title: language.t(.commandOutput)) {
                TerminalBlock(text: lastOutput, minHeight: 180)
            }
        }
    }

    private var runtimeStatusSummary: String {
        guard !runtimeSummaries.isEmpty else { return "—" }
        let running = runtimeSummaries.reduce(0) { $0 + $1.runningCount }
        let matched = runtimeSummaries.reduce(0) { $0 + $1.containers.count }
        return "\(running) running / \(matched) containers"
    }

    private var projectMatchedContainerCount: Int {
        Set(runtimeSummaries.flatMap { $0.containers.map(\.id) }).count
    }

    private func tint(for state: ComposeServiceRuntimeState) -> Color {
        switch state {
        case .running:
            CDTheme.lime
        case .mixed:
            CDTheme.violet
        case .stopped:
            CDTheme.ember
        case .missing:
            .secondary
        }
    }

    private func isOperationBlocked(except key: String) -> Bool {
        guard isComposeAvailable else { return true }
        guard let activeOperationKey else { return false }
        return activeOperationKey != key
    }
}
