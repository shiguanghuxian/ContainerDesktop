import AppKit
import SwiftUI

struct DockerCommandConverterView: View {
    @Environment(\.appLanguage) private var language
    @State private var dockerCommand = "docker run --name web -p 8080:80 nginx:latest"
    @State private var selectedCategory: DockerCommonCommandCategory = .containers
    @State private var commonSearchText = ""
    @State private var copiedMessage: String?

    private var conversion: DockerCommandConversionResult {
        DockerCommandConverter.convert(dockerCommand)
    }

    private var filteredCommonCommands: [DockerCommonCommand] {
        let categoryCommands = DockerCommandConverter.commonCommands.filter { $0.category == selectedCategory }
        let query = commonSearchText.trimmed.lowercased()
        guard !query.isEmpty else { return categoryCommands }
        return categoryCommands.filter {
            $0.title(language: language).lowercased().contains(query)
                || $0.dockerCommand.lowercased().contains(query)
                || $0.containerCommand.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.commandConverter),
                subtitle: language.t(.commandConverterSubtitle),
                systemImage: "arrow.left.arrow.right.square"
            ) {
                HStack(spacing: 8) {
                    Button {
                        copy(conversion.commandText, message: language.resolved == .zhHans ? "已复制转换结果" : "Converted command copied")
                    } label: {
                        Label(language.resolved == .zhHans ? "复制结果" : "Copy Result", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(conversion.commandText.isEmpty)

                    Button {
                        dockerCommand = ""
                    } label: {
                        Label(language.resolved == .zhHans ? "清空" : "Clear", systemImage: "xmark.circle")
                    }
                    .disabled(dockerCommand.isEmpty)
                }
            }

            if let copiedMessage {
                StatusBanner(text: copiedMessage, systemImage: "checkmark.circle", tint: CDTheme.lime)
                    .frame(maxWidth: 520)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    converterInputPanel
                        .frame(minWidth: 360, maxWidth: .infinity)
                    converterOutputPanel
                        .frame(minWidth: 420, maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 16) {
                    converterInputPanel
                    converterOutputPanel
                }
            }

            commonCommandsPanel
            migrationNotesPanel
        }
    }

    private var converterInputPanel: some View {
        PanelView(
            title: language.resolved == .zhHans ? "Docker 命令" : "Docker Command",
            subtitle: language.resolved == .zhHans ? "支持单行或多行粘贴" : "Single-line or multi-line input",
            systemImage: "terminal"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $dockerCommand)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 188)
                    .background(CDTheme.codeSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(CDTheme.separator)
                    }

                HStack(spacing: 8) {
                    ForEach(sampleCommands, id: \.self) { sample in
                        Button(sample) {
                            dockerCommand = sample
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
            }
        }
    }

