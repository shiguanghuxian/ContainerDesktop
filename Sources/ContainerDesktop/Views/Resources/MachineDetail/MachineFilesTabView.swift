import SwiftUI

struct MachineFilesTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: MachineDetailStore
    @State private var pathDraft = "/"
    @State private var newFolderName = ""
    @State private var isShowingNewFolder = false
    @State private var renameEntry: ContainerFileEntry?
    @State private var renameName = ""
    @State private var pendingDelete: ContainerFileEntry?
    @State private var previewFontSize = CodePreviewFontSize.defaultValue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if let error = store.fileError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            } else if let status = store.fileStatusText {
                StatusBanner(text: status, systemImage: status.contains("Root") ? "exclamationmark.triangle" : "checkmark.circle", tint: status.contains("Root") ? CDTheme.ember : CDTheme.lime)
            } else if store.fileUsesRoot {
                StatusBanner(text: rootWarningText, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            responsiveFileBrowser
        }
        .onAppear {
            pathDraft = store.filePath
            Task { await store.loadFilesIfNeeded() }
        }
        .onChange(of: store.filePath) {
            pathDraft = store.filePath
        }
        .sheet(isPresented: $isShowingNewFolder) {
            nameSheet(
                title: language.resolved == .zhHans ? "新建目录" : "New Folder",
                placeholder: "folder",
                text: $newFolderName
            ) {
                let name = newFolderName
                newFolderName = ""
                isShowingNewFolder = false
                Task { await store.createDirectory(name: name) }
            }
        }
        .sheet(item: $renameEntry) { entry in
            nameSheet(
                title: language.resolved == .zhHans ? "重命名" : "Rename",
                placeholder: entry.name,
                text: $renameName
            ) {
                let name = renameName
                renameEntry = nil
                renameName = ""
                Task { await store.rename(entry, to: name) }
            }
        }
        .alert("删除文件？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let entry = pendingDelete {
                Button(language.t(.delete), role: .destructive) {
                    pendingDelete = nil
                    Task { await store.delete(entry) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \(pendingDelete?.path ?? "所选路径")。此操作不可撤销。")
        }
    }

    private var rootWarningText: String {
        language.resolved == .zhHans
            ? "Root 模式已开启，文件操作将使用管理员权限。"
            : "Root mode is enabled. File actions will run with administrator privileges."
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            MachineDirectoryBreadcrumb(path: store.filePath) { path in
                Task { await store.loadFiles(path: path) }
            }

            ViewThatFits(in: .horizontal) {
                toolbarWide
                toolbarCompact
            }
        }
        .padding(10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var toolbarWide: some View {
        HStack(spacing: 8) {
            pathControls

            Divider()
                .frame(height: 24)

            rootToggle

            searchField
                .frame(minWidth: 160, idealWidth: 210, maxWidth: 240)

            sortPicker
                .frame(width: 120)

            Spacer(minLength: 8)

            actionButtons
        }
    }

    private var toolbarCompact: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                pathControls
                Button {
                    Task { await store.loadFiles(path: store.filePath) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isFileLoading)
                .help(language.t(.refresh))
            }

            HStack(spacing: 8) {
                rootToggle
                searchField
                    .frame(minWidth: 140, maxWidth: .infinity)
                sortPicker
                    .frame(width: 120)
                Spacer(minLength: 0)
                newFolderButton
            }
        }
    }

    private var pathControls: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.goToParentDirectory() }
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(store.filePath == "/" || store.isFileLoading)
            .help(language.resolved == .zhHans ? "上一级" : "Parent")

            TextField("/", text: $pathDraft)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140, maxWidth: .infinity)
                .onSubmit {
                    Task { await store.loadFiles(path: pathDraft) }
                }

            Button {
                Task { await store.loadFiles(path: pathDraft) }
            } label: {
                Image(systemName: "arrow.right")
            }
            .disabled(store.isFileLoading)
            .help(language.resolved == .zhHans ? "打开路径" : "Open path")
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    private var rootToggle: some View {
        Toggle("Root", isOn: Binding(
            get: { store.fileUsesRoot },
            set: { enabled in
                Task { await store.setFileUsesRoot(enabled) }
            }
        ))
        .toggleStyle(.switch)
        .disabled(store.isFileLoading || store.isFileSaving)
        .help(language.resolved == .zhHans ? "使用 Root 权限执行文件操作" : "Run file actions as root")
        .fixedSize()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(language.t(.search), text: $store.fileSearchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var sortPicker: some View {
        Picker("", selection: $store.fileSort) {
            ForEach(ContainerFileSort.allCases) { sort in
                Text(sort.title(language: language)).tag(sort)
            }
        }
        .labelsHidden()
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            newFolderButton

            Button {
                Task { await store.loadFiles(path: store.filePath) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(store.isFileLoading)
            .help(language.t(.refresh))
        }
        .fixedSize()
    }

    private var newFolderButton: some View {
        Button {
            isShowingNewFolder = true
        } label: {
            Label(language.resolved == .zhHans ? "新建目录" : "New Folder", systemImage: "folder.badge.plus")
        }
        .disabled(store.isFileLoading)
        .help(language.resolved == .zhHans ? "新建目录" : "Create folder")
    }

    private var responsiveFileBrowser: some View {
        GeometryReader { proxy in
            let useCompactLayout = proxy.size.width < 920

            Group {
                if useCompactLayout {
                    VStack(alignment: .leading, spacing: 12) {
                        fileList
                            .frame(maxWidth: .infinity)
                            .layoutPriority(2)
                        previewPane
                            .frame(maxWidth: .infinity, minHeight: 260)
                            .layoutPriority(1)
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        fileList
                            .frame(maxWidth: .infinity)
                            .layoutPriority(2)
                        previewPane
                            .frame(minWidth: 280, idealWidth: 360, maxWidth: 400)
                            .layoutPriority(1)
                    }
                }
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
            .frame(minHeight: 500, alignment: .topLeading)
        }
        .frame(minHeight: 500)
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ResourceTableHeaderLabel(title: language.t(.name))
                ResourceTableHeaderLabel(title: language.t(.size), width: 76, alignment: .trailing)
                ResourceTableHeaderLabel(title: language.t(.modified), width: 118)
                ResourceTableHeaderLabel(title: language.t(.mode), width: 88)
                ResourceTableHeaderLabel(title: "", width: 56, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(CDTheme.tableHeaderSurface)

            Divider()

            if store.isFileLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else if store.filteredFileEntries.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "目录为空" : "Empty directory",
                    message: store.filePath,
                    systemImage: "folder"
                )
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredFileEntries) { entry in
                            fileRow(entry)
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
                .thinScrollBars()
            }
        }
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func fileRow(_ entry: ContainerFileEntry) -> some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.openFileEntry(entry) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: entry.kind.systemImage)
                        .foregroundStyle(entry.isDirectory ? CDTheme.dockerBlue : .secondary)
                        .frame(width: 18)
                    Text(entry.displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .layoutPriority(2)
            .help(entry.path)
            .contextMenu {
                fileContextMenu(entry)
            }

            Text(entry.sizeDisplay)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .trailing)
            Text(entry.modifiedText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 118, alignment: .leading)
            Text(entry.mode)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            HStack(spacing: 6) {
                Button {
                    renameName = entry.name
                    renameEntry = entry
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "重命名" : "Rename")

                Button(role: .destructive) {
                    pendingDelete = entry
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(language.t(.delete))
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .contentShape(Rectangle())
        .background(store.selectedFile?.path == entry.path ? CDTheme.selectionSurface : .clear)
    }

    @ViewBuilder
    private func fileContextMenu(_ entry: ContainerFileEntry) -> some View {
        Button(language.resolved == .zhHans ? "打开" : "Open") {
            Task { await store.openFileEntry(entry) }
        }
        Button(language.resolved == .zhHans ? "重命名" : "Rename") {
            renameName = entry.name
            renameEntry = entry
        }
        Divider()
        Button(language.t(.delete), role: .destructive) {
            pendingDelete = entry
        }
    }

    @ViewBuilder
    private var previewPane: some View {
        if let selectedFile = store.selectedFile, !selectedFile.isDirectory {
            FilePreviewCodePanel(
                text: $store.filePreviewText,
                fontSize: $previewFontSize,
                title: selectedFile.displayName,
                subtitle: selectedFile.path,
                fileName: selectedFile.path,
                isEditable: store.isSelectedFileEditable,
                isDisabled: !store.isSelectedFileEditable || store.isFileSaving
            ) {
                Button {
                    Task { await store.saveSelectedFile() }
                } label: {
                    Label(language.t(.save), systemImage: "square.and.arrow.down")
                }
                .disabled(!store.isSelectedFileEditable || store.isFileSaving)
                .help(language.resolved == .zhHans ? "保存文件修改" : "Save file changes")
            }
        } else {
            FileBrowserFolderInfoPanel(
                info: FileBrowserFolderInfo(
                    path: store.filePath,
                    entries: store.fileEntries,
                    sourceText: store.fileUsesRoot
                        ? (language.resolved == .zhHans ? "Root 模式" : "Root mode")
                        : nil
                )
            )
        }
    }

    private func nameSheet(title: String, placeholder: String, text: Binding<String>, onConfirm: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 340)
            HStack {
                Spacer()
                Button("取消") {
                    isShowingNewFolder = false
                    renameEntry = nil
                }
                Button("确定", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
    }
}

private struct MachineDirectoryBreadcrumb: View {
    @Environment(\.appLanguage) private var language
    var path: String
    var onSelect: (String) -> Void

    private var parts: [(title: String, path: String)] {
        if path == "/" { return [("/", "/")] }
        var result: [(String, String)] = [("/", "/")]
        var current = ""
        for part in path.split(separator: "/") {
            current += "/\(part)"
            result.append((String(part), current))
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    Button(part.title) {
                        onSelect(part.path)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == parts.count - 1 ? .primary : CDTheme.dockerBlue)
                    .help(language.resolved == .zhHans ? "打开路径" : "Open path")

                    if index < parts.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout.weight(.medium))
        }
    }
}
