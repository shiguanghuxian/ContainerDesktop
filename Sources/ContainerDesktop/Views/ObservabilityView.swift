import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ObservabilityView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Binding var resourceSnapshotRequestID: Int?
    @State private var searchText = ""
    @State private var onlyRunning = true
    @State private var composeScope = ObservabilityComposeScope.all
    @State private var logLines = "120"
    @State private var logFilterText = ""
    @State private var logSource: ObservabilityLogSource = .containerStdio
    @State private var systemLogLast = "5m"
    @State private var autoRefresh = false
    @State private var refreshInterval = "10"
    @State private var statsSort: ObservabilityStatsSort = .memory
    @State private var showResourceDrawer = false
    @State private var resourceSampleScopeKey = ""
    @State private var liveLogStore = GlobalLogStreamStore()
    @State private var logPresets: [ObservabilityLogPreset] = ObservabilityLogPresetPersistence.load()
    @State private var logRegexEnabled = false
    @State private var logCaseSensitive = false
    @State private var logErrorOnly = false
    @State private var logSoftWrap = true

    private var scopedContainers: [ContainerSummary] {
        let composeScoped = composeScope.containers(from: runtimeStore.containers, projects: composeStore.projects)
        let base = onlyRunning ? composeScoped.filter { $0.state == "running" } : composeScoped
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.id.lowercased().contains(query)
                || $0.imageName.lowercased().contains(query)
                || $0.state.lowercased().contains(query)
        }
    }

    private var visibleLogsText: String {
        let rawText = liveLogStore.logsText.nilIfBlank ?? runtimeStore.globalLogsText
        guard logSource != .system else {
            return filteredLogText(rawText)
        }
        let ids = Set(scopedContainers.map(\.id))
        let allIDs = Set(runtimeStore.containers.map(\.id))
        let raw = ids == allIDs
            ? rawText
            : GlobalLogStreamFormatter.filtered(rawText, containerIDs: ids)
        return filteredLogText(raw)
    }

    private func filteredLogText(_ raw: String) -> String {
        let query = logFilterText.trimmed
        let lines = raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                matchesLogLine(line, query: query)
            }
        return lines.isEmpty ? (language.resolved == .zhHans ? "没有匹配的日志。" : "No matching log lines.") : lines.joined(separator: "\n")
    }

    private func matchesLogLine(_ line: String, query: String) -> Bool {
        if line.hasPrefix("[") || line.hasPrefix(AppBranding.logPrefix) || line.hasPrefix(AppBranding.legacyLogPrefix) {
            return true
        }
        if logErrorOnly, !isErrorLogLine(line) {
            return false
        }
        guard !query.isEmpty else { return true }
        if logRegexEnabled, let regex = try? Regex(query) {
            return line.firstMatch(of: regex) != nil
        }
        if logCaseSensitive {
            return line.contains(query)
        }
        return line.localizedCaseInsensitiveContains(query)
    }

    private func isErrorLogLine(_ line: String) -> Bool {
        let text = line.lowercased()
        return ["error", "failed", "failure", "fatal", "panic", "exception", "denied", "refused", "错误", "失败"].contains {
            text.contains($0)
        }
    }

    private var statsSummary: ObservabilityStatsSummary {
        ObservabilityStatsSummary(snapshots: visibleStats)
    }

    private var sortedStats: [ContainerStatsSnapshot] {
        visibleStats.sortedForObservability(by: statsSort)
    }

    private var scopedContainerIDs: [String] {
        scopedContainers.map(\.id)
    }

    private var scopedContainerKey: String {
        scopedContainerIDs.sorted().joined(separator: "|")
    }

    private var visibleStats: [ContainerStatsSnapshot] {
        let ids = Set(scopedContainerIDs)
        guard !ids.isEmpty else { return [] }
        return runtimeStore.globalStats.filter { ids.contains($0.id) }
    }

    private var visibleResourceSamples: [ContainerResourceSample] {
        let ids = Set(scopedContainerIDs)
        guard !ids.isEmpty else { return [] }
        return runtimeStore.containerResourceSamples.filter { ids.contains($0.id) }
    }

    private var scopedResourceSnapshot: EnvironmentResourceSnapshot? {
        guard !visibleResourceSamples.isEmpty else { return nil }
        let sampleDate = visibleResourceSamples.map(\.date).max() ?? Date()
        return EnvironmentResourceSnapshot(
            date: sampleDate,
            containerSamples: visibleResourceSamples,
            runningContainerCount: scopedContainers.filter { $0.state == "running" }.count,
            hostProcesses: runtimeStore.hostProcessSnapshots
        )
    }

    private var composeScopes: [ObservabilityComposeScope] {
        var scopes: [ObservabilityComposeScope] = [.all]
        for project in composeStore.projects {
            scopes.append(.project(project.id))
            scopes.append(contentsOf: project.services.map { .service(projectID: project.id, serviceName: $0.name) })
        }
        return scopes
    }

    var body: some View {
        DrawerPageLayout(
            isDrawerPresented: showResourceDrawer,
            onDismiss: closeResourceDrawer,
            drawerWidth: 620
        ) {
            pageContent
        } drawer: {
            resourceDrawer
        }
        .task {
            if runtimeStore.globalLogsText.isEmpty {
                refresh()
            }
        }
        .onAppear {
            consumeResourceSnapshotRouteRequest()
        }
        .task(id: autoRefresh) {
            guard autoRefresh else { return }
            while !Task.isCancelled, autoRefresh {
                let seconds = max(min(Int(refreshInterval.trimmed) ?? 10, 300), 5)
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                if !Task.isCancelled {
                    if !liveLogStore.isStreaming {
                        await refreshNow()
                    }
                }
            }
        }
        .onDisappear {
            liveLogStore.stop()
            runtimeStore.stopResourceMonitoring()
        }
        .onChange(of: logSource) { _, _ in
            liveLogStore.stop()
            liveLogStore.clear()
            refresh()
        }
        .onChange(of: scopedContainerKey) { _, _ in
            guard showResourceDrawer else { return }
            refreshResourceSnapshot()
        }
        .onChange(of: resourceSnapshotRequestID) { _, _ in
            consumeResourceSnapshotRouteRequest()
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.observability),
                subtitle: language.t(.observabilitySubtitle),
                systemImage: "waveform.path.ecg"
            ) {
                headerActions
            }

            ObservabilityControlBar(
                searchText: $searchText,
                logFilterText: $logFilterText,
                logSource: $logSource,
                logLines: $logLines,
                systemLogLast: $systemLogLast,
                composeScope: $composeScope,
                statsSort: $statsSort,
                onlyRunning: $onlyRunning,
                autoRefresh: $autoRefresh,
                refreshInterval: $refreshInterval,
                composeScopes: composeScopes,
                composeScopeTitle: composeScopeTitle,
                composeScopeDisabled: composeStore.projects.isEmpty,
                filteredCount: scopedContainers.count
            )

            logsPanel
        }
    }

    private func refresh() {
        Task { await refreshNow() }
    }

    private func toggleResourceDrawer() {
        if showResourceDrawer {
            closeResourceDrawer()
        } else {
            presentResourceDrawer()
        }
    }

    private func presentResourceDrawer() {
        showResourceDrawer = true
        if resourceSampleScopeKey != scopedContainerKey || visibleResourceSamples.isEmpty {
            refreshResourceSnapshot()
        }
    }

    private func consumeResourceSnapshotRouteRequest() {
        guard resourceSnapshotRequestID != nil else { return }
        resourceSnapshotRequestID = nil
        presentResourceDrawer()
    }

    private func closeResourceDrawer() {
        showResourceDrawer = false
    }

    private func refreshResourceSnapshot() {
        Task { await refreshResourceSnapshotNow() }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                toggleResourceDrawer()
            } label: {
                Label(language.resolved == .zhHans ? "资源快照" : "Stats Snapshot", systemImage: "sidebar.right")
            }
            .help(language.resolved == .zhHans ? "打开资源快照抽屉" : "Open stats snapshot drawer")

            Button {
                refresh()
            } label: {
                if runtimeStore.isObservabilityRefreshing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(language.resolved == .zhHans ? "加载中" : "Loading")
                    }
                } else {
                    Label(language.t(.refresh), systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(runtimeStore.isObservabilityRefreshing)
            .help(language.resolved == .zhHans ? "刷新日志和资源数据" : "Refresh logs and resource data")

            Button {
                toggleLiveLogs()
            } label: {
                if liveLogStore.isStarting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(language.resolved == .zhHans ? "启动中" : "Starting")
                    }
                } else {
                    Label(
                        liveLogStore.isStreaming ? (language.resolved == .zhHans ? "停止实时" : "Stop Live") : (language.resolved == .zhHans ? "实时" : "Live"),
                        systemImage: liveLogStore.isStreaming ? "pause.circle" : "dot.radiowaves.left.and.right"
                    )
                }
            }
            .disabled(liveLogStore.isStarting)
            .help(liveLogStore.isStreaming
                ? (language.resolved == .zhHans ? "停止实时日志" : "Stop live logs")
                : (language.resolved == .zhHans ? "启动实时日志" : "Start live logs"))

            Button {
                exportLogs()
            } label: {
                Label(language.resolved == .zhHans ? "导出" : "Export", systemImage: "square.and.arrow.up")
            }
            .help(language.resolved == .zhHans ? "导出当前日志" : "Export current logs")

            Button {
                copyLogs()
            } label: {
                Label(language.resolved == .zhHans ? "复制" : "Copy", systemImage: "doc.on.doc")
            }
            .help(language.resolved == .zhHans ? "复制当前过滤日志" : "Copy filtered logs")

            Menu {
                Button {
                    saveCurrentLogPreset()
                } label: {
                    Label(language.resolved == .zhHans ? "保存当前预设" : "Save Current Preset", systemImage: "plus")
                }
                Divider()
                if logPresets.isEmpty {
                    Text(language.resolved == .zhHans ? "暂无预设" : "No presets")
                } else {
                    ForEach(logPresets) { preset in
                        Button {
                            applyLogPreset(preset)
                        } label: {
                            Label(preset.name, systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            } label: {
                Label(language.resolved == .zhHans ? "预设" : "Presets", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help(language.resolved == .zhHans ? "保存或应用日志过滤预设" : "Save or apply log presets")
        }
    }

    private var resourceDrawer: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "资源快照" : "Stats Snapshot",
                subtitle: "container stats --no-stream · \(composeScopeTitle(composeScope))",
                systemImage: "chart.xyaxis.line",
                onClose: closeResourceDrawer
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EnvironmentResourceMonitorPanel(
                        snapshot: scopedResourceSnapshot,
                        hostProcesses: runtimeStore.hostProcessSnapshots,
                        errorMessage: runtimeStore.resourceMonitorErrorMessage
                    )

                    if !runtimeStore.resourceMonitorHistory.isEmpty {
                        ResourceMonitorChartsPanel(history: runtimeStore.resourceMonitorHistory)
                    }

                    if visibleResourceSamples.isEmpty, !visibleStats.isEmpty {
                        statsPanel
                    } else {
                        ContainerResourceSamplesPanel(samples: visibleResourceSamples, sort: statsSort)
                    }

                    HostProcessResourcesPanel(processes: runtimeStore.hostProcessSnapshots)
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .drawerSurface(width: 620)
    }

    private var statsPanel: some View {
        PanelView(
            title: language.resolved == .zhHans ? "资源快照" : "Stats Snapshot",
            subtitle: "container stats --no-stream",
            systemImage: "chart.xyaxis.line"
        ) {
            if visibleStats.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "暂无 stats 数据" : "No stats yet",
                    message: language.resolved == .zhHans ? "点击刷新读取当前筛选容器的资源快照。" : "Refresh to read a resource snapshot for the current container filter.",
                    systemImage: "chart.xyaxis.line"
                )
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ObservabilitySummaryGrid(summary: statsSummary, lastUpdated: runtimeStore.lastUpdated)
                        .padding(.bottom, 12)
                    Divider()
                    ForEach(sortedStats) { snapshot in
                        ObservabilityStatsRow(snapshot: snapshot)
                        Divider()
                    }
                }
            }
        }
    }

    private var logsPanel: some View {
        PanelView(title: language.t(.logs), subtitle: logPanelSubtitle, systemImage: "doc.plaintext") {
            logOptionsBar
                .padding(.bottom, 8)
            if liveLogStore.isStreaming || liveLogStore.isStarting {
                StatusBanner(
                    text: liveLogStatusText,
                    systemImage: "dot.radiowaves.left.and.right",
                    tint: CDTheme.dockerBlue
                )
                .padding(.bottom, 8)
            } else if let errorMessage = liveLogStore.errorMessage?.nilIfBlank {
                StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                    .padding(.bottom, 8)
            }
            TerminalBlock(
                text: visibleLogsText.nilIfBlank ?? (language.resolved == .zhHans ? "点击刷新加载日志。" : "Refresh to load logs."),
                minHeight: 440,
                softWrap: logSoftWrap
            )
        }
    }

    private var logOptionsBar: some View {
        HStack(spacing: 10) {
            Toggle(language.resolved == .zhHans ? "错误" : "Errors", isOn: $logErrorOnly)
                .toggleStyle(.switch)
            Toggle("Regex", isOn: $logRegexEnabled)
                .toggleStyle(.switch)
            Toggle(language.resolved == .zhHans ? "大小写" : "Case", isOn: $logCaseSensitive)
                .toggleStyle(.switch)
            Toggle(language.resolved == .zhHans ? "换行" : "Wrap", isOn: $logSoftWrap)
                .toggleStyle(.switch)
            Spacer()
            Text(language.resolved == .zhHans ? "\(visibleLogsText.split(separator: "\n").count) 行" : "\(visibleLogsText.split(separator: "\n").count) lines")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var logPanelSubtitle: String {
        switch logSource {
        case .containerStdio:
            return "container logs -n \(ObservabilityInputNormalizer.logLines(logLines))"
        case .containerBoot:
            return "container logs --boot -n \(ObservabilityInputNormalizer.logLines(logLines))"
        case .system:
            return "container system logs --last \(ObservabilityInputNormalizer.systemLogLast(systemLogLast))"
        }
    }

    private func composeScopeTitle(_ scope: ObservabilityComposeScope) -> String {
        switch scope {
        case .all:
            return language.resolved == .zhHans ? "全部容器" : "All containers"
        case .project(let projectID):
            let project = composeStore.projects.first { $0.id == projectID }
            let name = project?.name ?? projectID
            return language.resolved == .zhHans ? "项目：\(name)" : "Project: \(name)"
        case .service(let projectID, let serviceName):
            let project = composeStore.projects.first { $0.id == projectID }
            let projectName = project?.name ?? projectID
            return "\(projectName) / \(serviceName)"
        }
    }

    private var liveLogStatusText: String {
        if logSource == .system {
            if language.resolved == .zhHans {
                return liveLogStore.isStarting ? "正在启动系统实时日志..." : "正在实时跟随系统服务日志。"
            }
            return liveLogStore.isStarting ? "Starting system live logs..." : "Following system service logs live."
        }
        let count = liveLogStore.followedContainerIDs.count
        if language.resolved == .zhHans {
            return liveLogStore.isStarting ? "正在启动实时日志..." : "正在实时跟随 \(count) 个容器。"
        }
        return liveLogStore.isStarting ? "Starting live logs..." : "Following \(count) containers live."
    }

    private func toggleLiveLogs() {
        if liveLogStore.isStreaming || liveLogStore.isStarting {
            liveLogStore.stop()
            return
        }
        Task {
            if logSource == .system {
                await liveLogStore.startSystemLogs(last: ObservabilityInputNormalizer.systemLogLast(systemLogLast))
            } else {
                await liveLogStore.start(
                    containers: scopedContainers,
                    boot: logSource == .containerBoot,
                    lines: ObservabilityInputNormalizer.logLines(logLines)
                )
            }
        }
    }

    private func refreshNow() async {
        let ids = scopedContainers.map(\.id)
        await runtimeStore.refreshGlobalObservability(
            containerIDs: ids,
            lines: ObservabilityInputNormalizer.logLines(logLines),
            logSource: logSource,
            systemLogLast: ObservabilityInputNormalizer.systemLogLast(systemLogLast)
        )
        await refreshResourceSnapshotNow()
    }

    private func refreshResourceSnapshotNow() async {
        let scopeKey = scopedContainerKey
        let ids = scopedContainerIDs
        guard !ids.isEmpty else {
            await MainActor.run {
                resourceSampleScopeKey = scopeKey
            }
            return
        }
        await runtimeStore.refreshResourceMonitorOnce(containerIDs: ids)
        await MainActor.run {
            resourceSampleScopeKey = scopeKey
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "containerdesktop-logs.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try visibleLogsText.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            runtimeStore.errorMessage = error.localizedDescription
        }
    }

    private func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(visibleLogsText, forType: .string)
    }

    private func saveCurrentLogPreset() {
        let name = "\(composeScopeTitle(composeScope)) · \(Date().formatted(date: .omitted, time: .shortened))"
        let preset = ObservabilityLogPreset(
            name: name,
            searchText: searchText,
            filterText: logFilterText,
            logSource: logSource,
            logLines: logLines,
            systemLogLast: systemLogLast,
            composeScope: composeScope,
            onlyRunning: onlyRunning,
            autoRefresh: autoRefresh,
            refreshInterval: refreshInterval,
            regexEnabled: logRegexEnabled,
            caseSensitive: logCaseSensitive,
            errorOnly: logErrorOnly,
            softWrap: logSoftWrap
        )
        logPresets.removeAll { $0.name == preset.name }
        logPresets.insert(preset, at: 0)
        ObservabilityLogPresetPersistence.save(logPresets)
    }

    private func applyLogPreset(_ preset: ObservabilityLogPreset) {
        searchText = preset.searchText
        logFilterText = preset.filterText
        logSource = preset.logSource
        logLines = preset.logLines
        systemLogLast = preset.systemLogLast
        composeScope = preset.composeScope
        onlyRunning = preset.onlyRunning
        autoRefresh = preset.autoRefresh
        refreshInterval = preset.refreshInterval
        logRegexEnabled = preset.regexEnabled
        logCaseSensitive = preset.caseSensitive
        logErrorOnly = preset.errorOnly
        logSoftWrap = preset.softWrap
        refresh()
    }
}

