import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VolumesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var newVolumeName = ""
    @State private var newVolumeSize = ""
    @State private var newVolumeLabels = ""
    @State private var newVolumeOptions = ""
    @State private var showCreatePopover = false
    @State private var selectedName: String?
    @State private var pendingDelete: VolumeSummary?
    @State private var pendingEmpty: VolumeSummary?
    @State private var cloneSource: VolumeSummary?
    @State private var cloneVolumeName = ""
    @State private var cloneVolumeSize = ""
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var isConfirmingPrune = false
    @State private var volumeBrowserStore = VolumeBrowserStore()

    private var filteredVolumes: [VolumeSummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.volumes }
        return runtimeStore.volumes.filter {
            $0.name.lowercased().contains(query) || $0.source.lowercased().contains(query)
        }
    }

    private var selectedVolume: VolumeSummary? {
        guard let selectedName else { return nil }
        return runtimeStore.volumes.first { $0.name == selectedName }
    }

    var body: some View {
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
                    VolumeDetailOverview(
                        volume: selectedVolume,
                        browserStore: volumeBrowserStore,
                        onOpenEntry: { entry in
                            if entry.isDirectory {
                                volumeBrowserStore.open(entry)
                            } else {
                                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                            }
                        },
                        onRevealEntry: { entry in
                            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                        },
                        onRefreshFiles: {
                            volumeBrowserStore.load(volume: selectedVolume, relativePath: volumeBrowserStore.snapshot?.relativePath ?? "")
                        },
                        onExport: {
                            exportVolume(selectedVolume)
                        },
                        onImport: {
                            importIntoVolume(selectedVolume)
                        },
                        onClone: {
                            showCloneSheet(for: selectedVolume)
                        },
                        onEmpty: {
                            pendingEmpty = selectedVolume
                        }
                    )
                }
            }
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
            Text("将删除存储卷 \(pendingDelete?.name ?? "所选卷")。被容器引用的卷无法删除。")
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
                    .sheet(isPresented: $showCreatePopover) {
                        createVolumeForm
                    }

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
                Text(language.itemCount(filteredVolumes.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredVolumes.isEmpty {
                ResourceTable {
                    volumeHeader
                } rows: {
                    EmptyStateView(title: language.t(.noVolumes), message: "创建命名卷后可在容器中挂载使用。", systemImage: "externaldrive")
                        .padding(18)
                }
            } else {
                ResourceTable {
                    volumeHeader
                } rows: {
                    ForEach(filteredVolumes) { volume in
                        ResourceTableRow(isSelected: selectedName == volume.name) {
                            let deleteKey = RuntimeOperationKey.volumeDelete(volume.name)
                            let isOperationBlocked = runtimeStore.activeOperationKey != nil || runtimeStore.isVolumeOperationRunning
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

                            HStack(spacing: 8) {
                                RowActionButton(systemImage: "folder") {
                                    openVolumeSource(volume)
                                }
                                RowActionButton(systemImage: "plus.square.on.square", isDisabled: isOperationBlocked) {
                                    showCloneSheet(for: volume)
                                }
                                DestructiveRowActionButton(systemImage: "eraser", isDisabled: isOperationBlocked) {
                                    pendingEmpty = volume
                                }
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectVolume(volume)
                                }
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: isOperationBlocked && !runtimeStore.isOperationActive(deleteKey)
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
            Button("取消", role: .cancel) {}
        } message: {
            Text(language.resolved == .zhHans ? "将删除没有容器引用的存储卷。" : "This removes volumes that are not referenced by containers.")
        }
    }

    private func selectVolume(_ volume: VolumeSummary) {
        selectedName = volume.name
        drawerMode = .overview
        volumeBrowserStore.load(volume: volume)
        Task { await runtimeStore.inspectVolume(volume.name) }
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

    private func openVolumeSource(_ volume: VolumeSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: volume.source)])
    }

    private func exportVolume(_ volume: VolumeSummary) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(volume.name).tar"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await volumeBrowserStore.export(volume: volume, outputPath: url.path) }
    }

    private func importIntoVolume(_ volume: VolumeSummary) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await volumeBrowserStore.importArchive(volume: volume, archivePath: url.path) }
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
        Task {
            await runtimeStore.emptyVolume(volume)
            if selectedName == volume.name {
                volumeBrowserStore.load(volume: volume, relativePath: volumeBrowserStore.snapshot?.relativePath ?? "")
            }
        }
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}

