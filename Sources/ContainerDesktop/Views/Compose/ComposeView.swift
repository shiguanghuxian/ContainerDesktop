import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore

    @State private var showImporter = false
    @State private var searchText = ""
    @State private var selectedProjectID: ComposeProject.ID?
    @State private var pendingRemove: ComposeProject?
    @State private var drawerMode: DetailDrawerMode = .overview

    private var composeTypes: [UTType] {
        [
            UTType(filenameExtension: "yml") ?? .data,
            UTType(filenameExtension: "yaml") ?? .data,
            .data,
        ]
    }

    private var selectedProject: ComposeProject? {
        guard let selectedProjectID else { return nil }
        return composeStore.projects.first { $0.id == selectedProjectID }
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

    var body: some View {
        DrawerPageLayout(isDrawerPresented: selectedProject != nil) {
            pageContent
        } drawer: {
            if let selectedProject {
                DetailDrawer(
                    mode: $drawerMode,
                    title: selectedProject.name,
                    subtitle: selectedProject.path.path,
                    systemImage: "square.stack.3d.up",
                    rawText: rawComposeText(for: selectedProject),
                    rawLabel: "YAML",
                    onClose: {
                        selectedProjectID = nil
                    }
                ) {
                    ComposeProjectOverview(project: selectedProject, lastOutput: composeStore.lastOutput)
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
            Text("只会从 ContainerDesktop 列表中移除 \(pendingRemove?.name ?? "该项目")，不会删除文件。")
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
                    Button {
                        Task { await composeStore.reloadProjects() }
                    } label: {
                        Label(language.t(.reload), systemImage: "arrow.clockwise")
                    }
                }
            }

            if !runtimeStore.environment.containerComposeAvailable {
                PanelView(title: "Container-Compose 未安装", subtitle: language.t(.emptyInstallCompose), systemImage: "exclamationmark.triangle") {
                    TerminalBlock(text: "brew install container-compose", minHeight: 60)
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
                        ResourceTableRow(isSelected: selectedProject?.id == project.id) {
                            ResourceStatusDot(tint: composeStore.busyProjectID == project.id ? CDTheme.ember : CDTheme.dockerBlue)

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

                            Text("\(project.volumes.count) / \(project.networks.count)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 96, alignment: .trailing)

                            Text(project.lastModified.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)

                            HStack(spacing: 7) {
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectProject(project)
                                }
                                RowActionButton(systemImage: "hammer") {
                                    selectProject(project)
                                    Task {
                                        await composeStore.build(project)
                                        await runtimeStore.refreshAll()
                                    }
                                }
                                RowActionButton(systemImage: "play.fill", tint: CDTheme.lime) {
                                    selectProject(project)
                                    Task {
                                        await composeStore.up(project)
                                        await runtimeStore.refreshAll()
                                    }
                                }
                                RowActionButton(systemImage: "stop.fill", tint: CDTheme.ember) {
                                    selectProject(project)
                                    Task {
                                        await composeStore.down(project)
                                        await runtimeStore.refreshAll()
                                    }
                                }
                                DestructiveRowActionButton {
                                    pendingRemove = project
                                }
                            }
                            .frame(width: 172, alignment: .trailing)
                        }
                        .onTapGesture {
                            selectProject(project)
                        }
                    }
                }
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.services), width: 72, alignment: .trailing)
            ResourceTableHeaderLabel(title: "Vol / Net", width: 96, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.modified), width: 140)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 172, alignment: .trailing)
        }
    }

    private func selectProject(_ project: ComposeProject) {
        selectedProjectID = project.id
        drawerMode = .overview
    }

    private func rawComposeText(for project: ComposeProject) -> String {
        (try? String(contentsOf: project.path, encoding: .utf8)) ?? "Unable to read \(project.path.path)"
    }
}

private struct ComposeProjectOverview: View {
    @Environment(\.appLanguage) private var language
    var project: ComposeProject
    var lastOutput: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "项目" : "Project") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: project.name)
                    DetailInfoRow(title: language.t(.services), value: "\(project.services.count)")
                    DetailInfoRow(title: language.t(.volumes), value: project.volumes.isEmpty ? "—" : project.volumes.joined(separator: ", "))
                    DetailInfoRow(title: language.t(.networks), value: project.networks.isEmpty ? "—" : project.networks.joined(separator: ", "))
                    DetailInfoRow(title: language.t(.modified), value: project.lastModified.formatted(date: .abbreviated, time: .shortened))
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
                        DetailInfoCard {
                            DetailInfoRow(title: language.t(.name), value: service.name)
                            DetailInfoRow(title: language.t(.image), value: service.image ?? service.buildContext ?? "—")
                            DetailInfoRow(title: "Ports", value: service.ports.isEmpty ? "—" : service.ports.joined(separator: ", "), monospaced: true)
                            DetailInfoRow(title: "Platform", value: service.platform ?? "—")
                            DetailInfoRow(title: "Depends", value: service.dependsOn.isEmpty ? "—" : service.dependsOn.joined(separator: ", "))
                        }
                    }
                }
            }

            DetailSection(title: language.t(.commandOutput)) {
                TerminalBlock(text: lastOutput, minHeight: 180)
            }
        }
    }
}
