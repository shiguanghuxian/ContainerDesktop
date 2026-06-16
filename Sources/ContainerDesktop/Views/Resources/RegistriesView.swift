import AppKit
import SwiftUI

struct RegistriesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var pendingLogout: RegistrySummary?
    @State private var showLoginPopover = false
    @State private var loginServerMode: RegistryLoginServerMode = .preset
    @State private var loginServer = "docker.io"
    @State private var customLoginServer = ""
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var showBrowserDrawer = false
    @State private var browserStore = RegistryBrowserStore()
    @State private var dockerHubQuery = "nginx"
    @State private var customRegistryServer = "registry-1.docker.io"
    @State private var customRepository = "library/nginx"
    @State private var browserContext: RegistryBrowserContext = .dockerHub
    @State private var selectedTagList: RegistryTagListSelection?
    @State private var selectedTagDetail: RegistryTagDetailSelection?

    private let registryActionColumnWidth: CGFloat = 104
    private let browserDrawerWidth: CGFloat = 840

    private var filteredRegistries: [RegistrySummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.registries }
        return runtimeStore.registries.filter {
            $0.server.lowercased().contains(query)
                || $0.displayName.lowercased().contains(query)
                || ($0.username?.lowercased().contains(query) ?? false)
        }
    }

    private var isLoginSubmitDisabled: Bool {
        runtimeStore.isRegistryOperationRunning
            || !loginServerSelection.canSubmit
            || loginUsername.trimmed.isEmpty
            || loginPassword.isEmpty
    }

    private var loginServerSelection: RegistryLoginServerSelection {
        RegistryLoginServerSelection(
            mode: loginServerMode,
            presetServer: loginServer,
            customServer: customLoginServer
        )
    }

    var body: some View {
        DrawerPageLayout(
            isDrawerPresented: showBrowserDrawer,
            onDismiss: closeBrowserDrawer,
            drawerWidth: browserDrawerWidth
        ) {
            pageContent
        } drawer: {
            registryBrowserDrawerStack
        }
        .alert("退出仓库登录？", isPresented: Binding(
            get: { pendingLogout != nil },
            set: { if !$0 { pendingLogout = nil } }
        )) {
            if let registry = pendingLogout {
                Button(language.t(.remove), role: .destructive) {
                    pendingLogout = nil
                    Task { await runtimeStore.logoutRegistry(registry.server) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将移除 \(pendingLogout?.server ?? "该仓库") 的登录凭据。")
        }
    }

    @ViewBuilder
    private var registryBrowserDrawerStack: some View {
        RegistryBrowserDrawer(
            context: browserContext,
            store: browserStore,
            query: $dockerHubQuery,
            customRegistryServer: $customRegistryServer,
            customRepository: $customRepository,
            selectedTagList: selectedTagList,
            selectedTagDetail: selectedTagDetail,
            onClose: closeBrowserDrawer,
            onOpenDockerHubRepository: openDockerHubTagList,
            onOpenRegistryV2Tags: openRegistryV2TagList,
            onResetTagSelection: resetTagSelection,
            onCloseTagList: closeTagList,
            onCloseTagDetail: closeTagDetail,
            onPull: { reference in
                Task { await runtimeStore.pullImage(reference) }
            },
            onShowTagDetail: showTagDetail
        )
    }

    private func openDockerHubBrowser() {
        browserContext = .dockerHub
        if dockerHubQuery.trimmed.isEmpty {
            dockerHubQuery = "nginx"
        }
        browserStore.searchQuery = dockerHubQuery.trimmed
        browserStore.resetRegistryV2State()
        selectedTagList = nil
        selectedTagDetail = nil
        showBrowserDrawer = true
    }

    private func openRegistryV2Browser(for registry: RegistrySummary) {
        customRegistryServer = registry.registryBrowseServer
        customRepository = ""
        browserContext = .registryV2(server: customRegistryServer)
        browserStore.customRegistryServer = customRegistryServer
        browserStore.customRepository = customRepository
        browserStore.resetRegistryV2State()
        selectedTagList = nil
        selectedTagDetail = nil
        showBrowserDrawer = true
    }

    private func openBrowser(for registry: RegistrySummary) {
        switch RegistryBrowserContext.context(for: registry) {
        case .dockerHub:
            openDockerHubBrowser()
        case .registryV2:
            openRegistryV2Browser(for: registry)
        }
    }

    private func openDockerHubTagList(_ repository: RegistryRepositoryResult) {
        let selection = RegistryTagListSelection(
            source: .dockerHub,
            title: language.resolved == .zhHans ? "Docker Hub 标签" : "Docker Hub Tags",
            displayName: repository.displayName,
            repository: repository.pullReference
        )
        showTagList(selection)
    }

    private func openRegistryV2TagList(_ result: RegistryV2RepositoryResult) {
        let server = result.server.trimmed
        let repository = result.repository.trimmed
        guard !server.isEmpty, !repository.isEmpty else { return }
        let selection = RegistryTagListSelection(
            source: .registryV2,
            title: language.resolved == .zhHans ? "Registry v2 标签" : "Registry v2 Tags",
            displayName: repository,
            repository: "\(server)/\(repository)"
        )
        showTagList(selection)
    }

    private func showTagList(_ selection: RegistryTagListSelection) {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagList = selection
            selectedTagDetail = nil
        }
    }

    private func resetTagSelection() {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagList = nil
            selectedTagDetail = nil
        }
    }

    private func showTagDetail(_ selection: RegistryTagDetailSelection) {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagDetail = selection
        }
    }

    private func closeTagList() {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagList = nil
            selectedTagDetail = nil
        }
    }

    private func closeTagDetail() {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagDetail = nil
        }
    }

    private func closeBrowserDrawer() {
        showBrowserDrawer = false
        selectedTagList = nil
        selectedTagDetail = nil
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.registries),
                subtitle: language.t(.registriesSubtitle),
                systemImage: "key.icloud"
            ) {
                HStack(spacing: 8) {
                    Button {
                        openDockerHubBrowser()
                    } label: {
                        Label(language.resolved == .zhHans ? "浏览镜像" : "Browse Images", systemImage: "safari")
                    }
                    .help(language.resolved == .zhHans ? "打开 Docker Hub 镜像浏览" : "Open Docker Hub image browser")

                    Button {
                        showLoginPopover = true
                    } label: {
                        Label(language.resolved == .zhHans ? "登录仓库" : "Login", systemImage: "person.badge.key")
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showLoginPopover) {
                        loginForm
                    }
                    .disabled(runtimeStore.isRegistryOperationRunning)
                    .help(language.resolved == .zhHans ? "登录镜像仓库" : "Login to a registry")

                    Button {
                        Task { await runtimeStore.refreshRegistries(reportSuccess: true) }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .disabled(runtimeStore.isRegistryOperationRunning)
                    .help(language.resolved == .zhHans ? "刷新仓库登录列表" : "Refresh registry logins")
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Text(language.itemCount(filteredRegistries.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let message = runtimeStore.registryStatusMessage {
                StatusBanner(
                    text: message,
                    systemImage: runtimeStore.registryStatusIsError ? "exclamationmark.triangle" : "checkmark.circle",
                    tint: runtimeStore.registryStatusIsError ? CDTheme.ember : CDTheme.lime
                )
                .frame(maxWidth: 720)
            }

            ResourceTable {
                registryHeader
            } rows: {
                if filteredRegistries.isEmpty {
                    EmptyStateView(title: language.t(.noRegistries), message: "使用 container registry login 后，这里会展示登录项。", systemImage: "key.icloud")
                        .padding(18)
                } else {
                    ForEach(filteredRegistries) { registry in
                        ResourceTableRow {
                            ResourceStatusDot(tint: CDTheme.lime)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(registry.displayName)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                if let detailServer = registry.detailServer {
                                    Text(detailServer)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(registry.usernameText)
                                .font(.callout.monospaced())
                                .foregroundStyle(registry.username == nil ? .secondary : .primary)
                                .lineLimit(1)
                                .frame(width: 150, alignment: .leading)

                            StatusPill(title: language.resolved == .zhHans ? "已登录" : "logged in", systemImage: "checkmark.seal", tint: CDTheme.lime)
                                .frame(width: 120, alignment: .leading)

                            HStack(spacing: 8) {
                                RowActionButton(
                                    systemImage: "safari",
                                    help: language.resolved == .zhHans ? "浏览镜像" : "Browse images"
                                ) {
                                    openBrowser(for: registry)
                                }
                                DestructiveRowActionButton(
                                    systemImage: "rectangle.portrait.and.arrow.right",
                                    help: language.resolved == .zhHans ? "退出登录" : "Logout"
                                ) {
                                    pendingLogout = registry
                                }
                            }
                            .frame(width: registryActionColumnWidth, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "登录镜像仓库" : "Login to Registry")
                .font(.headline)

            ThemedSegmentedPicker(
                options: RegistryLoginServerMode.allCases,
                selection: $loginServerMode,
                title: loginServerModeTitle
            )
            .frame(width: 320)
            .disabled(runtimeStore.isRegistryOperationRunning)

            VStack(alignment: .leading, spacing: 6) {
                if loginServerMode == .preset {
                    Picker(language.resolved == .zhHans ? "仓库" : "Registry", selection: $loginServer) {
                        ForEach(FormPresetOptions.choices(current: loginServer, suggestions: FormPresetOptions.registries), id: \.self) { server in
                            Text(server).tag(server)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 320)
                    .disabled(runtimeStore.isRegistryOperationRunning)
                } else {
                    TextField("registry.example.com:5000", text: $customLoginServer)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                        .disabled(runtimeStore.isRegistryOperationRunning)

                    Text(language.resolved == .zhHans
                        ? "支持私有 Registry 域名或 host:port，不需要填写镜像路径。"
                        : "Use a registry domain or host:port. Do not include an image path.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 320, alignment: .leading)
                }
            }

            TextField(language.resolved == .zhHans ? "用户名" : "Username", text: $loginUsername)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .disabled(runtimeStore.isRegistryOperationRunning)

            SecureField(language.resolved == .zhHans ? "密码或 Token" : "Password or token", text: $loginPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
                .disabled(runtimeStore.isRegistryOperationRunning)

            if runtimeStore.isRegistryOperationRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(language.resolved == .zhHans ? "正在验证并写入钥匙串..." : "Verifying and writing to Keychain...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("取消") {
                    showLoginPopover = false
                    loginPassword = ""
                }
                .disabled(runtimeStore.isRegistryOperationRunning)
                .help(language.resolved == .zhHans ? "取消登录" : "Cancel login")
                Button {
                    let server = loginServerSelection.resolvedServer
                    let username = loginUsername
                    let password = loginPassword
                    loginPassword = ""
                    Task {
                        await runtimeStore.loginRegistry(server: server, username: username, password: password)
                        if !runtimeStore.registryStatusIsError {
                            showLoginPopover = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if runtimeStore.isRegistryOperationRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(runtimeStore.isRegistryOperationRunning ? (language.resolved == .zhHans ? "登录中" : "Logging in") : (language.resolved == .zhHans ? "登录" : "Login"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoginSubmitDisabled)
                .help(language.resolved == .zhHans ? "登录当前仓库" : "Login to the selected registry")
            }
        }
        .padding(16)
    }

    private func loginServerModeTitle(_ mode: RegistryLoginServerMode) -> String {
        switch mode {
        case .preset:
            return language.resolved == .zhHans ? "常用仓库" : "Presets"
        case .custom:
            return language.resolved == .zhHans ? "自定义地址" : "Custom"
        }
    }

    private var registryHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: "Server")
            ResourceTableHeaderLabel(title: language.resolved == .zhHans ? "用户名" : "Username", width: 150)
            ResourceTableHeaderLabel(title: language.t(.status), width: 120)
            ResourceTableHeaderLabel(title: language.t(.actions), width: registryActionColumnWidth, alignment: .trailing)
        }
    }
}

private struct RegistryBrowserDrawer: View {
    @Environment(\.appLanguage) private var language
    var context: RegistryBrowserContext
    @Bindable var store: RegistryBrowserStore
    @Binding var query: String
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    var selectedTagList: RegistryTagListSelection?
    var selectedTagDetail: RegistryTagDetailSelection?
    var onClose: () -> Void
    var onOpenDockerHubRepository: (RegistryRepositoryResult) -> Void
    var onOpenRegistryV2Tags: (RegistryV2RepositoryResult) -> Void
    var onResetTagSelection: () -> Void
    var onCloseTagList: () -> Void
    var onCloseTagDetail: () -> Void
    var onPull: (String) -> Void
    var onShowTagDetail: (RegistryTagDetailSelection) -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            browserContent

            if let selectedTagList {
                RegistryTagListOverlay(
                    store: store,
                    selection: selectedTagList,
                    onClose: onCloseTagList,
                    onPull: onPull,
                    onResetTagDetail: onCloseTagDetail,
                    onShowTagDetail: onShowTagDetail
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

            if let selectedTagDetail {
                RegistryTagDetailOverlay(
                    selection: selectedTagDetail,
                    isLoading: selectedTagDetail.isRegistryV2 && store.isLoadingCustomTagDetails,
                    onClose: onCloseTagDetail,
                    onPull: onPull
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .drawerSurface(width: 840)
        .task(id: context) {
            switch context {
            case .dockerHub:
                if store.repositories.isEmpty {
                    store.searchQuery = query
                    await store.searchDockerHub()
                }
            case .registryV2:
                break
            }
        }
    }

    private var browserContent: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "浏览镜像" : "Browse Images",
                subtitle: context.displayName,
                systemImage: "magnifyingglass",
                onClose: onClose
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RegistryBrowserNotice()
                    RegistryBrowserPanel(
                        context: context,
                        store: store,
                        query: $query,
                        customRegistryServer: $customRegistryServer,
                        customRepository: $customRepository,
                        onOpenDockerHubRepository: onOpenDockerHubRepository,
                        onOpenRegistryV2Tags: onOpenRegistryV2Tags,
                        onResetTagSelection: onResetTagSelection
                    )
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RegistryBrowserNotice: View {
    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(language.t(.loginInstructions))
                    .font(.callout.weight(.semibold))
                Text(language.resolved == .zhHans ? "登录信息由 container CLI 写入 macOS 钥匙串；私有 Registry 浏览会自动读取该凭据，\(AppBranding.displayName) 不保存密码。" : "Credentials are written by the container CLI to macOS Keychain. Private registry browsing reads those credentials and \(AppBranding.displayName) does not save passwords.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

private struct RegistryBrowserPanel: View {
    @Environment(\.appLanguage) private var language
    var context: RegistryBrowserContext
    @Bindable var store: RegistryBrowserStore
    @Binding var query: String
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    var onOpenDockerHubRepository: (RegistryRepositoryResult) -> Void
    var onOpenRegistryV2Tags: (RegistryV2RepositoryResult) -> Void
    var onResetTagSelection: () -> Void

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "Registry 浏览" : "Registry Browser",
            subtitle: context.displayName,
            systemImage: "magnifyingglass"
        ) {
            switch context {
            case .dockerHub:
                dockerHubContent
            case .registryV2(let server):
                registryV2Content(server: server)
            }
        }
    }

    private var dockerHubContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                TextField("nginx", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button {
                    onResetTagSelection()
                    store.searchQuery = query
                    Task { await store.searchDockerHub(page: 1) }
                } label: {
                    if store.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(language.t(.search), systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSearching || query.trimmed.isEmpty)
                .help(language.resolved == .zhHans ? "搜索 Docker Hub 镜像" : "Search Docker Hub images")
            }

            if let errorMessage = store.errorMessage {
                StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            repositoryList
        }
    }

    private func registryV2Content(server: String) -> some View {
        RegistryV2ManualLookupSection(
            store: store,
            server: server,
            customRegistryServer: $customRegistryServer,
            customRepository: $customRepository,
            onSearchRepository: searchCustomRepository,
            onOpenTags: onOpenRegistryV2Tags,
            onResetTagSelection: onResetTagSelection
        )
    }

    private func searchCustomRepository() {
        Task { await store.searchCustomRepository() }
    }

    private var repositoryList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Docker Hub")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let total = store.repositoryTotalCount {
                    Text("\(total.formatted())")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if store.repositories.isEmpty {
                Text(language.resolved == .zhHans ? "暂无搜索结果。" : "No search results.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.repositories.prefix(12)) { repository in
                    Button {
                        store.selectedRepository = repository
                        store.tags = []
                        store.selectedTag = nil
                        store.tagPage = 1
                        store.tagTotalCount = nil
                        store.tagHasNext = false
                        onOpenDockerHubRepository(repository)
                        Task { await store.loadTags(for: repository) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: repository.isOfficial ? "checkmark.seal.fill" : "shippingbox")
                                .foregroundStyle(repository.isOfficial ? CDTheme.lime : CDTheme.dockerBlue)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repository.displayName)
                                    .font(.callout.weight(.semibold))
                                    .lineLimit(1)
                                Text(repository.description.nilIfBlank ?? "—")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(repository.pullsDisplay)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 6)
                        .background(store.selectedRepository == repository ? CDTheme.selectionSurface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(language.resolved == .zhHans ? "查看镜像标签" : "View image tags")
                    Divider()
                }
            }
            HStack {
                Button(language.resolved == .zhHans ? "上一页" : "Previous") {
                    onResetTagSelection()
                    Task { await store.loadPreviousRepositoryPage() }
                }
                .disabled(store.repositoryPage <= 1 || store.isSearching)
                .help(language.resolved == .zhHans ? "上一页搜索结果" : "Previous search results page")
                Text("\(store.repositoryPage)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button(language.resolved == .zhHans ? "下一页" : "Next") {
                    onResetTagSelection()
                    Task { await store.loadNextRepositoryPage() }
                }
                .disabled(!store.repositoryHasNext || store.isSearching)
                .help(language.resolved == .zhHans ? "下一页搜索结果" : "Next search results page")
                Spacer()
            }
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
        .frame(minHeight: 420, alignment: .top)
    }
}

private struct RegistryV2ManualLookupSection: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: RegistryBrowserStore
    var server: String
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    var onSearchRepository: () -> Void
    var onOpenTags: (RegistryV2RepositoryResult) -> Void
    var onResetTagSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            registryControls
            manualRepositoryLookup
            repositorySearchResult
        }
        .onAppear {
            customRegistryServer = server
            store.customRegistryServer = server
        }
        .onChange(of: customRepository) { _, newValue in
            guard newValue.trimmed.isEmpty || newValue.trimmed != store.customRepository.trimmed else { return }
            store.resetCustomRegistryTags()
            onResetTagSelection()
        }
        .onChange(of: store.customRegistryScheme) { _, _ in
            store.resetCustomRegistryTags()
            onResetTagSelection()
        }
    }

    private var registryControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "network")
                    .foregroundStyle(CDTheme.dockerBlue)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(language.resolved == .zhHans ? "当前 Registry" : "Current Registry")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(server)
                        .font(.callout.weight(.semibold).monospaced())
                        .lineLimit(1)
                    Text(language.resolved == .zhHans ? "只查询当前仓库中心。输入 repository 后会使用 container 登录写入的钥匙串凭据读取 tags。" : "Queries only this registry. Enter a repository and tags are loaded with credentials from the container Keychain login.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if store.isLoadingTags {
                    StableLoadingIndicator(text: language.resolved == .zhHans ? "读取中" : "Loading")
                }
            }

            HStack(spacing: 8) {
                Picker("scheme", selection: $store.customRegistryScheme) {
                    Text("https").tag("https")
                    Text("http").tag("http")
                }
                .labelsHidden()
                .frame(width: 88)

                Text(language.resolved == .zhHans ? "认证：使用已登录的钥匙串凭据" : "Auth: uses saved Keychain credentials")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
        }
        .padding(12)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var manualRepositoryLookup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.resolved == .zhHans ? "手动查询 repository" : "Manual repository lookup")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(language.resolved == .zhHans ? "仅查询当前 Registry：\(server)。请输入 repository 名称，不需要填写 server。" : "Queries only \(server). Enter the repository name without the server.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorMessage = store.errorMessage {
                StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }
            HStack(spacing: 8) {
                TextField("team/app", text: $customRepository)
                    .textFieldStyle(.roundedBorder)
                Button {
                    submitSearch()
                } label: {
                    HStack(spacing: 7) {
                        if store.isLoadingTags {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text(store.isLoadingTags ? (language.resolved == .zhHans ? "查询中" : "Searching") : language.t(.search))
                    }
                    .frame(width: 94)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoadingTags || customRepository.trimmed.isEmpty)
                .help(language.resolved == .zhHans ? "查询当前 Registry 中的 repository" : "Search the repository in the current registry")
            }
        }
        .padding(12)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var repositorySearchResult: some View {
        Group {
            if let result = store.customRegistryRepositoryResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text(language.resolved == .zhHans ? "搜索结果" : "Search Result")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Button {
                        openTags(for: result)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "shippingbox")
                                .foregroundStyle(CDTheme.dockerBlue)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.repository)
                                    .font(.callout.weight(.semibold).monospaced())
                                    .lineLimit(1)
                                Text(resultSummaryText(for: result))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(tagCountText(for: result))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(CDTheme.separator)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(language.resolved == .zhHans ? "打开标签列表" : "Open tag list")
                }
            }
        }
    }

    private func submitSearch() {
        let repository = customRepository.trimmed
        guard !repository.isEmpty else { return }
        customRegistryServer = server
        store.customRegistryServer = server
        store.customRepository = repository
        store.resetCustomRegistryTags()
        onResetTagSelection()
        onSearchRepository()
    }

    private func openTags(for result: RegistryV2RepositoryResult) {
        customRegistryServer = result.server
        customRepository = result.repository
        store.customRegistryServer = result.server
        store.customRepository = result.repository
        store.customRegistryRepositoryResult = result
        onOpenTags(result)
    }

    private func resultSummaryText(for result: RegistryV2RepositoryResult) -> String {
        if language.resolved == .zhHans {
            return result.hasNextPage ? "已加载 \(result.tagCount) 个 tags，可能还有更多" : "已加载 \(result.tagCount) 个 tags"
        }
        return result.hasNextPage ? "\(result.tagCount) tags loaded, more may exist" : "\(result.tagCount) tags loaded"
    }

    private func tagCountText(for result: RegistryV2RepositoryResult) -> String {
        "\(result.tagCount)"
    }
}

private struct RegistryTagListOverlay: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: RegistryBrowserStore
    var selection: RegistryTagListSelection
    var onClose: () -> Void
    var onPull: (String) -> Void
    var onResetTagDetail: () -> Void
    var onShowTagDetail: (RegistryTagDetailSelection) -> Void

    private var tags: [RegistryImageTag] {
        selection.isRegistryV2 ? store.customRegistryTags : store.tags
    }

    private var totalText: String? {
        if selection.isRegistryV2 {
            return tags.isEmpty ? nil : "\(tags.count.formatted())"
        }
        return store.tagTotalCount.map { "\($0.formatted())" }
    }

    private var isLoading: Bool {
        store.isLoadingTags
    }

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "标签列表" : "Tags",
                subtitle: selection.pullReference,
                systemImage: "tag",
                onClose: onClose
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard

                    if let errorMessage = store.errorMessage {
                        StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                    }

                    tagList
                    paginationControls
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .drawerSurface(width: 620)
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: selection.isRegistryV2 ? "network" : "shippingbox")
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(selection.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(selection.displayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(selection.pullReference)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isLoading {
                StableLoadingIndicator(text: language.resolved == .zhHans ? "读取中" : "Loading")
            } else if let totalText {
                Text(totalText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var tagList: some View {
        VStack(spacing: 0) {
            if tags.isEmpty {
                emptyTagState
            } else {
                let visibleTags = Array(tags.prefix(18))
                ForEach(visibleTags) { tag in
                    tagRow(tag)
                    if tag.id != visibleTags.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(minHeight: 420, alignment: .top)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var emptyTagState: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
            }
            Text(isLoading
                ? (language.resolved == .zhHans ? "正在读取 tags..." : "Loading tags...")
                : (language.resolved == .zhHans ? "暂无 tags。" : "No tags."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }

    private func tagRow(_ tag: RegistryImageTag) -> some View {
        HStack(spacing: 10) {
            Button {
                selectTag(tag)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tag.name)
                            .font(.callout.weight(.semibold).monospaced())
                            .lineLimit(1)
                        Text(tagMetadataText(for: tag))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isSelected(tag) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(CDTheme.dockerBlue)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(language.resolved == .zhHans ? "打开 Tag 详情" : "Open tag details")

            Button(language.t(.pull)) {
                onPull(selection.reference(for: tag))
            }
            .buttonStyle(.borderless)
            .help(language.resolved == .zhHans ? "拉取此 Tag" : "Pull this tag")
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(isSelected(tag) ? CDTheme.selectionSurface : Color.clear)
    }

    private var paginationControls: some View {
        HStack {
            Button(language.resolved == .zhHans ? "上一页" : "Previous") {
                onResetTagDetail()
                Task {
                    if selection.isRegistryV2 {
                        await store.loadPreviousCustomRegistryPage()
                    } else {
                        await store.loadPreviousTagPage()
                    }
                }
            }
            .disabled(isPreviousDisabled)
            .help(language.resolved == .zhHans ? "上一页标签" : "Previous tag page")
            Text(pageText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(language.resolved == .zhHans ? "下一页" : "Next") {
                onResetTagDetail()
                Task {
                    if selection.isRegistryV2 {
                        await store.loadNextCustomRegistryPage()
                    } else {
                        await store.loadNextTagPage()
                    }
                }
            }
            .disabled(isNextDisabled)
            .help(language.resolved == .zhHans ? "下一页标签" : "Next tag page")
            Spacer()
        }
    }

    private var isPreviousDisabled: Bool {
        if isLoading { return true }
        if selection.isRegistryV2 {
            return store.customRegistryCursorStack.isEmpty
        }
        return store.tagPage <= 1
    }

    private var isNextDisabled: Bool {
        if isLoading { return true }
        if selection.isRegistryV2 {
            return store.customRegistryNextCursor == nil
        }
        return !store.tagHasNext
    }

    private var pageText: String {
        selection.isRegistryV2 ? "\(store.customRegistryCursorStack.count + 1)" : "\(store.tagPage)"
    }

    private func selectTag(_ tag: RegistryImageTag) {
        if selection.isRegistryV2 {
            store.selectedCustomRegistryTag = tag
            onShowTagDetail(tagDetailSelection(for: tag))
            Task { @MainActor in
                await store.selectCustomRegistryTag(tag)
                if let selectedCustomRegistryTag = store.selectedCustomRegistryTag,
                   selectedCustomRegistryTag.name == tag.name {
                    onShowTagDetail(tagDetailSelection(for: selectedCustomRegistryTag))
                }
            }
        } else {
            store.selectedTag = tag
            onShowTagDetail(tagDetailSelection(for: tag))
        }
    }

    private func tagDetailSelection(for tag: RegistryImageTag) -> RegistryTagDetailSelection {
        RegistryTagDetailSelection(
            source: selection.source,
            title: selection.isRegistryV2
                ? (language.resolved == .zhHans ? "Registry v2 Tag 详情" : "Registry v2 Tag Details")
                : (language.resolved == .zhHans ? "Docker Hub Tag 详情" : "Docker Hub Tag Details"),
            repository: selection.pullReference,
            tag: tag
        )
    }

    private func isSelected(_ tag: RegistryImageTag) -> Bool {
        if selection.isRegistryV2 {
            return store.selectedCustomRegistryTag == tag
        }
        return store.selectedTag == tag
    }

    private func tagMetadataText(for tag: RegistryImageTag) -> String {
        "\(tag.sizeDisplay) · \(tag.updatedText) · \(tag.mediaTypeText) · \(tag.platformCountText) platforms"
    }
}

private struct RegistryTagDetailOverlay: View {
    @Environment(\.appLanguage) private var language
    var selection: RegistryTagDetailSelection
    var isLoading: Bool
    var onClose: () -> Void
    var onPull: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "Tag 详情" : "Tag Details",
                subtitle: selection.reference,
                systemImage: "tag",
                onClose: onClose
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        StableLoadingIndicator(text: language.resolved == .zhHans ? "正在读取 manifest 详情..." : "Loading manifest details...")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(CDTheme.separator)
                            }
                    }

                    RegistryTagDetailCard(
                        title: selection.title,
                        repository: selection.repository,
                        tag: selection.tag,
                        onPull: {
                            onPull(selection.reference)
                        }
                    )
                }
                .padding(16)
            }
            .thinScrollBars()
        }
        .drawerSurface(width: 620)
    }
}

private struct StableLoadingIndicator: View {
    var text: String

    var body: some View {
        HStack(spacing: 7) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct RegistryTagDetailCard: View {
    @Environment(\.appLanguage) private var language
    var title: String
    var repository: String
    var tag: RegistryImageTag
    var onPull: () -> Void

    private var reference: String {
        "\(repository):\(tag.name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(title, systemImage: "tag")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button {
                    copy(reference)
                } label: {
                    Label(language.resolved == .zhHans ? "复制引用" : "Copy Reference", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(language.resolved == .zhHans ? "复制完整镜像引用" : "Copy full image reference")
                Button(language.t(.pull)) {
                    onPull()
                }
                .buttonStyle(.borderedProminent)
                .help(language.resolved == .zhHans ? "拉取此镜像 Tag" : "Pull this image tag")
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    metric(language.resolved == .zhHans ? "引用" : "Reference", reference, monospaced: true)
                    metric(language.t(.tag), tag.name, monospaced: true)
                }
                GridRow {
                    metric(language.t(.size), tag.sizeDisplay)
                    metric(language.resolved == .zhHans ? "更新时间" : "Updated", tag.updatedText)
                }
                GridRow {
                    metric("Media Type", tag.mediaTypeText)
                    metric(language.resolved == .zhHans ? "平台数" : "Platform Count", tag.platformCountText)
                }
                GridRow {
                    metric("Digest", tag.digestText, monospaced: true)
                    metric(language.resolved == .zhHans ? "平台" : "Platforms", tag.platformsText)
                }
            }
        }
        .padding(12)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func metric(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
