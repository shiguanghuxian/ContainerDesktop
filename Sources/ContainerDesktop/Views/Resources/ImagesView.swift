import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ImageDrawerSelection: Equatable {
    case tasks
    case image(String)
    case repositoryGroup(String)
}

private struct ImageDeleteRequest: Identifiable {
    var references: [String]
    var isBatch: Bool

    var id: String {
        "\(isBatch)-\(references.joined(separator: "\u{1F}"))"
    }
}

private enum ImageReferenceSelectionAction: Hashable {
    case openDetail
    case run
    case tag
    case push
    case export
    case delete
}

private struct ImageReferenceSelectionRequest: Identifiable {
    var id = UUID()
    var title: String
    var images: [ImageSummary]
    var action: ImageReferenceSelectionAction
}

struct ImagesView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage(ImageListDisplayMode.defaultsKey, store: .containerDesktopShared) private var imageListDisplayModeRaw = ImageListDisplayMode.tags.rawValue
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore
    @Binding var resourceRoute: AppResourceRoute?
    @State private var searchText = ""
    @State private var selectedRegistryFilter = ImageRegistryFilterOption.allID
    @State private var pullReference = "alpine:latest"
    @State private var useCustomPullReference = false
    @State private var customPullReference = ""
    @State private var detailReference: String?
    @State private var selectedImageReferences = Set<String>()
    @State private var pendingDeleteRequest: ImageDeleteRequest?
    @State private var isConfirmingPruneDanglingImages = false
    @State private var showPullPopover = false
    @State private var showBuildPopover = false
    @State private var showTagPopover = false
    @State private var showPushPopover = false
    @State private var showSavePopover = false
    @State private var showLoadPopover = false
    @State private var buildContextPath = ""
    @State private var buildDockerfilePath = ""
    @State private var buildTag = "localhost/containerdesktop/app:latest"
    @State private var buildPlatform = ""
    @State private var buildArchitecturesText = ""
    @State private var buildOperatingSystemsText = ""
    @State private var buildCPUs = ""
    @State private var buildMemory = ""
    @State private var buildTarget = ""
    @State private var buildOutput = ""
    @State private var buildProgress = "auto"
    @State private var buildArgsText = ""
    @State private var buildLabelsText = ""
    @State private var buildSecretsText = ""
    @State private var buildDNSText = ""
    @State private var buildDNSSearchText = ""
    @State private var buildDNSOptionsText = ""
    @State private var buildDNSDomain = ""
    @State private var buildNoCache = false
    @State private var buildPull = false
    @State private var buildQuiet = false
    @State private var tagSource = ""
    @State private var tagTarget = ""
    @State private var pushReference = ""
    @State private var pushPlatform = ""
    @State private var pushScheme = "auto"
    @State private var saveReferencesText = ""
    @State private var saveOutputPath = ""
    @State private var savePlatform = ""
    @State private var saveOS = ""
    @State private var saveArch = ""
    @State private var loadInputPath = ""
    @State private var loadForce = false
    @State private var drawerSelection: ImageDrawerSelection?
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var referenceSelectionRequest: ImageReferenceSelectionRequest?

    init(
        runtimeStore: RuntimeStore,
        operationStore: AppOperationStore,
        resourceRoute: Binding<AppResourceRoute?> = .constant(nil)
    ) {
        self.runtimeStore = runtimeStore
        self.operationStore = operationStore
        _resourceRoute = resourceRoute
    }

    private var imageListDisplayMode: ImageListDisplayMode {
        ImageListDisplayMode(rawValue: imageListDisplayModeRaw) ?? .tags
    }

    private var registryFilteredImages: [ImageSummary] {
        selectedRegistryFilter == ImageRegistryFilterOption.allID
            ? runtimeStore.images
            : runtimeStore.images.filter { $0.registryIdentity.id == selectedRegistryFilter }
    }

    private var imageListEntries: [ImageListEntry] {
        let entries = ImageListEntry.make(
            images: registryFilteredImages,
            displayMode: imageListDisplayMode
        )
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.searchText.contains(query)
        }
    }

    private var registryFilterOptions: [ImageRegistryFilterOption] {
        ImageRegistryFilterOptions.make(
            images: runtimeStore.images,
            registries: runtimeStore.registries
        )
    }

    private var filteredImageReferences: [String] {
        imageListEntries.flatMap(\.references)
    }

    private var filteredImageReferenceSet: Set<String> {
        Set(filteredImageReferences)
    }

    private var selectedExistingImageReferences: [String] {
        filteredImageReferences.filter { selectedImageReferences.contains($0) }
    }

    private var areAllFilteredImagesSelected: Bool {
        !filteredImageReferences.isEmpty && filteredImageReferenceSet.isSubset(of: selectedImageReferences)
    }

    private var hasFilteredImageSelection: Bool {
        !selectedImageReferences.isDisjoint(with: filteredImageReferenceSet)
    }

    private var detailImage: ImageSummary? {
        guard let detailReference else { return nil }
        return runtimeStore.images.first { $0.reference == detailReference }
    }

    private var drawerImage: ImageSummary? {
        guard case let .image(reference) = drawerSelection else { return nil }
        return runtimeStore.images.first { $0.reference == reference }
    }

    private var drawerRepositoryGroup: ImageRepositoryGroup? {
        guard case let .repositoryGroup(id) = drawerSelection else { return nil }
        return ImageRepositoryGroup.make(images: registryFilteredImages).first { $0.id == id }
    }

    private var isDrawerPresented: Bool {
        switch drawerSelection {
        case .tasks:
            true
        case .image:
            drawerImage != nil
        case .repositoryGroup:
            drawerRepositoryGroup != nil
        case nil:
            false
        }
    }

    private var drawerWidth: CGFloat {
        switch drawerSelection {
        case .tasks:
            return 620
        case .repositoryGroup:
            return 520
        case .image, nil:
            return 430
        }
    }

    private var pullChoices: [String] {
        FormPresetOptions.imageChoices(
            current: pullReference,
            localImages: [],
            suggestions: FormPresetOptions.containerImages
        )
    }

    var body: some View {
        Group {
            if let detailImage {
                ImageDetailPage(
                    runtimeStore: runtimeStore,
                    operationStore: operationStore,
                    reference: detailImage.reference,
                    isPresented: Binding(
                        get: { detailReference != nil },
                        set: { if !$0 { closeDetail() } }
                    ),
                    showTasksDrawer: Binding(
                        get: { drawerSelection == .tasks },
                        set: { isPresented in
                            if isPresented {
                                drawerSelection = .tasks
                            } else if drawerSelection == .tasks {
                                drawerSelection = nil
                            }
                        }
                    ),
                    resourceRoute: $resourceRoute
                )
            } else {
                DrawerPageLayout(
                    isDrawerPresented: isDrawerPresented,
                    onDismiss: closeDrawer,
                    drawerWidth: drawerWidth
                ) {
                    pageContent
                } drawer: {
                    drawerContent
                }
            }
        }
        .alert(deleteAlertTitle, isPresented: Binding(
            get: { pendingDeleteRequest != nil },
            set: { if !$0 { pendingDeleteRequest = nil } }
        )) {
            if let request = pendingDeleteRequest {
                Button(deleteAlertButtonTitle(for: request), role: .destructive) {
                    pendingDeleteRequest = nil
                    if request.isBatch {
                        deleteImages(request.references)
                    } else if let reference = request.references.first {
                        deleteImage(reference)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteAlertMessage)
        }
        .alert(language.resolved == .zhHans ? "清理无标签镜像？" : "Prune dangling images?", isPresented: $isConfirmingPruneDanglingImages) {
            Button(language.resolved == .zhHans ? "清理" : "Prune", role: .destructive) {
                pruneDanglingImages()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(language.resolved == .zhHans ? "将删除 dangling/无标签镜像。仍被容器引用或 CLI 拒绝删除的镜像会保留或返回错误。" : "This deletes dangling or untagged images. Images referenced by containers or rejected by the CLI are kept or reported as errors.")
        }
        .onChange(of: runtimeStore.images.map(\.reference)) { _, _ in
            pruneSelectedImages()
            pruneSelectedRegistryFilter()
        }
        .onChange(of: runtimeStore.registries.map(\.server)) { _, _ in
            pruneSelectedRegistryFilter()
        }
        .onAppear {
            consumeResourceRoute()
        }
        .onChange(of: resourceRoute) { _, route in
            consumeResourceRoute(route)
        }
        .confirmationDialog(
            referenceSelectionRequest?.title ?? "",
            isPresented: Binding(
                get: { referenceSelectionRequest != nil },
                set: { if !$0 { referenceSelectionRequest = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let request = referenceSelectionRequest {
                ForEach(request.images, id: \.reference) { image in
                    Button(image.reference) {
                        performReferenceSelection(image, action: request.action)
                        referenceSelectionRequest = nil
                    }
                }
            }
            Button("取消", role: .cancel) {
                referenceSelectionRequest = nil
            }
        } message: {
            Text(language.resolved == .zhHans ? "选择要操作的镜像 tag。" : "Choose the image tag to use.")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeader

            if let message = runtimeStore.imageOperationStatusMessage {
                StatusBanner(
                    text: message,
                    systemImage: runtimeStore.imageOperationStatusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                    tint: runtimeStore.imageOperationStatusIsError ? CDTheme.ember : CDTheme.lime
                )
            }

            imageToolbar

            if imageListEntries.isEmpty {
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
                    ForEach(imageListEntries) { entry in
                        imageRow(entry)
                    }
                }
            }
        }
        .sheet(isPresented: $showPullPopover) {
            pullImageForm
        }
        .sheet(isPresented: $showBuildPopover) {
            buildImageForm
        }
        .sheet(isPresented: $showSavePopover) {
            saveImageForm
        }
        .sheet(isPresented: $showLoadPopover) {
            loadImageForm
        }
        .sheet(isPresented: $showTagPopover) {
            tagImageForm
        }
        .sheet(isPresented: $showPushPopover) {
            pushImageForm
        }
    }

    private var pageHeader: some View {
        PageHeader(
            title: language.t(.images),
            subtitle: language.t(.imagesSubtitle),
            systemImage: "photo.stack"
        ) {
            HStack(spacing: 8) {
                pullButton
                refreshButton
                imageMoreMenu
                Button {
                    openTasksDrawer()
                } label: {
                    Label(language.resolved == .zhHans ? "镜像任务" : "Image Tasks", systemImage: "clock.arrow.circlepath")
                }
                .help(language.resolved == .zhHans ? "打开镜像任务列表" : "Open image tasks")
            }
        }
    }

    private var pullButton: some View {
        Button {
            showPullPopover = true
        } label: {
            if runtimeStore.isOperationActive(RuntimeOperationKey.imagePull) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.resolved == .zhHans ? "拉取中" : "Pulling")
                }
            } else {
                Label(language.t(.pull), systemImage: "arrow.down.circle")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)
        .help(language.resolved == .zhHans ? "拉取镜像" : "Pull image")
    }

    private var refreshButton: some View {
        Button {
            refreshImages()
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
        .help(language.resolved == .zhHans ? "刷新镜像列表" : "Refresh image list")
    }

    private var imageMoreMenu: some View {
        Menu {
            Button {
                showBuildPopover = true
            } label: {
                Label(language.t(.build), systemImage: "hammer")
            }
            Button {
                showLoadPopover = true
            } label: {
                Label(language.resolved == .zhHans ? "导入" : "Import", systemImage: "square.and.arrow.down")
            }
            Button {
                prepareSaveAllImages()
            } label: {
                Label(language.resolved == .zhHans ? "批量导出" : "Export", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button {
                isConfirmingPruneDanglingImages = true
            } label: {
                Label(language.resolved == .zhHans ? "清理无标签镜像" : "Prune dangling images", systemImage: "sparkles")
            }
        } label: {
            Label(language.resolved == .zhHans ? "更多" : "More", systemImage: "ellipsis.circle")
        }
        .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)
        .help(language.resolved == .zhHans ? "更多镜像操作" : "More image actions")
    }

    private var imageToolbar: some View {
        ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
            toolbarFilterControls
            if !selectedExistingImageReferences.isEmpty {
                Text(language.resolved == .zhHans ? "已选 \(selectedExistingImageReferences.count) 个" : "\(selectedExistingImageReferences.count) selected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    confirmDeleteSelectedImages()
                } label: {
                    Label(language.resolved == .zhHans ? "删除所选" : "Delete Selected", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "删除已勾选的镜像" : "Delete selected images")
            }
            Text(language.itemCount(imageListEntries.count))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var toolbarFilterControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                displayModeMenuButton
                registryFilterMenuButton
            }
            compactFilterMenuButton
        }
    }

    private func imageRow(_ entry: ImageListEntry) -> some View {
        ResourceTableRow(
            isSelected: isEntrySelected(entry),
            onActivate: {
                selectEntry(entry)
            },
            activationHelp: imageRowActivationHelp(entry)
        ) {
            let primaryImage = entry.primaryImage
            imageSelectionButton(for: entry)
            ResourceStatusDot(tint: primaryImage.variants.isEmpty ? .secondary : CDTheme.lime, isHollow: primaryImage.variants.isEmpty)
            imageRowMainContent(entry)
            imageRowActions(entry)
        }
    }

    private func imageRowMainContent(_ entry: ImageListEntry) -> some View {
        HStack(spacing: 0) {
            Text(entry.title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.tagText)
                .font(.callout)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(entry.imageIDText)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(entry.createdText)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(entry.sizeDisplay)
                .frame(width: 86, alignment: .trailing)
        }
    }

    private func imageRowActivationHelp(_ entry: ImageListEntry) -> String {
        entry.references.count > 1
            ? (language.resolved == .zhHans ? "选择 tag 后打开镜像详情" : "Choose a tag to open image details")
            : (language.resolved == .zhHans ? "打开镜像详情" : "Open image details")
    }

    private func imageRowActions(_ entry: ImageListEntry) -> some View {
        let primaryImage = entry.primaryImage
        let deleteKey = RuntimeOperationKey.imageDelete(primaryImage.reference)
        let isOperationBlocked = runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning
        return HStack(spacing: 8) {
            RowActionButton(
                systemImage: "sidebar.right",
                help: imageListDisplayMode == .repositories
                    ? (language.resolved == .zhHans ? "打开仓库 tag 概览抽屉" : "Open repository tag overview drawer")
                    : (language.resolved == .zhHans ? "打开镜像概览抽屉" : "Open image overview drawer")
            ) {
                openEntryDrawer(entry)
            }
            ImageRowMoreMenu(isDisabled: isOperationBlocked) {
                requestImageAction(.run, for: entry)
            } onTag: {
                requestImageAction(.tag, for: entry)
            } onPush: {
                requestImageAction(.push, for: entry)
            } onExport: {
                requestImageAction(.export, for: entry)
            }
            DestructiveRowActionButton(
                isLoading: runtimeStore.isOperationActive(deleteKey),
                isDisabled: isOperationBlocked && !runtimeStore.isOperationActive(deleteKey),
                help: language.resolved == .zhHans ? "删除镜像" : "Delete image"
            ) {
                requestImageAction(.delete, for: entry)
            }
        }
        .frame(width: 118, alignment: .trailing)
    }

    private func selectImage(_ image: ImageSummary) {
        drawerSelection = nil
        detailReference = image.reference
    }

    private func selectEntry(_ entry: ImageListEntry) {
        switch entry {
        case .image(let image):
            selectImage(image)
        case .repository(let group):
            requestImageAction(.openDetail, for: group)
        }
    }

    private func openImageDrawer(_ image: ImageSummary) {
        drawerSelection = .image(image.reference)
        drawerMode = .overview
    }

    private func openEntryDrawer(_ entry: ImageListEntry) {
        switch entry {
        case .image(let image):
            openImageDrawer(image)
        case .repository(let group):
            drawerSelection = .repositoryGroup(group.id)
            drawerMode = .overview
        }
    }

    private func openTasksDrawer() {
        drawerSelection = .tasks
    }

    private func closeDetail() {
        detailReference = nil
        drawerSelection = nil
    }

    private func closeDrawer() {
        drawerSelection = nil
    }

    private func isEntrySelected(_ entry: ImageListEntry) -> Bool {
        if detailReference == entry.primaryImage.reference || drawerImage?.reference == entry.primaryImage.reference {
            return true
        }
        if case .repository(let group) = entry,
           drawerRepositoryGroup?.id == group.id {
            return true
        }
        return entry.references.contains { selectedImageReferences.contains($0) }
    }

    private func requestImageAction(_ action: ImageReferenceSelectionAction, for entry: ImageListEntry) {
        switch entry {
        case .image(let image):
            performReferenceSelection(image, action: action)
        case .repository(let group):
            requestImageAction(action, for: group)
        }
    }

    private func requestImageAction(_ action: ImageReferenceSelectionAction, for group: ImageRepositoryGroup) {
        guard group.images.count > 1 else {
            if let image = group.images.first {
                performReferenceSelection(image, action: action)
            }
            return
        }
        referenceSelectionRequest = ImageReferenceSelectionRequest(
            title: referenceSelectionTitle(action: action, group: group),
            images: group.images,
            action: action
        )
    }

    private func performReferenceSelection(_ image: ImageSummary, action: ImageReferenceSelectionAction) {
        switch action {
        case .openDetail:
            selectImage(image)
        case .run:
            runImage(image)
        case .tag:
            prepareTagImage(image)
        case .push:
            preparePushImage(image)
        case .export:
            prepareSaveImage(image)
        case .delete:
            pendingDeleteRequest = ImageDeleteRequest(references: [image.reference], isBatch: false)
        }
    }

    private func consumeResourceRoute(_ route: AppResourceRoute? = nil) {
        let route = route ?? resourceRoute
        switch route {
        case .image(let reference, _):
            detailReference = reference
            drawerSelection = nil
            resourceRoute = nil
        case .imageTag(let reference):
            detailReference = nil
            drawerSelection = nil
            prepareTagImage(reference: reference)
            resourceRoute = nil
        case .imagePush(let reference):
            detailReference = nil
            drawerSelection = nil
            preparePushImage(reference: reference)
            resourceRoute = nil
        case .imageTasks:
            drawerSelection = .tasks
            detailReference = nil
            resourceRoute = nil
        default:
            break
        }
    }

    private func referenceSelectionTitle(action: ImageReferenceSelectionAction, group: ImageRepositoryGroup) -> String {
        let actionTitle: String
        switch action {
        case .openDetail:
            actionTitle = language.resolved == .zhHans ? "打开镜像详情" : "Open image details"
        case .run:
            actionTitle = language.resolved == .zhHans ? "运行镜像" : "Run image"
        case .tag:
            actionTitle = language.resolved == .zhHans ? "标记镜像" : "Tag image"
        case .push:
            actionTitle = language.resolved == .zhHans ? "推送镜像" : "Push image"
        case .export:
            actionTitle = language.resolved == .zhHans ? "导出镜像" : "Export image"
        case .delete:
            actionTitle = language.resolved == .zhHans ? "删除镜像" : "Delete image"
        }
        return "\(actionTitle) · \(group.displayName)"
    }

    @ViewBuilder
    private var drawerContent: some View {
        switch drawerSelection {
        case .tasks:
            ImageTasksDrawer(
                operationStore: operationStore,
                statusMessage: runtimeStore.imageOperationStatusMessage,
                statusIsError: runtimeStore.imageOperationStatusIsError,
                onClose: closeDrawer
            )
        case .image:
            if let drawerImage {
                DetailDrawer(
                    mode: $drawerMode,
                    title: drawerImage.reference,
                    subtitle: drawerImage.sizeDisplay,
                    systemImage: "photo.stack",
                    rawText: imageRawSummary(drawerImage),
                    onClose: closeDrawer
                ) {
                    ImageDrawerOverview(image: drawerImage)
                }
            }
        case .repositoryGroup:
            if let drawerRepositoryGroup {
                DetailDrawer(
                    mode: $drawerMode,
                    title: drawerRepositoryGroup.displayName,
                    subtitle: drawerRepositoryGroup.tagSummary,
                    systemImage: "photo.stack",
                    rawText: repositoryGroupRawSummary(drawerRepositoryGroup),
                    onClose: closeDrawer
                ) {
                    ImageRepositoryGroupDrawerOverview(group: drawerRepositoryGroup) { image in
                        selectImage(image)
                    }
                }
            }
        case nil:
            EmptyView()
        }
    }

    private func imageRawSummary(_ image: ImageSummary) -> String {
        guard let data = try? JSONEncoder.containerDesktop.encode(image),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func repositoryGroupRawSummary(_ group: ImageRepositoryGroup) -> String {
        let payload: [String: JSONValue] = [
            "repository": .string(group.displayName),
            "registry": .string(group.registryIdentity.displayName),
            "tags": .array(group.images.map { image in
                .object([
                    "reference": .string(image.reference),
                    "tag": .string(image.referenceParts.tagDisplayName),
                    "digest": .string(image.digest),
                    "imageID": .string(image.id),
                    "created": .string(image.createdText),
                    "size": .string(image.sizeDisplay),
                ])
            }),
        ]
        guard let data = try? JSONEncoder.containerDesktop.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private var deleteAlertTitle: String {
        guard pendingDeleteRequest?.isBatch == true else {
            return language.resolved == .zhHans ? "删除镜像？" : "Delete image?"
        }
        return language.resolved == .zhHans ? "删除所选镜像？" : "Delete selected images?"
    }

    private var deleteAlertMessage: String {
        guard let request = pendingDeleteRequest else { return "" }
        if request.isBatch {
            let preview = request.references.prefix(6).joined(separator: "\n")
            let remaining = max(request.references.count - 6, 0)
            let suffix = remaining > 0
                ? (language.resolved == .zhHans ? "\n另有 \(remaining) 个镜像。" : "\n\(remaining) more images.")
                : ""
            return language.resolved == .zhHans
                ? "将删除 \(request.references.count) 个镜像。被容器引用的镜像可能无法删除。\n\(preview)\(suffix)"
                : "This will delete \(request.references.count) images. Images used by containers may fail to delete.\n\(preview)\(suffix)"
        }
        let reference = request.references.first ?? (language.resolved == .zhHans ? "所选镜像" : "the selected image")
        return language.resolved == .zhHans
            ? "将删除镜像 \(reference)。被容器引用的镜像可能无法删除。"
            : "This will delete image \(reference). Images used by containers may fail to delete."
    }

    private func deleteAlertButtonTitle(for request: ImageDeleteRequest) -> String {
        if request.isBatch {
            return language.resolved == .zhHans ? "删除 \(request.references.count) 个" : "Delete \(request.references.count)"
        }
        return language.t(.delete)
    }

    @ViewBuilder
    private var filteredImagesSelectionButton: some View {
        Button {
            toggleFilteredImageSelection()
        } label: {
            Image(systemName: filteredImagesSelectionSystemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(imageListEntries.isEmpty ? .secondary : CDTheme.dockerBlue)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(imageListEntries.isEmpty)
        .help(filteredImagesSelectionHelp)
    }

    private var filteredImagesSelectionSystemImage: String {
        if areAllFilteredImagesSelected { return "checkmark.square.fill" }
        if hasFilteredImageSelection { return "minus.square.fill" }
        return "square"
    }

    private var filteredImagesSelectionHelp: String {
        if areAllFilteredImagesSelected {
            return language.resolved == .zhHans ? "取消选择当前筛选结果" : "Deselect filtered images"
        }
        return language.resolved == .zhHans ? "选择当前筛选结果" : "Select filtered images"
    }

    @ViewBuilder
    private func imageSelectionButton(for entry: ImageListEntry) -> some View {
        let references = entry.references
        let selectedCount = references.filter { selectedImageReferences.contains($0) }.count
        let isSelected = !references.isEmpty && selectedCount == references.count
        let isPartiallySelected = selectedCount > 0 && selectedCount < references.count
        Button {
            toggleImageSelection(references)
        } label: {
            Image(systemName: isSelected ? "checkmark.square.fill" : (isPartiallySelected ? "minus.square.fill" : "square"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle((isSelected || isPartiallySelected) ? CDTheme.dockerBlue : .secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(isSelected
            ? (language.resolved == .zhHans ? "取消选择镜像" : "Deselect image")
            : (language.resolved == .zhHans ? "选择镜像" : "Select image"))
    }

    private func toggleImageSelection(_ references: [String]) {
        let referenceSet = Set(references)
        if referenceSet.isSubset(of: selectedImageReferences) {
            selectedImageReferences.subtract(referenceSet)
        } else {
            selectedImageReferences.formUnion(referenceSet)
        }
    }

    private func toggleFilteredImageSelection() {
        if areAllFilteredImagesSelected {
            selectedImageReferences.subtract(filteredImageReferenceSet)
        } else {
            selectedImageReferences.formUnion(filteredImageReferenceSet)
        }
    }

    private func confirmDeleteSelectedImages() {
        let references = selectedExistingImageReferences
        guard !references.isEmpty else { return }
        pendingDeleteRequest = ImageDeleteRequest(references: references, isBatch: true)
    }

    private func pruneSelectedImages() {
        let existingReferences = Set(runtimeStore.images.map(\.reference))
        selectedImageReferences.formIntersection(existingReferences)
    }

    private func pruneSelectedRegistryFilter() {
        guard selectedRegistryFilter != ImageRegistryFilterOption.allID else { return }
        let optionIDs = Set(registryFilterOptions.map(\.id))
        if !optionIDs.contains(selectedRegistryFilter) {
            selectedRegistryFilter = ImageRegistryFilterOption.allID
        }
    }

    private func refreshImages() {
        Task {
            await runtimeStore.refreshAll()
            pruneSelectedImages()
        }
    }

    private func deleteImages(_ references: [String]) {
        var seen = Set<String>()
        let resolvedReferences = references
            .map(\.trimmed)
            .filter { reference in
                guard !reference.isEmpty, !seen.contains(reference) else { return false }
                seen.insert(reference)
                return true
            }
        guard !resolvedReferences.isEmpty else { return }
        let id = operationStore.start(
            domain: .image,
            title: language.resolved == .zhHans ? "批量删除镜像" : "Delete images",
            target: "\(resolvedReferences.count) images",
            commandPreview: imageDeleteCommandPreview(for: resolvedReferences)
        )
        Task {
            let result = await runtimeStore.deleteImages(resolvedReferences)
            selectedImageReferences.subtract(result.deletedReferences)
            operationStore.finish(
                id: id,
                status: result.succeeded ? .succeeded : .failed,
                output: result.output
            )
        }
    }

    private func imageDeleteCommandPreview(for references: [String]) -> String {
        references
            .map { AppOperationCommandPreview.make(executable: "container", arguments: ["image", "delete", $0]) }
            .joined(separator: " && ")
    }

    private var allRegistriesTitle: String {
        language.resolved == .zhHans ? "全部注册中心" : "All registries"
    }

    private var currentRegistryFilterTitle: String {
        guard selectedRegistryFilter != ImageRegistryFilterOption.allID else {
            return allRegistriesTitle
        }
        return registryFilterOptions.first { $0.id == selectedRegistryFilter }?.displayName ?? allRegistriesTitle
    }

    private var compactFilterSummary: String {
        "\(imageListDisplayMode.fullTitle(language: language)) · \(currentRegistryFilterTitle)"
    }

    private var displayModeMenuButton: some View {
        Menu {
            displayModeMenuItems
        } label: {
            ImageToolbarMenuButton(
                title: language.resolved == .zhHans ? "显示方式" : "Display",
                value: imageListDisplayMode.fullTitle(language: language),
                systemImage: "rectangle.grid.1x2"
            )
            .frame(width: 220)
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "选择镜像按 tag 展示或按仓库合并展示" : "Show images by tag or grouped by repository")
    }

    private var registryFilterMenuButton: some View {
        Menu {
            registryFilterMenuItems
        } label: {
            ImageToolbarMenuButton(
                title: language.resolved == .zhHans ? "注册中心" : "Registry",
                value: currentRegistryFilterTitle,
                systemImage: "line.3.horizontal.decrease.circle"
            )
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "按镜像注册中心筛选：\(currentRegistryFilterTitle)" : "Filter by image registry: \(currentRegistryFilterTitle)")
    }

    private var compactFilterMenuButton: some View {
        Menu {
            Section(language.resolved == .zhHans ? "显示方式" : "Display") {
                displayModeMenuItems
            }
            Section(language.resolved == .zhHans ? "注册中心" : "Registry") {
                registryFilterMenuItems
            }
        } label: {
            ImageToolbarMenuButton(
                title: language.resolved == .zhHans ? "筛选" : "Filters",
                value: compactFilterSummary,
                systemImage: "line.3.horizontal.decrease.circle"
            )
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "筛选镜像：\(compactFilterSummary)" : "Filter images: \(compactFilterSummary)")
    }

    @ViewBuilder
    private var displayModeMenuItems: some View {
        ForEach(ImageListDisplayMode.allCases) { mode in
            Button {
                imageListDisplayModeRaw = mode.rawValue
            } label: {
                menuCheckmarkLabel(
                    mode.fullTitle(language: language),
                    isSelected: imageListDisplayMode == mode
                )
            }
        }
    }

    @ViewBuilder
    private var registryFilterMenuItems: some View {
        Button {
            selectedRegistryFilter = ImageRegistryFilterOption.allID
        } label: {
            menuCheckmarkLabel(
                allRegistriesTitle,
                isSelected: selectedRegistryFilter == ImageRegistryFilterOption.allID
            )
        }
        ForEach(registryFilterOptions) { option in
            Button {
                selectedRegistryFilter = option.id
            } label: {
                menuCheckmarkLabel(
                    option.displayName,
                    isSelected: selectedRegistryFilter == option.id
                )
            }
        }
    }

    @ViewBuilder
    private func menuCheckmarkLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private var currentPullReference: String {
        useCustomPullReference ? customPullReference : pullReference
    }

    private var imageHeader: some View {
        HStack(spacing: 12) {
            filteredImagesSelectionButton
                .frame(width: 28)
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.tag), width: 120)
            ResourceTableHeaderLabel(title: language.t(.imageID), width: 130)
            ResourceTableHeaderLabel(title: language.t(.created), width: 130)
            ResourceTableHeaderLabel(title: language.t(.size), width: 86, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 118, alignment: .trailing)
        }
    }

    private var pullImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "拉取镜像" : "Pull Image")
                .font(.headline)

            Picker(language.t(.image), selection: $pullReference) {
                ForEach(pullChoices, id: \.self) { reference in
                    Text(reference).tag(reference)
                }
            }
            .labelsHidden()
            .disabled(useCustomPullReference || runtimeStore.isImageOperationRunning)

            Toggle(language.resolved == .zhHans ? "使用自定义引用" : "Use custom reference", isOn: $useCustomPullReference)
                .toggleStyle(.switch)
                .disabled(runtimeStore.isImageOperationRunning)

            TextField("alpine:latest", text: $customPullReference)
                .textFieldStyle(.roundedBorder)
                .disabled(!useCustomPullReference || runtimeStore.isImageOperationRunning)

            Text(language.resolved == .zhHans ? "支持 Docker Hub、私有 Registry 和完整 OCI 引用。" : "Supports Docker Hub, private registries, and full OCI references.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("取消") {
                    showPullPopover = false
                }
                .disabled(runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "取消拉取镜像" : "Cancel image pull")
                Button(language.t(.pull)) {
                    runPullImage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentPullReference.trimmed.isEmpty || runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "拉取当前镜像引用" : "Pull the current image reference")
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private var buildImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "构建镜像" : "Build Image")
                .font(.headline)
            HStack(spacing: 8) {
                TextField(language.resolved == .zhHans ? "构建目录" : "Context directory", text: $buildContextPath)
                    .textFieldStyle(.roundedBorder)
                Button {
                    chooseBuildContext()
                } label: {
                    Image(systemName: "folder")
                }
                .help(language.resolved == .zhHans ? "选择构建目录" : "Choose build context")
            }
            TextField("Dockerfile / Containerfile", text: $buildDockerfilePath)
                .textFieldStyle(.roundedBorder)
            TextField("tag", text: $buildTag)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("platform", text: $buildPlatform)
                TextField("cpus", text: $buildCPUs)
                TextField("memory", text: $buildMemory)
            }
            .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("arch, one per line", text: $buildArchitecturesText, axis: .vertical)
                    .lineLimit(1...3)
                TextField("os, one per line", text: $buildOperatingSystemsText, axis: .vertical)
                    .lineLimit(1...3)
            }
            .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("target", text: $buildTarget)
                TextField("output type=oci,dest=...", text: $buildOutput)
            }
            .textFieldStyle(.roundedBorder)
            Picker("--progress", selection: $buildProgress) {
                ForEach(["auto", "plain", "tty"], id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            TextField("--build-arg, one per line", text: $buildArgsText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField("--label, one per line", text: $buildLabelsText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField("--secret, one per line", text: $buildSecretsText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            DisclosureGroup(language.resolved == .zhHans ? "DNS 构建参数" : "Build DNS Options") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("--dns, one per line", text: $buildDNSText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    TextField("--dns-search, one per line", text: $buildDNSSearchText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    TextField("--dns-option, one per line", text: $buildDNSOptionsText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    TextField("--dns-domain", text: $buildDNSDomain)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 6)
            }
            HStack {
                Toggle("--no-cache", isOn: $buildNoCache)
                Toggle("--pull", isOn: $buildPull)
                Toggle("-q", isOn: $buildQuiet)
                Spacer()
            }
            .toggleStyle(.checkbox)
            HStack {
                Spacer()
                Button("取消") {
                    showBuildPopover = false
                }
                .help(language.resolved == .zhHans ? "取消构建镜像" : "Cancel image build")
                Button(language.t(.build)) {
                    showBuildPopover = false
                    let options = ImageBuildOptions(
                        contextPath: buildContextPath,
                        dockerfilePath: buildDockerfilePath,
                        tag: buildTag,
                        cpus: buildCPUs,
                        memory: buildMemory,
                        target: buildTarget,
                        output: buildOutput,
                        progress: buildProgress,
                        noCache: buildNoCache,
                        pull: buildPull,
                        quiet: buildQuiet,
                        platforms: lines(from: buildPlatform),
                        architectures: lines(from: buildArchitecturesText),
                        operatingSystems: lines(from: buildOperatingSystemsText),
                        buildArgs: lines(from: buildArgsText),
                        labels: lines(from: buildLabelsText),
                        secrets: lines(from: buildSecretsText),
                        dns: lines(from: buildDNSText),
                        dnsSearch: lines(from: buildDNSSearchText),
                        dnsOptions: lines(from: buildDNSOptionsText),
                        dnsDomain: buildDNSDomain
                    )
                    runTrackedImageOperation(
                        title: language.resolved == .zhHans ? "构建镜像" : "Build image",
                        target: buildTag.nilIfBlank ?? buildContextPath.nilIfBlank ?? "build",
                        arguments: options.arguments
                    ) {
                        await runtimeStore.buildImage(options)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "开始构建镜像" : "Start building image")
            }
        }
        .padding(16)
        .frame(width: 480)
    }

    private var tagImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "标记镜像" : "Tag Image")
                .font(.headline)
            TextField("source", text: $tagSource)
                .textFieldStyle(.roundedBorder)
            TextField("target", text: $tagTarget)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { showTagPopover = false }
                    .help(language.resolved == .zhHans ? "取消标记镜像" : "Cancel image tag")
                Button(language.resolved == .zhHans ? "标记" : "Tag") {
                    showTagPopover = false
                    runTrackedImageOperation(
                        title: language.resolved == .zhHans ? "标记镜像" : "Tag image",
                        target: tagTarget,
                        arguments: ["image", "tag", tagSource, tagTarget]
                    ) {
                        await runtimeStore.tagImage(source: tagSource, target: tagTarget)
                    }
                }
                .buttonStyle(.borderedProminent)
                .help(language.resolved == .zhHans ? "创建镜像标签" : "Create image tag")
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private var pushImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "推送镜像" : "Push Image")
                .font(.headline)
            TextField("reference", text: $pushReference)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Picker("scheme", selection: $pushScheme) {
                    ForEach(["auto", "https", "http"], id: \.self) { scheme in
                        Text(scheme).tag(scheme)
                    }
                }
                TextField("platform", text: $pushPlatform)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("取消") { showPushPopover = false }
                    .help(language.resolved == .zhHans ? "取消推送镜像" : "Cancel image push")
                Button(language.resolved == .zhHans ? "推送" : "Push") {
                    showPushPopover = false
                    let options = ImagePushOptions(
                        reference: pushReference,
                        scheme: pushScheme,
                        progress: "plain",
                        platform: pushPlatform
                    )
                    runTrackedImageOperation(
                        title: language.resolved == .zhHans ? "推送镜像" : "Push image",
                        target: pushReference,
                        arguments: options.arguments
                    ) {
                        await runtimeStore.pushImage(options)
                    }
                }
                .buttonStyle(.borderedProminent)
                .help(language.resolved == .zhHans ? "推送镜像到仓库" : "Push image to registry")
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private var saveImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "导出镜像归档" : "Save Image Archive")
                .font(.headline)
            TextField(language.resolved == .zhHans ? "镜像引用，每行一个" : "Image references, one per line", text: $saveReferencesText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack(spacing: 8) {
                TextField(language.resolved == .zhHans ? "输出 tar 路径" : "Output tar path", text: $saveOutputPath)
                    .textFieldStyle(.roundedBorder)
                Button {
                    chooseSaveOutputPath()
                } label: {
                    Image(systemName: "folder")
                }
                .help(language.resolved == .zhHans ? "选择导出路径" : "Choose export path")
            }
            HStack(spacing: 8) {
                TextField("platform", text: $savePlatform)
                TextField("os", text: $saveOS)
                TextField("arch", text: $saveArch)
            }
            .textFieldStyle(.roundedBorder)
            Text(language.resolved == .zhHans ? "Apple container 使用 image save/load 处理镜像归档；容器文件系统导出在容器详情中使用 container export。" : "Apple container uses image save/load for image archives. Container filesystem export is available from container details.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") {
                    showSavePopover = false
                }
                .help(language.resolved == .zhHans ? "取消导出镜像" : "Cancel image export")
                Button(language.resolved == .zhHans ? "导出" : "Save") {
                    runSaveImages()
                }
                .buttonStyle(.borderedProminent)
                .disabled(lines(from: saveReferencesText).isEmpty || saveOutputPath.trimmed.isEmpty || runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "导出镜像归档" : "Export image archive")
            }
        }
        .padding(16)
        .frame(width: 460)
    }

    private var loadImageForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "导入镜像归档" : "Load Image Archive")
                .font(.headline)
            HStack(spacing: 8) {
                TextField(language.resolved == .zhHans ? "输入 tar 路径" : "Input tar path", text: $loadInputPath)
                    .textFieldStyle(.roundedBorder)
                Button {
                    chooseLoadInputPath()
                } label: {
                    Image(systemName: "folder")
                }
                .help(language.resolved == .zhHans ? "选择导入文件" : "Choose import file")
            }
            Toggle(language.resolved == .zhHans ? "-f / 强制导入" : "-f / Force", isOn: $loadForce)
                .toggleStyle(.checkbox)
            Text(language.resolved == .zhHans ? "导入对应 container image load。若要导入容器文件系统，请先在容器页使用导出/导入工作流。" : "Import maps to container image load. Filesystem archives belong to the container export workflow.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") {
                    showLoadPopover = false
                }
                .help(language.resolved == .zhHans ? "取消导入镜像" : "Cancel image import")
                Button(language.resolved == .zhHans ? "导入" : "Load") {
                    runLoadImage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(loadInputPath.trimmed.isEmpty || runtimeStore.isImageOperationRunning)
                .help(language.resolved == .zhHans ? "导入镜像归档" : "Import image archive")
            }
        }
        .padding(16)
        .frame(width: 430)
    }

    private func chooseBuildContext() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        buildContextPath = url.path
    }

    private func prepareTagImage(_ image: ImageSummary) {
        prepareTagImage(reference: image.reference)
    }

    private func prepareTagImage(reference: String) {
        tagSource = reference
        tagTarget = suggestedTagTarget(for: reference)
        showTagPopover = true
    }

    private func preparePushImage(_ image: ImageSummary) {
        preparePushImage(reference: image.reference)
    }

    private func preparePushImage(reference: String) {
        pushReference = reference
        showPushPopover = true
    }

    private func runImage(_ image: ImageSummary) {
        Task {
            await runtimeStore.runContainer(options: ContainerRunOptions(image: image.reference))
        }
    }

    private func prepareSaveImage(_ image: ImageSummary) {
        saveReferencesText = image.reference
        saveOutputPath = suggestedImageArchiveName(for: [image.reference])
        savePlatform = ""
        saveOS = ""
        saveArch = ""
        showSavePopover = true
    }

    private func prepareSaveAllImages() {
        saveReferencesText = runtimeStore.images.map(\.reference).joined(separator: "\n")
        saveOutputPath = suggestedImageArchiveName(for: runtimeStore.images.map(\.reference))
        savePlatform = ""
        saveOS = ""
        saveArch = ""
        showSavePopover = true
    }

    private func chooseSaveOutputPath() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = saveOutputPath.nilIfBlank.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "containerdesktop-images.tar"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        if let directory = saveOutputPath.nilIfBlank.map({ URL(fileURLWithPath: $0).deletingLastPathComponent() }) {
            panel.directoryURL = directory
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveOutputPath = url.path
    }

    private func chooseLoadInputPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadInputPath = url.path
    }

    private func runSaveImages() {
        let references = lines(from: saveReferencesText)
        let options = ImageSaveOptions(
            references: references,
            outputPath: saveOutputPath,
            platform: savePlatform,
            os: saveOS,
            arch: saveArch
        )
        showSavePopover = false
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "导出镜像" : "Save image",
            target: references.joined(separator: ", "),
            arguments: options.arguments
        ) {
            await runtimeStore.saveImages(options)
        }
    }

    private func runLoadImage() {
        let options = ImageLoadOptions(inputPath: loadInputPath, force: loadForce)
        showLoadPopover = false
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "导入镜像" : "Load image",
            target: URL(fileURLWithPath: loadInputPath).lastPathComponent,
            arguments: options.arguments
        ) {
            await runtimeStore.loadImage(options)
        }
    }

    private func runPullImage() {
        let reference = currentPullReference.trimmed
        guard !reference.isEmpty else { return }
        showPullPopover = false
        if useCustomPullReference {
            customPullReference = ""
        }
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "拉取镜像" : "Pull image",
            target: reference,
            arguments: ["image", "pull", reference],
            usesImageStatus: false
        ) {
            await runtimeStore.pullImage(reference)
        }
    }

    private func pruneDanglingImages() {
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "清理无标签镜像" : "Prune dangling images",
            target: "dangling",
            arguments: ["image", "prune"]
        ) {
            await runtimeStore.pruneDanglingImages()
        }
    }

    private func suggestedImageArchiveName(for references: [String]) -> String {
        let name: String
        if references.count == 1, let reference = references.first {
            name = reference
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
        } else {
            name = "containerdesktop-images"
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "\(name).tar")
            .path
    }

    private func deleteImage(_ reference: String) {
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "删除镜像" : "Delete image",
            target: reference,
            arguments: ["image", "delete", reference],
            usesImageStatus: false
        ) {
            await runtimeStore.deleteImage(reference)
        }
    }

    private func runTrackedImageOperation(
        title: String,
        target: String,
        arguments: [String],
        usesImageStatus: Bool = true,
        operation: @escaping () async -> Void
    ) {
        let id = operationStore.start(
            domain: .image,
            title: title,
            target: target.nilIfBlank ?? "—",
            commandPreview: AppOperationCommandPreview.make(executable: "container", arguments: arguments)
        )
        Task {
            await operation()
            finishTrackedImageOperation(id, usesImageStatus: usesImageStatus)
        }
    }

    private func finishTrackedImageOperation(_ id: UUID, usesImageStatus: Bool) {
        let failed = usesImageStatus
            ? runtimeStore.imageOperationStatusIsError
            : runtimeStore.errorMessage != nil
        let output = usesImageStatus
            ? runtimeStore.imageOperationStatusMessage?.nilIfBlank ?? runtimeStore.errorMessage?.nilIfBlank ?? "完成。"
            : runtimeStore.errorMessage?.nilIfBlank ?? "完成。"
        operationStore.finish(id: id, status: failed ? .failed : .succeeded, output: output)
    }

    private func suggestedTagTarget(for reference: String) -> String {
        if reference.contains(":") {
            return "\(reference)-copy"
        }
        return "\(reference):latest"
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}

