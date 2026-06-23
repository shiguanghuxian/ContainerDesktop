import AppKit
import SwiftUI

struct ContainerFilesTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ContainerDetailStore
    @State private var pathDraft = "/"
    @State private var newFolderName = ""
    @State private var isShowingNewFolder = false
    @State private var renameEntry: ContainerFileEntry?
    @State private var renameName = ""
    @State private var pendingDelete: ContainerFileEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolbar

            if let error = store.fileError {
                StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            } else if let status = store.fileStatusText {
                StatusBanner(text: status, systemImage: "checkmark.circle", tint: CDTheme.lime)
            }

            responsiveFileBrowser
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            pathDraft = store.filePath
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

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            DirectoryBreadcrumb(path: store.filePath) { path in
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
                .help(language.t(.refresh))
            }

            HStack(spacing: 8) {
                searchField
                    .frame(minWidth: 140, maxWidth: .infinity)
                sortPicker
                    .frame(width: 120)
                Spacer(minLength: 0)
                actionButtonsWithoutRefresh
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
            .disabled(store.filePath == "/")
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
            .help(language.resolved == .zhHans ? "打开路径" : "Open path")
        }
        .frame(minWidth: 0, maxWidth: .infinity)
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
            actionButtonsWithoutRefresh

            Button {
                Task { await store.loadFiles(path: store.filePath) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help(language.t(.refresh))
        }
        .fixedSize()
    }

    private var actionButtonsWithoutRefresh: some View {
        HStack(spacing: 8) {
            Button {
                isShowingNewFolder = true
            } label: {
                Label(language.resolved == .zhHans ? "新建目录" : "New Folder", systemImage: "folder.badge.plus")
            }
            .help(language.resolved == .zhHans ? "新建目录" : "Create folder")

            Button {
                upload()
            } label: {
                Label(language.resolved == .zhHans ? "上传" : "Upload", systemImage: "square.and.arrow.up")
            }
            .help(language.resolved == .zhHans ? "上传文件" : "Upload file")
        }
        .fixedSize()
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
                ResourceTableHeaderLabel(title: "", width: 86, alignment: .trailing)
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
                    download(entry)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "下载" : "Download")

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
            .frame(width: 86, alignment: .trailing)
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
        Button(language.resolved == .zhHans ? "下载" : "Download") {
            download(entry)
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

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedFile?.displayName ?? (language.resolved == .zhHans ? "文件预览" : "Preview"))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(store.selectedFile?.path ?? (language.resolved == .zhHans ? "选择一个文件查看内容" : "Select a file to preview"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    Task { await store.saveSelectedFile() }
                } label: {
                    Label(language.t(.save), systemImage: "square.and.arrow.down")
                }
                .disabled(store.selectedFile == nil || store.selectedFile?.isDirectory == true || store.isFileSaving)
                .help(language.resolved == .zhHans ? "保存文件修改" : "Save file changes")
            }

            TextEditor(text: $store.filePreviewText)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(CDTheme.codeSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
                .disabled(store.selectedFile == nil || store.selectedFile?.isDirectory == true)
        }
        .padding(12)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
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

    private func upload() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await store.upload(localURL: url) }
        }
    }

    private func download(_ entry: ContainerFileEntry) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = entry.name
        if panel.runModal() == .OK, let url = panel.url {
            Task { await store.download(entry, to: url) }
        }
    }
}

private struct DirectoryBreadcrumb: View {
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
