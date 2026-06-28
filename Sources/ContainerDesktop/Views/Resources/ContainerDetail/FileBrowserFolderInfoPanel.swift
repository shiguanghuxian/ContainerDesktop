import SwiftUI

struct FileBrowserFolderInfo: Equatable, Sendable {
    var path: String
    var totalCount: Int
    var fileCount: Int
    var directoryCount: Int
    var visibleFileBytes: Int64
    var sourceText: String?

    var visibleFileSizeText: String {
        ByteCountFormatter.string(fromByteCount: visibleFileBytes, countStyle: .file)
    }

    init(
        path: String,
        entries: [ContainerFileEntry],
        sourceText: String? = nil
    ) {
        self.init(
            path: path,
            totalCount: entries.count,
            fileCount: entries.filter { !$0.isDirectory }.count,
            directoryCount: entries.filter(\.isDirectory).count,
            visibleFileBytes: entries.reduce(Int64(0)) { total, entry in
                entry.isDirectory ? total : total + entry.size
            },
            sourceText: sourceText
        )
    }

    init(
        path: String,
        entries: [VolumeFileEntry],
        sourceText: String? = nil
    ) {
        self.init(
            path: path,
            totalCount: entries.count,
            fileCount: entries.filter { !$0.isDirectory }.count,
            directoryCount: entries.filter(\.isDirectory).count,
            visibleFileBytes: entries.reduce(Int64(0)) { total, entry in
                entry.isDirectory ? total : total + (entry.size ?? 0)
            },
            sourceText: sourceText
        )
    }

    init(
        path: String,
        totalCount: Int,
        fileCount: Int,
        directoryCount: Int,
        visibleFileBytes: Int64,
        sourceText: String? = nil
    ) {
        self.path = path.isEmpty ? "/" : path
        self.totalCount = totalCount
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.visibleFileBytes = visibleFileBytes
        self.sourceText = sourceText?.nilIfBlank
    }
}

struct FileBrowserFolderInfoPanel: View {
    @Environment(\.appLanguage) private var language
    var info: FileBrowserFolderInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            statsGrid
            hint
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 38, height: 38)
                .background(CDTheme.dockerBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(language.resolved == .zhHans ? "文件夹信息" : "Folder Info")
                    .font(.headline.weight(.semibold))
                Text(info.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if let sourceText = info.sourceText {
                    Label(sourceText, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                statCell(
                    title: language.resolved == .zhHans ? "总项" : "Items",
                    value: "\(info.totalCount)",
                    systemImage: "list.bullet.rectangle"
                )
                statCell(
                    title: language.resolved == .zhHans ? "文件夹" : "Folders",
                    value: "\(info.directoryCount)",
                    systemImage: "folder"
                )
            }
            GridRow {
                statCell(
                    title: language.resolved == .zhHans ? "文件" : "Files",
                    value: "\(info.fileCount)",
                    systemImage: "doc"
                )
                statCell(
                    title: language.resolved == .zhHans ? "可见文件大小" : "Visible Size",
                    value: info.visibleFileSizeText,
                    systemImage: "tray.full"
                )
            }
        }
    }

    private func statCell(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator.opacity(0.75))
        }
    }

    private var hint: some View {
        Label(
            language.resolved == .zhHans
                ? "选择文本文件后会在此处预览或编辑内容。"
                : "Select a text file to preview or edit its contents here.",
            systemImage: "doc.text.magnifyingglass"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}