    private var converterOutputPanel: some View {
        PanelView(
            title: language.resolved == .zhHans ? "Apple/container 命令" : "Apple/container Command",
            subtitle: statusText,
            systemImage: "shippingbox"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: statusText, systemImage: statusImage, tint: statusTint)
                    Spacer()
                    Button {
                        copy(conversion.commandText, message: language.resolved == .zhHans ? "已复制转换结果" : "Converted command copied")
                    } label: {
                        Label(language.resolved == .zhHans ? "复制" : "Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(conversion.commandText.isEmpty)
                }

                TerminalBlock(
                    text: conversion.commandText.nilIfBlank ?? (language.resolved == .zhHans ? "等待输入 Docker 命令。" : "Waiting for a Docker command."),
                    minHeight: 188
                )

                if !conversion.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conversion.notes, id: \.self) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: conversion.status == .converted ? "checkmark.circle" : "exclamationmark.triangle")
                                    .foregroundStyle(statusTint)
                                    .frame(width: 16)
                                Text(note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var commonCommandsPanel: some View {
        PanelView(
            title: language.resolved == .zhHans ? "常用命令一键复制" : "Common Commands",
            subtitle: language.resolved == .zhHans ? "按场景快速迁移日常操作" : "Quick migration templates by workflow",
            systemImage: "rectangle.grid.2x2"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        ThemedSegmentedPicker(
                            options: DockerCommonCommandCategory.allCases,
                            selection: $selectedCategory,
                            title: { $0.title(language: language) }
                        )
                        .frame(maxWidth: 560)
                        Spacer()
                        searchField
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ThemedSegmentedPicker(
                            options: DockerCommonCommandCategory.allCases,
                            selection: $selectedCategory,
                            title: { $0.title(language: language) }
                        )
                        searchField
                    }
                }

                if filteredCommonCommands.isEmpty {
                    EmptyStateView(
                        title: language.resolved == .zhHans ? "没有匹配命令" : "No matching commands",
                        message: language.resolved == .zhHans ? "换一个分类或搜索关键词。" : "Try another category or search query.",
                        systemImage: "magnifyingglass"
                    )
                    .padding(.vertical, 16)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                        ForEach(filteredCommonCommands) { item in
                            DockerCommonCommandCard(
                                item: item,
                                onUse: {
                                    dockerCommand = item.dockerCommand
                                },
                                onCopy: {
                                    copy(item.containerCommand, message: language.resolved == .zhHans ? "已复制命令" : "Command copied")
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var migrationNotesPanel: some View {
        PanelView(
            title: language.resolved == .zhHans ? "迁移提示" : "Migration Notes",
            subtitle: language.resolved == .zhHans ? "避免把 Docker daemon 假设直接带过来" : "Avoid carrying Docker daemon assumptions directly",
            systemImage: "lightbulb"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DockerMigrationNote(
                    title: language.resolved == .zhHans ? "镜像命令使用 image 子命令" : "Image commands use the image namespace",
                    message: "docker pull nginx -> container image pull nginx"
                )
                DockerMigrationNote(
                    title: language.resolved == .zhHans ? "安全清理不要默认删除 volume" : "Safe cleanup does not delete volumes by default",
                    message: "container prune && container image prune"
                )
                DockerMigrationNote(
                    title: language.resolved == .zhHans ? "Compose 使用 container-compose" : "Compose uses container-compose",
                    message: "docker compose up -d -> container-compose up -d"
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(language.t(.search), text: $commonSearchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .frame(maxWidth: 280)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var sampleCommands: [String] {
        [
            "docker ps -a",
            "docker logs -f --tail 100 web",
            "docker images",
        ]
    }

    private var statusText: String {
        let isChinese = language.resolved == .zhHans
        switch conversion.status {
        case .empty:
            return isChinese ? "等待输入" : "Waiting"
        case .converted:
            return isChinese ? "已转换" : "Converted"
        case .warning:
            return isChinese ? "需要核对" : "Review needed"
        case .unsupported:
            return isChinese ? "暂不支持" : "Unsupported"
        case .invalid:
            return isChinese ? "解析失败" : "Invalid command"
        }
    }

    private var statusImage: String {
        switch conversion.status {
        case .empty:
            return "circle"
        case .converted:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .unsupported, .invalid:
            return "xmark.octagon"
        }
    }

    private var statusTint: Color {
        switch conversion.status {
        case .empty:
            return .secondary
        case .converted:
            return CDTheme.lime
        case .warning:
            return CDTheme.ember
        case .unsupported, .invalid:
            return .red
        }
    }

    private func copy(_ value: String, message: String) {
        let trimmed = value.trimmed
        guard !trimmed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(trimmed, forType: .string)
        copiedMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if copiedMessage == message {
                copiedMessage = nil
            }
        }
    }
}

private struct DockerCommonCommandCard: View {
    @Environment(\.appLanguage) private var language
    var item: DockerCommonCommand
    var onUse: () -> Void
    var onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title(language: language))
                        .font(.callout.weight(.semibold))
                    if let note = item.note(language: language) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                DockerCommandSnippet(label: "Docker", text: item.dockerCommand)
                DockerCommandSnippet(label: "container", text: item.containerCommand)
            }

            HStack {
                Button {
                    onUse()
                } label: {
                    Label(language.resolved == .zhHans ? "填入转换器" : "Use", systemImage: "arrow.up.left.square")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    onCopy()
                } label: {
                    Label(language.resolved == .zhHans ? "复制 container" : "Copy container", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(13)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

private struct DockerCommandSnippet: View {
    var label: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(CDTheme.codeSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.hairline)
                }
        }
    }
}

private struct DockerMigrationNote: View {
    var title: String
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(12)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
