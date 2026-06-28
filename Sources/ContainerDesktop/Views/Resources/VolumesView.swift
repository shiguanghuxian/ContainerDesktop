import AppKit
import SwiftUI

private enum VolumeKindFilter: String, CaseIterable, Identifiable {
    case all
    case named
    case anonymous

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            language.resolved == .zhHans ? "全部类型" : "All Types"
        case .named:
            language.resolved == .zhHans ? "命名卷" : "Named"
        case .anonymous:
            language.resolved == .zhHans ? "匿名卷" : "Anonymous"
        }
    }
}

private enum VolumeSortOption: String, CaseIterable, Identifiable {
    case name
    case createdNewest
    case createdOldest
    case sizeLargest
    case sizeSmallest

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .name:
            language.resolved == .zhHans ? "名称" : "Name"
        case .createdNewest:
            language.resolved == .zhHans ? "最新创建" : "Newest"
        case .createdOldest:
            language.resolved == .zhHans ? "最早创建" : "Oldest"
        case .sizeLargest:
            language.resolved == .zhHans ? "大小降序" : "Largest"
        case .sizeSmallest:
            language.resolved == .zhHans ? "大小升序" : "Smallest"
        }
    }
}

struct VolumesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore
    @Binding var resourceRoute: AppResourceRoute?
    @State private var searchText = ""
    @State private var kindFilter: VolumeKindFilter = .all
    @State private var sortOption: VolumeSortOption = .name
    @State private var newVolumeName = ""
    @State private var newVolumeSize = ""
    @State private var newVolumeLabels = ""
    @State private var newVolumeOptions = ""
    @State private var showCreatePopover = false
    @State private var detailName: String?
    @State private var detailInitialTab: VolumeDetailTab = .overview
    @State private var selectedName: String?
    @State private var pendingDelete: VolumeSummary?
    @State private var pendingEmpty: VolumeSummary?
    @State private var cloneSource: VolumeSummary?
    @State private var cloneVolumeName = ""
    @State private var cloneVolumeSize = ""
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var isConfirmingPrune = false

    init(
        runtimeStore: RuntimeStore,
        operationStore: AppOperationStore,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        self.operationStore = operationStore
        _resourceRoute = resourceRoute
    }

    private var filteredVolumes: [VolumeSummary] {
        let query = searchText.trimmed.lowercased()
        return runtimeStore.volumes
            .filter { volume in
                switch kindFilter {
                case .all:
                    true
                case .named:
                    !volume.isAnonymous
                case .anonymous:
                    volume.isAnonymous
                }
            }
            .filter { volume in
                query.isEmpty
                    || volume.name.lowercased().contains(query)
                    || volume.source.lowercased().contains(query)
                    || volume.driver.lowercased().contains(query)
                    || volume.typeText.lowercased().contains(query)
            }
            .sorted { lhs, rhs in
                switch sortOption {
                case .name:
                    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                case .createdNewest:
                    lhs.configuration.creationDate > rhs.configuration.creationDate
                case .createdOldest:
                    lhs.configuration.creationDate < rhs.configuration.creationDate
                case .sizeLargest:
                    (lhs.configuration.sizeInBytes ?? 0) > (rhs.configuration.sizeInBytes ?? 0)
                case .sizeSmallest:
                    (lhs.configuration.sizeInBytes ?? UInt64.max) < (rhs.configuration.sizeInBytes ?? UInt64.max)
                }
            }
    }

    private var demoVolumeCommand: String {
        """
        container volume create --label purpose=ui-test --label demo=container-desktop cd-demo-empty
        container volume create --label purpose=ui-test --label demo=container-desktop --label content=files -s 64M cd-demo-files
        container volume create --label purpose=ui-test --label demo=container-desktop --label role=cache -s 128M cd-demo-cache
        container run --rm -v cd-demo-files:/mnt docker.io/library/alpine:3.22 sh -c 'mkdir -p /mnt/config /mnt/logs /mnt/data && printf "# ContainerDesktop volume demo\\n\\nThis file was generated for testing the Volumes page.\\n" > /mnt/README.md && printf "APP_ENV=demo\\nCACHE_DRIVER=file\\n" > /mnt/config/app.env && printf "2026-06-18T14:00:00Z demo volume initialized\\n2026-06-18T14:01:00Z files ready\\n" > /mnt/logs/app.log && printf "{\\n  \\"name\\": \\"cd-demo-files\\",\\n  \\"items\\": [\\"README.md\\", \\"config/app.env\\", \\"logs/app.log\\"]\\n}\\n" > /mnt/data/sample.json'
        # cleanup:
        container volume delete cd-demo-empty cd-demo-files cd-demo-cache cd-demo-files-copy
        """
    }

    private var pruneReferenceHint: String {
        language.resolved == .zhHans
            ? "当前 CLI 会删除没有容器引用的卷；如果有容器仍在使用，命令会保留或返回错误。"
            : "The CLI removes volumes with no container references; referenced volumes are kept or reported as errors."
    }

    private func deleteReferenceHint(for volume: VolumeSummary) -> String {
        let base = language.resolved == .zhHans
            ? "如果该卷仍被容器引用，CLI 会拒绝删除。"
            : "If the volume is still referenced by a container, the CLI will reject deletion."
        guard !volume.isAnonymous else {
            return base + (language.resolved == .zhHans ? " 这是匿名卷，建议先确认对应容器。" : " This is an anonymous volume; check the related container first.")
        }
        return base
    }

    private var selectedVolume: VolumeSummary? {
        guard let selectedName else { return nil }
        return runtimeStore.volumes.first { $0.name == selectedName }
    }

    private var isDetailPresented: Binding<Bool> {
        Binding(
            get: { detailName != nil },
            set: { if !$0 { detailName = nil } }
        )
    }

    var body: some View {
        Group {
            if let detailName {
                VolumeDetailPage(
                    runtimeStore: runtimeStore,
                    operationStore: operationStore,
                    name: detailName,
                    initialTab: detailInitialTab,
                    isPresented: isDetailPresented,
                    resourceRoute: $resourceRoute
                )
            } else {
                DrawerPageLayout(isDrawerPresented: selectedVolume != nil, onDismiss: {
                    selectedName = nil
                }) {
                    pageContent
                } drawer: {
                    if let selectedVolume {
                        DetailDrawer(
                            mode: $drawerMode,
                            title: selectedVolume.name,
                            subtitle: "container volume inspect",
                            systemImage: "externaldrive",
                            rawText: runtimeStore.selectedInspectorText,
                            onClose: {
                                selectedName = nil
                            }
                        ) {
                            VStack(alignment: .leading, spacing: 16) {
                                VolumeOverviewTabView(volume: selectedVolume)
                                VolumeMetadataTabView(volume: selectedVolume)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            consumeResourceRoute()
        }
        .onChange(of: resourceRoute) { _, route in
            consumeResourceRoute(route)
        }
        .alert("删除存储卷？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let volume = pendingDelete {
                Button(language.t(.delete), role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteVolume(volume.name) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteAlertMessage)
        }
        .alert(language.resolved == .zhHans ? "清空存储卷？" : "Empty volume?", isPresented: Binding(
            get: { pendingEmpty != nil },
            set: { if !$0 { pendingEmpty = nil } }
        )) {
            if let volume = pendingEmpty {
                Button(language.resolved == .zhHans ? "清空" : "Empty", role: .destructive) {
                    pendingEmpty = nil
                    emptyVolume(volume)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(language.resolved == .zhHans ? "将删除卷内所有文件，但保留存储卷本身。请先停止正在写入该卷的容器。" : "This removes all files inside the volume but keeps the volume. Stop containers that are writing to it first.")
        }
        .sheet(item: $cloneSource) { volume in
            VolumeCloneSheet(
                sourceVolume: volume,
                name: $cloneVolumeName,
                size: $cloneVolumeSize,
                isRunning: runtimeStore.isVolumeOperationRunning,
                onCancel: {
                    cloneSource = nil
                },
                onClone: {
                    let source = volume
                    let targetName = cloneVolumeName
                    let targetSize = cloneVolumeSize
                    cloneSource = nil
                    Task {
                        await runtimeStore.cloneVolume(
                            source: source,
                            targetOptions: VolumeCreateOptions(
                                name: targetName,
                                size: targetSize.nilIfBlank
                            )
                        )
                    }
                }
            )
        }
    }

    private func consumeResourceRoute(_ route: AppResourceRoute? = nil) {
        let route = route ?? resourceRoute
        guard case .volume(let name, let tab) = route else { return }
        selectedName = nil
        detailInitialTab = tab ?? .overview
        detailName = name
        resourceRoute = nil
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.volumes),
                subtitle: language.t(.volumesSubtitle),
                systemImage: "externaldrive"
            ) {
                HStack(spacing: 8) {
                    Button {
                        showCreatePopover = true
                    } label: {
                        if runtimeStore.isOperationActive(RuntimeOperationKey.volumeCreate) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(language.resolved == .zhHans ? "创建中" : "Creating")
                            }
                        } else {
                            Label(language.t(.createVolume), systemImage: "plus.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning)
                    .help(language.resolved == .zhHans ? "打开创建卷表单" : "Open the create volume form")
                    .sheet(isPresented: $showCreatePopover) {
                        createVolumeForm
                    }

                    refreshButton

                    Button {
                        isConfirmingPrune = true
                    } label: {
                        if runtimeStore.isOperationActive(RuntimeOperationKey.volumePrune) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(language.resolved == .zhHans ? "清理中" : "Pruning")
                            }
                        } else {
                            Label(language.resolved == .zhHans ? "清理未使用" : "Prune Unused", systemImage: "trash")
                        }
                    }
                    .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning)
                    .help(language.resolved == .zhHans ? "清理未使用的卷" : "Prune unused volumes")
                }
            }

            if let message = runtimeStore.volumeStatusMessage {
                StatusBanner(
                    text: message,
                    systemImage: runtimeStore.volumeStatusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                    tint: runtimeStore.volumeStatusIsError ? CDTheme.ember : CDTheme.lime
                )
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Picker("", selection: $kindFilter) {
                    ForEach(VolumeKindFilter.allCases) { option in
                        Text(option.title(language: language)).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 118)
                .help(language.resolved == .zhHans ? "按卷类型过滤" : "Filter by volume type")

                Picker("", selection: $sortOption) {
                    ForEach(VolumeSortOption.allCases) { option in
                        Text(option.title(language: language)).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 118)
                .help(language.resolved == .zhHans ? "排序卷列表" : "Sort volumes")

                Text(language.itemCount(filteredVolumes.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredVolumes.isEmpty {
                ResourceTable {
                    volumeHeader
                } rows: {
                    volumeEmptyState
                        .padding(18)
                }
            } else {
                ResourceTable {
                    volumeHeader
                } rows: {
                    ForEach(filteredVolumes) { volume in
                        ResourceTableRow(
                            isSelected: selectedName == volume.name || detailName == volume.name,
                            onActivate: {
                                openVolumeDetail(volume)
                            },
                            activationHelp: language.resolved == .zhHans ? "打开卷详情" : "Open volume details"
                        ) {
                            let deleteKey = RuntimeOperationKey.volumeDelete(volume.name)
                            let isOperationBlocked = runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning
                            volumeRowMainContent(volume)

                            HStack(spacing: 8) {
                                RowActionButton(
                                    systemImage: "folder",
                                    help: language.resolved == .zhHans ? "打开本地卷文件夹" : "Open local volume folder"
                                ) {
                                    openVolumeLocalFolder(volume)
                                }
                                RowActionButton(
                                    systemImage: "plus.square.on.square",
                                    isDisabled: isOperationBlocked,
                                    help: language.resolved == .zhHans ? "克隆卷" : "Clone volume"
                                ) {
                                    showCloneSheet(for: volume)
                                }
                                DestructiveRowActionButton(
                                    systemImage: "eraser",
                                    isDisabled: isOperationBlocked,
                                    help: language.resolved == .zhHans ? "清空卷" : "Empty volume"
                                ) {
                                    pendingEmpty = volume
                                }
                                RowActionButton(
                                    systemImage: "sidebar.right",
                                    help: language.resolved == .zhHans ? "打开卷概览抽屉" : "Open volume overview drawer"
                                ) {
                                    selectVolume(volume)
                                }
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: isOperationBlocked && !runtimeStore.isOperationActive(deleteKey),
                                    help: language.resolved == .zhHans ? "删除卷" : "Delete volume"
                                ) {
                                    pendingDelete = volume
                                }
                            }
                            .frame(width: 184, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .alert(language.resolved == .zhHans ? "清理未使用卷？" : "Prune unused volumes?", isPresented: $isConfirmingPrune) {
            Button(language.resolved == .zhHans ? "清理" : "Prune", role: .destructive) {
                Task { await runtimeStore.pruneVolumes() }
            }
            .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning)
            .help(language.resolved == .zhHans ? "清理未使用卷" : "Prune unused volumes")
            Button("取消", role: .cancel) {}
        } message: {
            Text(pruneReferenceHint)
        }
    }

    private func volumeRowMainContent(_ volume: VolumeSummary) -> some View {
        HStack(spacing: 12) {
            ResourceStatusDot(tint: volume.isAnonymous ? .orange : CDTheme.lime, isHollow: volume.isAnonymous)

            Text(volume.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusPill(title: volume.typeText, systemImage: "tag", tint: volume.isAnonymous ? .orange : CDTheme.lime)
                .frame(width: 112, alignment: .leading)

            Text(volume.driver)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)

            Text(volume.createdText)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(volume.sizeDisplay)
                .font(.callout.monospacedDigit())
                .frame(width: 90, alignment: .trailing)
        }
    }

    private var deleteAlertMessage: String {
        guard let pendingDelete else {
            return language.resolved == .zhHans ? "将删除所选卷。" : "This deletes the selected volume."
        }
        let prefix = language.resolved == .zhHans
            ? "将删除存储卷 \(pendingDelete.name)。"
            : "This deletes volume \(pendingDelete.name)."
        return "\(prefix)\n\(deleteReferenceHint(for: pendingDelete))"
    }

    private var refreshButton: some View {
        Button {
            Task { await runtimeStore.refreshAll() }
        } label: {
            if runtimeStore.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.resolved == .zhHans ? "刷新中" : "Refreshing")
                }
            } else {
                Label(language.t(.refresh), systemImage: "arrow.clockwise")
            }
        }
        .disabled(runtimeStore.isRefreshing)
        .help(language.resolved == .zhHans ? "刷新卷列表" : "Refresh volume list")
    }

    private var volumeEmptyState: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                title: language.t(.noVolumes),
                message: language.resolved == .zhHans
                    ? "创建命名卷后可在容器中挂载使用，也可以先生成一组示例卷测试列表、详情和文件浏览。"
                    : "Create named volumes for containers, or generate demo volumes to test the list, details, and file browser.",
                systemImage: "externaldrive"
            )

            HStack(spacing: 8) {
                Button {
                    Task { await runtimeStore.createDemoVolumes() }
                } label: {
                    if runtimeStore.isVolumeOperationRunning {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(language.resolved == .zhHans ? "创建示例中" : "Creating Demo")
                        }
                    } else {
                        Label(language.resolved == .zhHans ? "创建示例卷" : "Create Demo Volumes", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning)
                .help(language.resolved == .zhHans ? "创建 cd-demo-* 示例卷" : "Create cd-demo-* sample volumes")

                Button {
                    copyToPasteboard(demoVolumeCommand)
                    runtimeStore.volumeStatusMessage = language.resolved == .zhHans
                        ? "已复制示例卷命令。"
                        : "Demo volume commands copied."
                    runtimeStore.volumeStatusIsError = false
                } label: {
                    Label(language.resolved == .zhHans ? "复制测试命令" : "Copy Test Commands", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .help(language.resolved == .zhHans ? "复制创建和清理示例卷的命令" : "Copy commands for creating and cleaning demo volumes")
            }
        }
    }

    private func selectVolume(_ volume: VolumeSummary) {
        detailName = nil
        selectedName = volume.name
        drawerMode = .overview
        Task { await runtimeStore.inspectVolume(volume.name) }
    }

    private func openVolumeDetail(_ volume: VolumeSummary, selectedTab: VolumeDetailTab = .overview) {
        selectedName = nil
        detailInitialTab = selectedTab
        detailName = volume.name
    }

    private func openVolumeLocalFolder(_ volume: VolumeSummary) {
        let source = volume.source.trimmed
        guard !source.isEmpty else { return }

        let sourceURL = URL(fileURLWithPath: source).standardizedFileURL
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            NSWorkspace.shared.open(sourceURL)
            return
        }

        let folderURL = sourceURL.deletingLastPathComponent()
        guard folderURL.path != sourceURL.path else { return }
        NSWorkspace.shared.open(folderURL)
    }

    private var createVolumeForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t(.createVolume))
                .font(.headline)
            TextField(language.t(.volumeName), text: $newVolumeName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            Picker(language.t(.volumeSize), selection: $newVolumeSize) {
                Text(language.resolved == .zhHans ? "默认" : "Default").tag("")
                ForEach(FormPresetOptions.volumeSizes, id: \.self) { size in
                    Text(size).tag(size)
                }
            }
            .labelsHidden()
            .frame(width: 260)
            TextField("--label key=value, one per line", text: $newVolumeLabels, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .frame(width: 320)
            TextField("--opt key=value, one per line", text: $newVolumeOptions, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .frame(width: 320)
            HStack {
                Spacer()
                Button("取消") {
                    showCreatePopover = false
                }
                .help(language.resolved == .zhHans ? "取消创建卷" : "Cancel creating volume")
                Button(language.t(.create)) {
                    let options = VolumeCreateOptions(
                        name: newVolumeName,
                        size: newVolumeSize,
                        options: lines(from: newVolumeOptions),
                        labels: lines(from: newVolumeLabels)
                    )
                    newVolumeName = ""
                    newVolumeSize = ""
                    newVolumeLabels = ""
                    newVolumeOptions = ""
                    showCreatePopover = false
                    Task { await runtimeStore.createVolume(options: options) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning)
                .help(language.resolved == .zhHans ? "创建卷" : "Create volume")
            }
        }
        .padding(16)
    }

    private var volumeHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.type), width: 112)
            ResourceTableHeaderLabel(title: language.t(.driver), width: 92)
            ResourceTableHeaderLabel(title: language.t(.created), width: 140)
            ResourceTableHeaderLabel(title: language.t(.size), width: 90, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 184, alignment: .trailing)
        }
    }

    private func showCloneSheet(for volume: VolumeSummary) {
        cloneVolumeName = suggestedCloneName(for: volume.name)
        cloneVolumeSize = ""
        cloneSource = volume
    }

    private func suggestedCloneName(for name: String) -> String {
        let base = "\(name)-copy"
        guard runtimeStore.volumes.contains(where: { $0.name == base }) else { return base }
        var index = 2
        while runtimeStore.volumes.contains(where: { $0.name == "\(base)-\(index)" }) {
            index += 1
        }
        return "\(base)-\(index)"
    }

    private func emptyVolume(_ volume: VolumeSummary) {
        Task { await runtimeStore.emptyVolume(volume) }
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
