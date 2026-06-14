import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImagesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore
    @State private var searchText = ""
    @State private var pullReference = "alpine:latest"
    @State private var useCustomPullReference = false
    @State private var customPullReference = ""
    @State private var selectedReference: String?
    @State private var pendingDelete: ImageSummary?
    @State private var drawerMode: DetailDrawerMode = .overview
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
    @State private var showTasksDrawer = false

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

    private var pullChoices: [String] {
        FormPresetOptions.imageChoices(
            current: pullReference,
            localImages: [],
            suggestions: FormPresetOptions.containerImages
        )
    }

    var body: some View {
        DrawerPageLayout(
            isDrawerPresented: selectedImage != nil || showTasksDrawer,
            onDismiss: closeDrawer,
            drawerWidth: showTasksDrawer ? 620 : 430
        ) {
            pageContent
        } drawer: {
            if showTasksDrawer {
                ImageTasksDrawer(
                    operationStore: operationStore,
                    statusMessage: runtimeStore.imageOperationStatusMessage,
                    statusIsError: runtimeStore.imageOperationStatusIsError,
                    onClose: closeDrawer
                )
            } else if let selectedImage {
                DetailDrawer(
                    mode: $drawerMode,
                    title: selectedImage.reference,
                    subtitle: "container image inspect",
                    systemImage: "photo.stack",
                    rawText: runtimeStore.selectedInspectorText,
                    onClose: {
                        closeDrawer()
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
                    deleteImage(image)
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
                            pruneDanglingImages()
                        } label: {
                            Label(language.resolved == .zhHans ? "清理无标签镜像" : "Prune dangling images", systemImage: "sparkles")
                        }
                    } label: {
                        Label(language.resolved == .zhHans ? "更多" : "More", systemImage: "ellipsis.circle")
                    }
                    .disabled(runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)

                    Button {
                        openTasksDrawer()
                    } label: {
                        Label(language.resolved == .zhHans ? "镜像任务" : "Image Tasks", systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            if let message = runtimeStore.imageOperationStatusMessage {
                StatusBanner(
                    text: message,
                    systemImage: runtimeStore.imageOperationStatusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                    tint: runtimeStore.imageOperationStatusIsError ? CDTheme.ember : CDTheme.lime
                )
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
                            let deleteKey = RuntimeOperationKey.imageDelete(image.reference)
                            let isOperationBlocked = runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning
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

                            HStack(spacing: 8) {
                                RowActionButton(systemImage: "sidebar.right") {
                                    selectImage(image)
                                }
                                ImageRowMoreMenu(isDisabled: isOperationBlocked) {
                                    tagSource = image.reference
                                    tagTarget = suggestedTagTarget(for: image.reference)
                                    showTagPopover = true
                                } onPush: {
                                    pushReference = image.reference
                                    showPushPopover = true
                                } onExport: {
                                    prepareSaveImage(image)
                                }
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: isOperationBlocked && !runtimeStore.isOperationActive(deleteKey)
                                ) {
                                    pendingDelete = image
                                }
                            }
                            .frame(width: 118, alignment: .trailing)
                        }
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

    private func selectImage(_ image: ImageSummary) {
        showTasksDrawer = false
        selectedReference = image.reference
        drawerMode = .overview
        Task { await runtimeStore.inspectImage(image.reference) }
    }

    private func openTasksDrawer() {
        selectedReference = nil
        showTasksDrawer = true
    }

    private func closeDrawer() {
        selectedReference = nil
        showTasksDrawer = false
    }

    private var currentPullReference: String {
        useCustomPullReference ? customPullReference : pullReference
    }

    private var imageHeader: some View {
        HStack(spacing: 12) {
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
                Button(language.t(.pull)) {
                    runPullImage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentPullReference.trimmed.isEmpty || runtimeStore.activeOperationKey != nil || runtimeStore.isImageOperationRunning)
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
                Button(language.resolved == .zhHans ? "导出" : "Save") {
                    runSaveImages()
                }
                .buttonStyle(.borderedProminent)
                .disabled(lines(from: saveReferencesText).isEmpty || saveOutputPath.trimmed.isEmpty || runtimeStore.isImageOperationRunning)
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
                Button(language.resolved == .zhHans ? "导入" : "Load") {
                    runLoadImage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(loadInputPath.trimmed.isEmpty || runtimeStore.isImageOperationRunning)
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

    private func deleteImage(_ image: ImageSummary) {
        runTrackedImageOperation(
            title: language.resolved == .zhHans ? "删除镜像" : "Delete image",
            target: image.reference,
            arguments: ["image", "delete", image.reference],
            usesImageStatus: false
        ) {
            await runtimeStore.deleteImage(image.reference)
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

private struct ImageRowMoreMenu: View {
    @Environment(\.appLanguage) private var language
    var isDisabled: Bool
    var onTag: () -> Void
    var onPush: () -> Void
    var onExport: () -> Void

    var body: some View {
        Menu {
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
    }
}