private struct ImageDrawerOverview: View {
    @Environment(\.appLanguage) private var language
    var image: ImageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "镜像" : "Image") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: image.reference)
                    DetailInfoRow(title: language.t(.tag), value: image.tag)
                    DetailInfoRow(title: language.t(.imageID), value: image.id, monospaced: true)
                    DetailInfoRow(title: "Digest", value: image.digest, monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: image.createdText)
                    DetailInfoRow(title: language.t(.size), value: image.sizeDisplay)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "平台变体" : "Platform variants") {
                DetailInfoCard {
                    DetailInfoRow(
                        title: language.resolved == .zhHans ? "数量" : "Count",
                        value: "\(image.variants.count)"
                    )

                    if image.variants.isEmpty {
                        DetailInfoRow(title: "Platforms", value: "—")
                    } else {
                        ForEach(image.variants, id: \.digest) { variant in
                            DetailInfoRow(
                                title: variant.platformText,
                                value: variant.sizeDisplay
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct ImageRepositoryGroupDrawerOverview: View {
    @Environment(\.appLanguage) private var language
    var group: ImageRepositoryGroup
    var onOpenImage: (ImageSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "仓库镜像" : "Repository") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: group.displayName)
                    DetailInfoRow(title: language.resolved == .zhHans ? "注册中心" : "Registry", value: group.registryIdentity.displayName)
                    DetailInfoRow(title: language.resolved == .zhHans ? "Tag 数量" : "Tags", value: "\(group.tagCount)")
                    DetailInfoRow(title: language.t(.imageID), value: group.imageIDText, monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: group.createdText)
                    DetailInfoRow(title: language.t(.size), value: group.sizeDisplay)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "Tag 列表" : "Tags") {
                VStack(spacing: 0) {
                    ForEach(group.images, id: \.reference) { image in
                        ImageRepositoryTagRow(image: image) {
                            onOpenImage(image)
                        }
                    }
                }
                .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            }
        }
    }
}

private struct ImageRepositoryTagRow: View {
    @Environment(\.appLanguage) private var language
    var image: ImageSummary
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(image.referenceParts.tagDisplayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(image.reference)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(String(image.id.prefix(12)))
                        .font(.caption.monospaced())
                    Text(image.sizeDisplay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "打开此 tag 的镜像详情" : "Open image details for this tag")

        Divider()
            .padding(.leading, 12)
    }
}

private struct ImageToolbarMenuButton: View {
    var title: String
    var value: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(value)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ImageRowMoreMenu: View {
    @Environment(\.appLanguage) private var language
    var isDisabled: Bool
    var onRun: () -> Void
    var onTag: () -> Void
    var onPush: () -> Void
    var onExport: () -> Void

    var body: some View {
        Menu {
            Button {
                onRun()
            } label: {
                Label(language.resolved == .zhHans ? "运行" : "Run", systemImage: "play.circle")
            }
            Button {
                onTag()
            } label: {
                Label(language.resolved == .zhHans ? "标记" : "Tag", systemImage: "tag")
            }
            Button {
                onPush()
            } label: {
                Label(language.resolved == .zhHans ? "推送" : "Push", systemImage: "arrow.up.circle")
            }
            Button {
                onExport()
            } label: {
                Label(language.resolved == .zhHans ? "导出" : "Export", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDisabled ? .secondary : CDTheme.dockerBlue)
                .frame(width: 28, height: 28)
                .background((isDisabled ? Color.secondary : CDTheme.dockerBlue).opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(language.resolved == .zhHans ? "更多镜像操作" : "More image actions")
    }
}
