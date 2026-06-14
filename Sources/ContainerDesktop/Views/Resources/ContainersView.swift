import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContainersView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var onlyRunning = false
    @State private var showRunPopover = false
    @State private var newContainerName = ""
    @State private var newContainerImage = "alpine:latest"
    @State private var useAutoContainerName = true
    @State private var newContainerCommandPreset = ContainerCommandPreset.keepAlive
    @State private var customContainerCommand = ""
    @State private var newContainerCreateOnly = false
    @State private var newContainerDetached = true
    @State private var newContainerInteractive = false
    @State private var newContainerTTY = false
    @State private var newContainerRemove = false
    @State private var newContainerReadOnly = false
    @State private var newContainerInit = false
    @State private var newContainerRosetta = false
    @State private var newContainerSSH = false
    @State private var newContainerVirtualization = false
    @State private var newContainerNoDNS = false
    @State private var newContainerCPUs = ""
    @State private var newContainerMemory = ""
    @State private var newContainerPlatform = ""
    @State private var newContainerOS = ""
    @State private var newContainerArch = ""
    @State private var newContainerUser = ""
    @State private var newContainerUID = ""
    @State private var newContainerGID = ""
    @State private var newContainerWorkdir = ""
    @State private var newContainerEntrypoint = ""
    @State private var newContainerRuntime = ""
    @State private var newContainerKernel = ""
    @State private var newContainerCIDFile = ""
    @State private var newContainerInitImage = ""
    @State private var newContainerShmSize = ""
    @State private var newContainerDNSDomain = ""
    @State private var newContainerScheme = "auto"
    @State private var newContainerProgress = "auto"
    @State private var newContainerMaxDownloads = ""
    @State private var newContainerPorts = ""
    @State private var newContainerEnv = ""
    @State private var newContainerEnvFiles = ""
    @State private var newContainerVolumes = ""
    @State private var newContainerMounts = ""
    @State private var newContainerNetworks = ""
    @State private var newContainerPublishSockets = ""
    @State private var newContainerLabels = ""
    @State private var newContainerDNS = ""
    @State private var newContainerDNSSearch = ""
    @State private var newContainerDNSOptions = ""
    @State private var newContainerTmpfs = ""
    @State private var newContainerCapAdd = ""
    @State private var newContainerCapDrop = ""
    @State private var newContainerUlimits = ""
    @State private var detailID: String?
    @State private var drawerID: String?
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var pendingDelete: ContainerSummary?

    private var filteredContainers: [ContainerSummary] {
        let query = searchText.trimmed.lowercased()
        let base = onlyRunning ? runtimeStore.containers.filter { $0.state == "running" } : runtimeStore.containers
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.id.lowercased().contains(query)
                || $0.imageName.lowercased().contains(query)
                || $0.state.lowercased().contains(query)
        }
    }

    private var detailContainer: ContainerSummary? {
        guard let detailID else { return nil }
        return runtimeStore.containers.first { $0.id == detailID }
    }

    private var drawerContainer: ContainerSummary? {
        guard let drawerID else { return nil }
        return runtimeStore.containers.first { $0.id == drawerID }
    }

    private var imageChoices: [String] {
        FormPresetOptions.imageChoices(
            current: newContainerImage,
            localImages: runtimeStore.images,
            suggestions: FormPresetOptions.containerImages
        )
    }

    var body: some View {
        Group {
            if let container = detailContainer {
                ContainerDetailPage(
                    runtimeStore: runtimeStore,
                    containerID: detailID ?? container.id,
                    isPresented: Binding(
                        get: { detailID != nil },
                        set: { if !$0 { detailID = nil } }
                    )
                )
            } else {
                DrawerPageLayout(isDrawerPresented: drawerContainer != nil, onDismiss: {
                    drawerID = nil
                }) {
                    pageContent
                } drawer: {
                    if let drawerContainer {
                        DetailDrawer(
                            mode: $drawerMode,
                            title: drawerContainer.id,
                            subtitle: drawerContainer.imageName,
                            systemImage: "shippingbox",
                            rawText: containerRawSummary(drawerContainer),
                            onClose: { drawerID = nil }
                        ) {
                            ContainerDetailOverview(container: drawerContainer)
                        }
                    }
                }
            }
        }
        .alert("删除容器？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let container = pendingDelete {
                Button("删除", role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteContainer(container.id) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除容器 \(pendingDelete?.id ?? "所选容器")。运行中的容器需要先停止。")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.containers),
                subtitle: language.t(.containersSubtitle),
                systemImage: "shippingbox"
            ) {
                HStack(spacing: 8) {
                    Button {
                        showRunPopover = true
                    } label: {
                        if runtimeStore.isOperationActive(RuntimeOperationKey.containerRun) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(language.resolved == .zhHans ? "运行中" : "Running")
                            }
                        } else {
                            Label(language.resolved == .zhHans ? "运行容器" : "Run Container", systemImage: "play.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeStore.activeOperationKey != nil)
                    .sheet(isPresented: $showRunPopover) {
                        runContainerForm
                    }

                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Toggle(language.t(.onlyRunning), isOn: $onlyRunning)
                    .toggleStyle(.switch)
                Text(language.itemCount(filteredContainers.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredContainers.isEmpty {
                ResourceTable {
                    containerHeader
                } rows: {
                    EmptyStateView(title: language.t(.noContainers), message: "Start container system, run an image, or bring up a Compose project.", systemImage: "shippingbox")
                        .padding(18)
                }
            } else {
                ResourceTable {
                    containerHeader
                } rows: {
                    ForEach(filteredContainers) { container in
                        ResourceTableRow(isSelected: detailID == container.id || drawerID == container.id) {
                            Button {
                                openContainerDetail(container)
                            } label: {
                                HStack(spacing: 12) {
                                    ResourceStatusDot(tint: container.state == "running" ? CDTheme.lime : .secondary)

                                    Text(container.id)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                                    Text(container.imageName)
                                        .lineLimit(1)
                                        .frame(width: 180, alignment: .leading)

                                    Text(container.primaryIP)
                                        .font(.callout.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .frame(width: 118, alignment: .leading)

                                    Text(container.state)
                                        .lineLimit(1)
                                        .frame(width: 76, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 8) {
                                let startStopKey = container.state == "running"
                                    ? RuntimeOperationKey.containerStop(container.id)
                                    : RuntimeOperationKey.containerStart(container.id)
                                RowActionButton(
                                    systemImage: container.state == "running" ? "stop.fill" : "play.fill",
                                    isLoading: runtimeStore.isOperationActive(startStopKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(startStopKey)
                                ) {
                                    Task {
                                        if container.state == "running" {
                                            await runtimeStore.stopContainer(container.id)
                                        } else {
                                            await runtimeStore.startContainer(container.id)
                                        }
                                    }
                                }
                                RowActionButton(systemImage: "terminal", tint: container.state == "running" ? CDTheme.dockerBlue : .secondary) {
                                    openContainerTerminal(container)
                                }
                                RowActionButton(
                                    systemImage: "archivebox",
                                    isDisabled: container.state == "running",
                                    help: container.state == "running"
                                        ? (language.resolved == .zhHans ? "停止容器后可导出文件系统。" : "Stop the container before exporting its filesystem.")
                                        : (language.resolved == .zhHans ? "导出文件系统" : "Export filesystem")
                                ) {
                                    exportContainer(container)
                                }
                                RowActionButton(systemImage: "sidebar.right") {
                                    openContainerDrawer(container)
                                }
                                let deleteKey = RuntimeOperationKey.containerDelete(container.id)
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(deleteKey)
                                ) {
                                    pendingDelete = container
                                }
                            }
                            .frame(width: 180, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func openContainerDetail(_ container: ContainerSummary) {
        detailID = container.id
    }

    private func openContainerDrawer(_ container: ContainerSummary) {
        drawerID = container.id
        drawerMode = .overview
    }

    private func openContainerTerminal(_ container: ContainerSummary) {
        guard container.state == "running" else {
            runtimeStore.errorMessage = language.resolved == .zhHans ? "容器未运行，无法进入终端。" : "The container is not running."
            return
        }
        do {
            try SystemTerminalLauncher.openContainerShell(id: container.id)
        } catch {
            runtimeStore.errorMessage = error.localizedDescription
        }
    }

    private func containerRawSummary(_ container: ContainerSummary) -> String {
        guard let data = try? JSONEncoder.containerDesktop.encode(container),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private var containerHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: language.t(.image), width: 180)
            ResourceTableHeaderLabel(title: "IP", width: 118)
            ResourceTableHeaderLabel(title: language.t(.status), width: 76)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 180, alignment: .trailing)
        }
    }

    private var runContainerForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.resolved == .zhHans ? "创建或运行容器" : "Create or Run Container")
                    .font(.headline)
                Spacer()
            }
            .padding([.horizontal, .top], 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    runFormSection(language.resolved == .zhHans ? "基础" : "Basics") {
                        Toggle(language.resolved == .zhHans ? "只创建，不启动" : "Create only", isOn: $newContainerCreateOnly)
                            .toggleStyle(.switch)
                        Toggle(language.resolved == .zhHans ? "自动命名" : "Automatic name", isOn: $useAutoContainerName)
                            .toggleStyle(.switch)

                        if !useAutoContainerName {
                            TextField(language.t(.name), text: $newContainerName)
                                .textFieldStyle(.roundedBorder)
                        }

                        Picker(language.t(.image), selection: $newContainerImage) {
                            ForEach(imageChoices, id: \.self) { reference in
                                Text(reference).tag(reference)
                            }
                        }

                        ThemedSegmentedPicker(
                            options: ContainerCommandPreset.allCases,
                            selection: $newContainerCommandPreset,
                            title: { $0.title(language: language) }
                        )

                        if newContainerCommandPreset == .custom {
                            TextField("command", text: $customContainerCommand)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    runFormSection(language.resolved == .zhHans ? "资源和进程" : "Resources and Process") {
                        HStack(spacing: 10) {
                            TextField("CPUs", text: $newContainerCPUs)
                            TextField("Memory", text: $newContainerMemory)
                            TextField("Platform", text: $newContainerPlatform)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            TextField("OS", text: $newContainerOS)
                            TextField("Arch", text: $newContainerArch)
                            TextField("max downloads", text: $newContainerMaxDownloads)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            TextField("User", text: $newContainerUser)
                            TextField("UID", text: $newContainerUID)
                            TextField("GID", text: $newContainerGID)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            TextField("Workdir", text: $newContainerWorkdir)
                            TextField("Entrypoint", text: $newContainerEntrypoint)
                            TextField("shm-size", text: $newContainerShmSize)
                        }
                        .textFieldStyle(.roundedBorder)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                            Toggle("-d", isOn: $newContainerDetached)
                            Toggle("-i", isOn: $newContainerInteractive)
                            Toggle("-t", isOn: $newContainerTTY)
                            Toggle("--rm", isOn: $newContainerRemove)
                            Toggle("--init", isOn: $newContainerInit)
                            Toggle("--read-only", isOn: $newContainerReadOnly)
                            Toggle("--rosetta", isOn: $newContainerRosetta)
                            Toggle("--ssh", isOn: $newContainerSSH)
                            Toggle("--virtualization", isOn: $newContainerVirtualization)
                            Toggle("--no-dns", isOn: $newContainerNoDNS)
                        }
                        .toggleStyle(.checkbox)
                    }

                    runFormSection(language.resolved == .zhHans ? "网络、挂载和元数据" : "Network, Mounts, Metadata") {
                        multilineField(title: "-p / --publish", text: $newContainerPorts, prompt: "8080:80/tcp")
                        multilineField(title: "-e / --env", text: $newContainerEnv, prompt: "KEY=value")
                        multilineField(title: "--env-file", text: $newContainerEnvFiles, prompt: "/path/to/.env")
                        multilineField(title: "-v / --volume", text: $newContainerVolumes, prompt: "name:/data:rw")
                        multilineField(title: "--mount", text: $newContainerMounts, prompt: "type=bind,source=/tmp,target=/tmp")
                        multilineField(title: "--network", text: $newContainerNetworks, prompt: "network-name")
                        multilineField(title: "--publish-socket", text: $newContainerPublishSockets, prompt: "/tmp/host.sock:/tmp/container.sock")
                        multilineField(title: "-l / --label", text: $newContainerLabels, prompt: "key=value")
                        multilineField(title: "--dns", text: $newContainerDNS, prompt: "1.1.1.1")
                        multilineField(title: "--dns-search", text: $newContainerDNSSearch, prompt: "svc.local")
                        multilineField(title: "--dns-option", text: $newContainerDNSOptions, prompt: "ndots:1")
                    }

                    runFormSection(language.resolved == .zhHans ? "高级" : "Advanced") {
                        HStack(spacing: 10) {
                            TextField("runtime", text: $newContainerRuntime)
                            TextField("kernel", text: $newContainerKernel)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            TextField("cidfile", text: $newContainerCIDFile)
                            TextField("init-image", text: $newContainerInitImage)
                        }
                        .textFieldStyle(.roundedBorder)
                        HStack(spacing: 10) {
                            Picker("scheme", selection: $newContainerScheme) {
                                ForEach(["auto", "https", "http"], id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            Picker("progress", selection: $newContainerProgress) {
                                ForEach(["auto", "none", "ansi", "plain", "color"], id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            TextField("dns-domain", text: $newContainerDNSDomain)
                                .textFieldStyle(.roundedBorder)
                        }
                        multilineField(title: "--tmpfs", text: $newContainerTmpfs, prompt: "/run")
                        multilineField(title: "--cap-add", text: $newContainerCapAdd, prompt: "CAP_NET_RAW")
                        multilineField(title: "--cap-drop", text: $newContainerCapDrop, prompt: "CAP_SYS_ADMIN")
                        multilineField(title: "--ulimit", text: $newContainerUlimits, prompt: "nofile=1024:2048")
                    }
                }
                .padding(16)
            }
            .frame(width: 560, height: 620)

            Divider()

            HStack {
                Spacer()
                Button("取消") {
                    showRunPopover = false
                }
                Button(newContainerCreateOnly ? (language.resolved == .zhHans ? "创建" : "Create") : (language.resolved == .zhHans ? "运行" : "Run")) {
                    submitContainerRun()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
    }

    private func runFormSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func multilineField(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private func submitContainerRun() {
        let commandText = newContainerCommandPreset.command(custom: customContainerCommand)
        let command: [String]
        do {
            command = try CommandLineTokenizer.split(commandText)
        } catch {
            runtimeStore.errorMessage = error.localizedDescription
            return
        }

        let options = ContainerRunOptions(
            createOnly: newContainerCreateOnly,
            name: useAutoContainerName ? nil : newContainerName,
            image: newContainerImage,
            command: command,
            detached: newContainerDetached,
            interactive: newContainerInteractive,
            tty: newContainerTTY,
            removeWhenStopped: newContainerRemove,
            readOnlyRoot: newContainerReadOnly,
            initProcess: newContainerInit,
            rosetta: newContainerRosetta,
            sshAgent: newContainerSSH,
            virtualization: newContainerVirtualization,
            noDNS: newContainerNoDNS,
            cpus: newContainerCPUs,
            memory: newContainerMemory,
            platform: newContainerPlatform,
            os: newContainerOS,
            arch: newContainerArch,
            user: newContainerUser,
            uid: newContainerUID,
            gid: newContainerGID,
            workdir: newContainerWorkdir,
            entrypoint: newContainerEntrypoint,
            runtime: newContainerRuntime,
            kernel: newContainerKernel,
            cidfile: newContainerCIDFile,
            initImage: newContainerInitImage,
            shmSize: newContainerShmSize,
            dnsDomain: newContainerDNSDomain,
            scheme: newContainerScheme,
            progress: newContainerProgress,
            maxConcurrentDownloads: newContainerMaxDownloads,
            env: lines(from: newContainerEnv),
            envFiles: lines(from: newContainerEnvFiles),
            labels: lines(from: newContainerLabels),
            ports: lines(from: newContainerPorts),
            volumes: lines(from: newContainerVolumes),
            mounts: lines(from: newContainerMounts),
            networks: lines(from: newContainerNetworks),
            publishSockets: lines(from: newContainerPublishSockets),
            tmpfs: lines(from: newContainerTmpfs),
            dns: lines(from: newContainerDNS),
            dnsSearch: lines(from: newContainerDNSSearch),
            dnsOptions: lines(from: newContainerDNSOptions),
            capAdd: lines(from: newContainerCapAdd),
            capDrop: lines(from: newContainerCapDrop),
            ulimits: lines(from: newContainerUlimits)
        )

        showRunPopover = false
        Task { await runtimeStore.runContainer(options: options) }
    }

    private func exportContainer(_ container: ContainerSummary) {
        guard container.state != "running" else {
            runtimeStore.errorMessage = language.resolved == .zhHans
                ? "容器运行中，停止后才能导出文件系统。"
                : "Stop the container before exporting its filesystem."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(container.id)-filesystem.tar"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await runtimeStore.exportContainer(id: container.id, outputPath: url.path) }
    }

    private func lines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}

private enum ContainerCommandPreset: String, CaseIterable, Identifiable {
    case imageDefault
    case keepAlive
    case shell
    case custom

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .imageDefault:
            language.resolved == .zhHans ? "默认" : "Default"
        case .keepAlive:
            "sleep"
        case .shell:
            "sh"
        case .custom:
            language.resolved == .zhHans ? "自定义" : "Custom"
        }
    }

    func command(custom: String) -> String {
        switch self {
        case .imageDefault:
            ""
        case .keepAlive:
            "sleep 3600"
        case .shell:
            "sh"
        case .custom:
            custom
        }
    }
}

private struct ContainerDetailOverview: View {
    @Environment(\.appLanguage) private var language
    var container: ContainerSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "容器" : "Container") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.status), value: container.state)
                    DetailInfoRow(title: language.t(.image), value: container.imageName)
                    DetailInfoRow(title: "IP", value: container.primaryIP, monospaced: true)
                    DetailInfoRow(title: "Platform", value: container.platformName)
                    DetailInfoRow(title: "Started", value: container.startedText)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "资源" : "Resources") {
                DetailInfoCard {
                    DetailInfoRow(title: "CPUs", value: "\(container.cpuCount)")
                    DetailInfoRow(title: "Memory", value: container.memoryDisplay)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "标识" : "Identity") {
                DetailInfoCard {
                    DetailInfoRow(title: "ID", value: container.id, monospaced: true)
                    DetailInfoRow(title: "State", value: container.state)
                }
            }
        }
    }
}
