import SwiftUI

struct ImagesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var pullReference = ""
    @State private var selectedReference: String?
    @State private var pendingDelete: ImageSummary?
    @State private var drawerMode: DetailDrawerMode = .overview

    private var filteredImages: [ImageSummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.images }
        return runtimeStore.images.filter {
            $0.reference.lowercased().contains(query) || $0.digest.lowercased().contains(query)
        }
    }

    private var selectedImage: ImageSummary? {
        guard let selectedReference else { return nil }
        return runtimeStore.images.first { $0.reference == selectedReference }
    }

    var body: some View {
        DrawerPageLayout(isDrawerPresented: selectedImage != nil) {
            pageContent
        } drawer: {
            if let selectedImage {
                DetailDrawer(
                    mode: $drawerMode,
                    title: selectedImage.reference,
                    subtitle: "container image inspect",
                    systemImage: "photo.stack",
                    rawText: runtimeStore.selectedInspectorText,
                    onClose: {
                        selectedReference = nil
                    }
                ) {
                    ImageDetailOverview(image: selectedImage)
                }
            }
        }
        .alert("删除镜像？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let image = pendingDelete {
                Button("删除", role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteImage(image.reference) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除镜像 \(pendingDelete?.reference ?? "所选镜像")。被容器引用的镜像可能无法删除。")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.images),
                subtitle: language.t(.imagesSubtitle),
                systemImage: "photo.stack"
            ) {
                HStack(spacing: 8) {
                    TextField("alpine:latest", text: $pullReference)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                    Button {
                        let reference = pullReference
                        pullReference = ""
                        Task { await runtimeStore.pullImage(reference) }
                    } label: {
                        Label(language.t(.pull), systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Text(language.itemCount(filteredImages.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredImages.isEmpty {
                ResourceTable {
                    imageHeader
                } rows: {
                    EmptyStateView(title: language.t(.noImages), message: "Pull an OCI image or build one from a Compose project.", systemImage: "photo.stack")
                        .padding(18)
                }
            } else {
                ResourceTable {
                    imageHeader
                } rows: {
                    ForEach(filteredImages) { image in
                        ResourceTableRow(isSelected: selectedReference == image.reference) {
                            ResourceStatusDot(tint: image.variants.isEmpty ? .secondary : CDTheme.lime, isHollow: image.variants.isEmpty)

                            Text(image.reference)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(image.tag)
                                .font(.callout)
                                .lineLimit(1)
                                .frame(width: 120, alignment: .leading)

                            Text(String(image.id.prefix(12)))
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(width: 130, alignment: .leading)

                            Text(image.createdText)
                                .foregroundStyle(.secondary)
                                .frame(width: 130, alignment: .leading)

                            Text(image.sizeDisplay)
                                .frame(width: 86, alignment: .trailing)

                            HStack(spacing: 10) {
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectImage(image)
                                }
                                DestructiveRowActionButton {
                                    pendingDelete = image
                                }
                            }
                            .frame(width: 92, alignment: .trailing)
                        }
                        .onTapGesture {
                            selectImage(image)
                        }
                    }
                }
            }
        }
    }

    private func selectImage(_ image: ImageSummary) {
        selectedReference = image.reference
        drawerMode = .overview
        Task { await runtimeStore.inspectImage(image.reference) }
    }

    private var imageHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.tag), width: 120)
            ResourceTableHeaderLabel(title: language.t(.imageID), width: 130)
            ResourceTableHeaderLabel(title: language.t(.created), width: 130)
            ResourceTableHeaderLabel(title: language.t(.size), width: 86, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 92, alignment: .trailing)
        }
    }
}

private struct ImageDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var image: ImageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "镜像" : "Image") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: image.reference)
                    DetailInfoRow(title: language.t(.tag), value: image.tag)
                    DetailInfoRow(title: language.t(.imageID), value: String(image.id.prefix(18)), monospaced: true)
                    DetailInfoRow(title: "Digest", value: image.digest, monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: image.createdText)
                    DetailInfoRow(title: language.t(.size), value: image.sizeDisplay)
                }
            }

            DetailSection(title: "Variants") {
                DetailInfoCard {
                    if image.variants.isEmpty {
                        Text(language.resolved == .zhHans ? "没有平台变体信息。" : "No platform variants.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(image.variants, id: \.digest) { variant in
                            DetailInfoRow(
                                title: "\(variant.platform.os)/\(variant.platform.architecture)",
                                value: ByteCountFormatter.string(fromByteCount: variant.size, countStyle: .file)
                            )
                        }
                    }
                }
            }
        }
    }
}