private struct VolumeDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var volume: VolumeSummary
    @Bindable var browserStore: VolumeBrowserStore
    var onOpenEntry: (VolumeFileEntry) -> Void
    var onRevealEntry: (VolumeFileEntry) -> Void
    var onRefreshFiles: () -> Void
    var onExport: () -> Void
    var onImport: () -> Void
    var onClone: () -> Void
    var onEmpty: () -> Void
    @State private var showCreateFolderPopover = false
    @State private var newFolderName = ""
    @State private var renameEntry: VolumeFileEntry?
    @State private var renameEntryName = ""
    @State private var pendingDeleteEntry: VolumeFileEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "存储卷" : "Volume") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: volume.name)
                    DetailInfoRow(title: language.t(.type), value: volume.typeText)
                    DetailInfoRow(title: language.t(.driver), value: volume.driver)
                    DetailInfoRow(title: "Format", value: volume.format)
                    DetailInfoRow(title: language.t(.source), value: volume.source)
                    DetailInfoRow(title: language.t(.created), value: volume.createdText)
                    DetailInfoRow(title: language.t(.size), value: volume.sizeDisplay)
                }
            }

            DetailSection(title: "Metadata") {
                DetailInfoCard {
                    if volume.configuration.labels.isEmpty && volume.configuration.options.isEmpty {
                        Text(language.resolved == .zhHans ? "没有标签或驱动选项。" : "No labels or driver options.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(volume.configuration.labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailInfoRow(title: key, value: value)
                        }
                        ForEach(volume.configuration.options.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailInfoRow(title: key, value: value)
                        }
                    }
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "文件" : "Files") {
                DetailInfoCard {
                    volumeFileToolbar

                    if let statusMessage = browserStore.statusMessage {
                        StatusBanner(
                            text: statusMessage,
                            systemImage: browserStore.isError ? "exclamationmark.triangle" : "checkmark.circle",
                            tint: browserStore.isError ? CDTheme.ember : CDTheme.lime
                        )
                    }

                    if browserStore.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(language.resolved == .zhHans ? "正在读取卷目录..." : "Reading volume directory...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let snapshot = browserStore.snapshot {
                        if snapshot.entries.isEmpty {
                            Text(language.resolved == .zhHans ? "目录为空。" : "Directory is empty.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(snapshot.entries.prefix(80)) { entry in
                                    VolumeFileRow(
                                        entry: entry,
                                        onOpen: { onOpenEntry(entry) },
                                        onReveal: { onRevealEntry(entry) },
                                        onRename: {
                                            renameEntryName = entry.name
                                            renameEntry = entry
                                        },
                                        onDelete: {
                                            pendingDeleteEntry = entry
                                        }
                                    )
                                    Divider()
                                }
                            }
                            if snapshot.entries.count > 80 {
                                Text(language.resolved == .zhHans ? "仅显示前 80 项，缩小目录后继续浏览。" : "Showing the first 80 items. Narrow the directory to inspect more.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(language.resolved == .zhHans ? "无法读取卷目录。" : "Unable to read volume directory.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .alert(language.resolved == .zhHans ? "删除文件项？" : "Delete entry?", isPresented: Binding(
            get: { pendingDeleteEntry != nil },
            set: { if !$0 { pendingDeleteEntry = nil } }
        )) {
            if let entry = pendingDeleteEntry {
                Button(language.resolved == .zhHans ? "删除" : "Delete", role: .destructive) {
                    pendingDeleteEntry = nil
                    Task { await browserStore.deleteEntry(volume: volume, entry: entry) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(language.resolved == .zhHans ? "将删除 \(pendingDeleteEntry?.name ?? "该项")。" : "This will delete \(pendingDeleteEntry?.name ?? "the selected entry").")
        }
        .sheet(item: $renameEntry) { entry in
            renameSheet(entry: entry)
        }
        .sheet(isPresented: $showCreateFolderPopover) {
            createFolderForm
        }
    }

    private var volumeFileToolbar: some View {
        HStack(spacing: 8) {
            Text(browserStore.snapshot?.displayPath ?? "/")
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 6))

            Spacer()

            Button {
                showCreateFolderPopover = true
            } label: {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 28, height: 28)
                    .background(CDTheme.dockerBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(browserStore.isLoading || browserStore.isImportExportRunning || browserStore.isFileOperationRunning)

            RowActionButton(systemImage: "arrow.up") {
                browserStore.goUp()
            }
            RowActionButton(systemImage: "arrow.clockwise") {
                onRefreshFiles()
            }
            RowActionButton(systemImage: "plus.square.on.square") {
                onClone()
            }
            DestructiveRowActionButton(systemImage: "eraser") {
                onEmpty()
            }
            RowActionButton(systemImage: "square.and.arrow.up") {
                onExport()
            }
            RowActionButton(systemImage: "square.and.arrow.down") {
                onImport()
            }
        }
    }

    private var createFolderForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "新建目录" : "Create Folder")
                .font(.headline)
            TextField(language.resolved == .zhHans ? "目录名称" : "Folder name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Spacer()
                Button("取消") {
                    showCreateFolderPopover = false
                }
                Button(language.t(.create)) {
                    let name = newFolderName
                    newFolderName = ""
                    showCreateFolderPopover = false
                    Task { await browserStore.createDirectory(volume: volume, name: name) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFolderName.trimmed.isEmpty || browserStore.isFileOperationRunning)
            }
        }
        .padding(16)
    }

    private func renameSheet(entry: VolumeFileEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "重命名" : "Rename")
                .font(.headline)
            Text(entry.name)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            TextField(language.resolved == .zhHans ? "新名称" : "New name", text: $renameEntryName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Spacer()
                Button("取消") {
                    renameEntry = nil
                }
                Button(language.t(.save)) {
                    let newName = renameEntryName
                    renameEntry = nil
                    Task { await browserStore.renameEntry(volume: volume, entry: entry, newName: newName) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameEntryName.trimmed.isEmpty || browserStore.isFileOperationRunning)
            }
        }
        .padding(16)
    }
}

private struct VolumeFileRow: View {
    var entry: VolumeFileEntry
    var onOpen: () -> Void
    var onReveal: () -> Void
    var onRename: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 8) {
                    Image(systemName: entry.systemImage)
                        .foregroundStyle(entry.isDirectory ? CDTheme.dockerBlue : .secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Text("\(entry.sizeDisplay) · \(entry.modifiedText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            RowActionButton(systemImage: "folder") {
                onReveal()
            }
            RowActionButton(systemImage: "pencil") {
                onRename()
            }
            DestructiveRowActionButton {
                onDelete()
            }
        }
        .padding(.vertical, 7)
    }
}
