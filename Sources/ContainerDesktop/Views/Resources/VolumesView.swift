import SwiftUI

struct VolumesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var newVolumeName = ""
    @State private var newVolumeSize = ""
    @State private var showCreatePopover = false
    @State private var selectedName: String?
    @State private var pendingDelete: VolumeSummary?
    @State private var drawerMode: DetailDrawerMode = .overview

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
        DrawerPageLayout(isDrawerPresented: selectedVolume != nil) {
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
                    VolumeDetailOverview(volume: selectedVolume)
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
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.volumes),
                subtitle: language.t(.volumesSubtitle),
                systemImage: "externaldrive"
            ) {
                Button {
                    showCreatePopover = true
                } label: {
                    Label(language.t(.createVolume), systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .popover(isPresented: $showCreatePopover, arrowEdge: .bottom) {
                    createVolumeForm
                }
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
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectVolume(volume)
                                }
                                DestructiveRowActionButton {
                                    pendingDelete = volume
                                }
                            }
                            .frame(width: 78, alignment: .trailing)
                        }
                        .onTapGesture {
                            selectVolume(volume)
                        }
                    }
                }
            }
        }
    }

    private func selectVolume(_ volume: VolumeSummary) {
        selectedName = volume.name
        drawerMode = .overview
        Task { await runtimeStore.inspectVolume(volume.name) }
    }

    private var createVolumeForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t(.createVolume))
                .font(.headline)
            TextField(language.t(.volumeName), text: $newVolumeName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            TextField("10g", text: $newVolumeSize)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Spacer()
                Button("取消") {
                    showCreatePopover = false
                }
                Button(language.t(.create)) {
                    let name = newVolumeName
                    let size = newVolumeSize
                    newVolumeName = ""
                    newVolumeSize = ""
                    showCreatePopover = false
                    Task { await runtimeStore.createVolume(name: name, size: size) }
                }
                .buttonStyle(.borderedProminent)
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
            ResourceTableHeaderLabel(title: language.t(.actions), width: 78, alignment: .trailing)
        }
    }
}

private struct VolumeDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var volume: VolumeSummary

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
        }
    }
}