private struct ObservabilitySummaryGrid: View {
    @Environment(\.appLanguage) private var language
    var summary: ObservabilityStatsSummary
    var lastUpdated: Date?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                metric(
                    language.resolved == .zhHans ? "容器" : "Containers",
                    "\(summary.containerCount)"
                )
                metric(
                    "Memory",
                    summary.memoryDisplay
                )
            }
            GridRow {
                metric(
                    "Network",
                    summary.networkDisplay
                )
                metric(
                    "PIDs",
                    "\(summary.totalProcesses)"
                )
            }
            GridRow {
                metric(
                    "Block I/O",
                    summary.blockIODisplay
                )
                metric(
                    language.resolved == .zhHans ? "刷新" : "Updated",
                    lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "—"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }
}

private struct ObservabilityStatsRow: View {
    var snapshot: ContainerStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(snapshot.id)
                    .font(.callout.weight(.semibold).monospaced())
                    .lineLimit(1)
                Spacer()
                Text("\(snapshot.numProcesses) proc")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    metric("Memory", "\(snapshot.memoryUsageDisplay) / \(snapshot.memoryLimitDisplay)")
                    metric("Network", snapshot.networkDisplay)
                }
                GridRow {
                    metric("Block I/O", snapshot.blockIODisplay)
                    metric("CPU usec", "\(snapshot.cpuUsageUsec)")
                }
            }
        }
        .padding(.vertical, 9)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}
