import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct VolumeFilesTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    var volume: VolumeSummary
    @Bindable var browserStore: VolumeBrowserStore

    @State private var showCreateFolderPopover = false
    @State private var newFolderName = ""
    @State private var renameEntry: VolumeFileEntry?
    @State private var renameEntryName = ""
    @State private var pendingDeleteEntry: VolumeFileEntry?
    @State private var isConfirmingEmpty = false
    @State private var isShowingCloneSheet = false
    @State private var cloneVolumeName = ""
    @State private var cloneVolumeSize = ""

    var body: some View {
        DetailSection(title: language.resolved == .zhHans ? "文件" : "Files") {
            DetailInfoCard {
                volumeFileToolbar

                if isContainerBackedVolume {
                    containerBackedNotice
                }

                if let statusMessage = runtimeStore.volumeStatusMessage {
                    StatusBanner(
                        text: statusMessage,
                        systemImage: runtimeStore.volumeStatusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                        tint: runtimeStore.volumeStatusIsError ? CDTheme.ember : CDTheme.lime
                    )
                }

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
                                    isDisabled: isFileActionDisabled,
                                    onOpen: { openEntry(entry) },
                                    onReveal: { revealEntry(entry) },
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
                            Label(
                                language.resolved == .zhHans ? "仅显示前 80 项，缩小目录后继续浏览。" : "Showing the first 80 items. Narrow the directory to inspect more.",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        }
                    }
                } else {
                    Text(language.resolved == .zhHans ? "无法读取卷目录。" : "Unable to read volume directory.")
                        .foregroundStyle(.secondary)
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
        .alert(language.resolved == .zhHans ? "清空存储卷？" : "Empty volume?", isPresented: $isConfirmingEmpty) {
            Button(language.resolved == .zhHans ? "清空" : "Empty", role: .destructive) {
                emptyVolume()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(language.resolved == .zhHans ? "将删除卷内所有文件，但保留存储卷本身。请先停止正在写入该卷的容器。" : "This removes all files inside the volume but keeps the volume. Stop containers that are writing to it first.")
        }
        .sheet(item: $renameEntry) { entry in
            renameSheet(entry: entry)
        }
        .sheet(isPresented: $showCreateFolderPopover) {
            createFolderForm
        }
        .sheet(isPresented: $isShowingCloneSheet) {
            VolumeCloneSheet(
                sourceVolume: volume,
                name: $cloneVolumeName,
                size: $cloneVolumeSize,
                isRunning: runtimeStore.isVolumeOperationRunning,
                onCancel: {
                    isShowingCloneSheet = false
                },
                onClone: {
                    let targetName = cloneVolumeName
                    let targetSize = cloneVolumeSize
                    isShowingCloneSheet = false
                    Task {
                        await runtimeStore.cloneVolume(
                            source: volume,
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

    private var isContainerBackedVolume: Bool {
        if let snapshot = browserStore.snapshot {
            return !snapshot.isHostBacked
        }

        let source = volume.source.trimmed
        guard !source.isEmpty else { return false }
        var isDirectory: ObjCBool = false
        return !(FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) && isDirectory.boolValue)
    }

    private var containerBackedNotice: some View {
        Label(
            language.resolved == .zhHans
                ? "卷内文件通过临时容器挂载读取和操作，依赖 docker.io/library/alpine:3.22 可拉取和运行。"
                : "Volume files are read and changed through a transient container mount, which requires docker.io/library/alpine:3.22 to be pullable and runnable.",
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    private var volumeFileToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                pathLabel
                itemCountLabel
                Spacer(minLength: 8)
                actionButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    pathLabel
                    itemCountLabel
                    Spacer(minLength: 0)
                }
                actionButtons
            }
        }
    }

    private var pathLabel: some View {
        Text(browserStore.snapshot?.displayPath ?? "/")
            .font(.caption.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var itemCountLabel: some View {
        if let snapshot = browserStore.snapshot {
            Text(language.resolved == .zhHans ? "\(snapshot.entries.count) 项" : "\(snapshot.entries.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
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
            .disabled(isFileActionDisabled)
            .help(language.resolved == .zhHans ? "新建目录" : "Create folder")

            RowActionButton(
                systemImage: "arrow.up",
                isDisabled: isFileActionDisabled,
                help: language.resolved == .zhHans ? "返回上一级" : "Go to parent folder"
            ) {
                Task { await browserStore.goUp(volume: volume) }
            }
            RowActionButton(
                systemImage: "arrow.clockwise",
                isDisabled: isFileActionDisabled,
                help: language.t(.refresh)
            ) {
                Task { await browserStore.load(volume: volume, relativePath: browserStore.snapshot?.relativePath ?? "") }
            }
            RowActionButton(
                systemImage: "plus.square.on.square",
                isDisabled: isFileActionDisabled,
                help: language.resolved == .zhHans ? "克隆卷" : "Clone volume"
            ) {
                showCloneSheet()
            }
            DestructiveRowActionButton(
                systemImage: "eraser",
                isDisabled: isFileActionDisabled,
                help: language.resolved == .zhHans ? "清空卷" : "Empty volume"
            ) {
                isConfirmingEmpty = true
            }
            RowActionButton(
                systemImage: "square.and.arrow.up",
                isDisabled: isFileActionDisabled,
                help: language.resolved == .zhHans ? "导出文件" : "Export files"
            ) {
                exportVolume()
            }
            RowActionButton(
                systemImage: "square.and.arrow.down",
                isDisabled: isFileActionDisabled,
                help: language.resolved == .zhHans ? "导入文件" : "Import files"
            ) {
                importIntoVolume()
            }
        }
    }

    private var isFileActionDisabled: Bool {
        browserStore.isLoading || browserStore.isFileOperationRunning || browserStore.isImportExportRunning
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
                .help(language.resolved == .zhHans ? "取消新建目录" : "Cancel creating folder")
                Button(language.t(.create)) {
                    let name = newFolderName
                    newFolderName = ""
                    showCreateFolderPopover = false
                    Task { await browserStore.createDirectory(volume: volume, name: name) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newFolderName.trimmed.isEmpty || isFileActionDisabled)
                .help(language.resolved == .zhHans ? "创建目录" : "Create folder")
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
                .help(language.resolved == .zhHans ? "取消重命名" : "Cancel rename")
                Button(language.t(.save)) {
                    let newName = renameEntryName
                    renameEntry = nil
                    Task { await browserStore.renameEntry(volume: volume, entry: entry, newName: newName) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(renameEntryName.trimmed.isEmpty || isFileActionDisabled)
                .help(language.resolved == .zhHans ? "保存新名称" : "Save new name")
            }
        }
        .padding(16)
    }

    private func openEntry(_ entry: VolumeFileEntry) {
        if entry.isDirectory {
            Task { await browserStore.open(entry, volume: volume) }
        } else if entry.isHostBacked {
            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
        } else {
            browserStore.statusMessage = language.resolved == .zhHans
                ? "真实卷内文件暂不支持直接在 Finder 预览。"
                : "Files inside container-backed volumes cannot be previewed in Finder yet."
            browserStore.isError = false
        }
    }

    private func revealEntry(_ entry: VolumeFileEntry) {
        if entry.isHostBacked {
            NSWorkspace.shared.activateFileViewerSelecting([entry.url])
        } else {
            browserStore.statusMessage = language.resolved == .zhHans
                ? "真实卷内文件没有宿主机路径可显示。"
                : "Container-backed volume entries do not have a host path to reveal."
            browserStore.isError = false
        }
    }

    private func exportVolume() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(volume.name).tar"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await browserStore.export(volume: volume, outputPath: url.path) }
    }

    private func importIntoVolume() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await browserStore.importArchive(volume: volume, archivePath: url.path) }
    }

    private func showCloneSheet() {
        cloneVolumeName = suggestedCloneName(for: volume.name)
        cloneVolumeSize = ""
        isShowingCloneSheet = true
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

    private func emptyVolume() {
        Task {
            await runtimeStore.emptyVolume(volume)
            await browserStore.load(volume: volume, relativePath: browserStore.snapshot?.relativePath ?? "")
        }
    }
}

private struct VolumeFileRow: View {
    @Environment(\.appLanguage) private var language
    var entry: VolumeFileEntry
    var isDisabled = false
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
            .disabled(isDisabled)
            .help(entry.isDirectory
                ? (language.resolved == .zhHans ? "打开目录" : "Open folder")
                : (language.resolved == .zhHans ? "查看文件" : "View file"))

            RowActionButton(
                systemImage: "folder",
                isDisabled: isDisabled || !entry.isHostBacked,
                help: entry.isHostBacked
                    ? (language.resolved == .zhHans ? "在访达中显示" : "Reveal in Finder")
                    : (language.resolved == .zhHans ? "真实卷内文件没有宿主机路径" : "No host path for container-backed volume entries")
            ) {
                onReveal()
            }
            RowActionButton(
                systemImage: "pencil",
                isDisabled: isDisabled,
                help: language.resolved == .zhHans ? "重命名" : "Rename"
            ) {
                onRename()
            }
            DestructiveRowActionButton(
                isDisabled: isDisabled,
                help: language.resolved == .zhHans ? "删除文件或目录" : "Delete file or folder"
            ) {
                onDelete()
            }
        }
        .padding(.vertical, 7)
    }
}
