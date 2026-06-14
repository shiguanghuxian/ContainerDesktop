import AppKit
import SwiftUI

struct RegistriesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var pendingLogout: RegistrySummary?
    @State private var showLoginPopover = false
    @State private var loginServer = "docker.io"
    @State private var loginUsername = ""
    @State private var loginPassword = ""
    @State private var showBrowserDrawer = false
    @State private var browserStore = RegistryBrowserStore()
    @State private var dockerHubQuery = "nginx"
    @State private var customRegistryServer = "registry-1.docker.io"
    @State private var customRepository = "library/nginx"
    @State private var isRegistryV2Expanded = false
    @State private var selectedTagDetail: RegistryTagDetailSelection?

    private let registryActionColumnWidth: CGFloat = 104
    private let browserDrawerWidth: CGFloat = 840
    private let tagDetailDrawerWidth: CGFloat = 520
    private let drawerSpacing: CGFloat = 12

    private var activeDrawerWidth: CGFloat {
        browserDrawerWidth + (selectedTagDetail == nil ? 0 : drawerSpacing + tagDetailDrawerWidth)
    }

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
            || loginServer.trimmed.isEmpty
            || loginUsername.trimmed.isEmpty
            || loginPassword.isEmpty
    }

    var body: some View {
        DrawerPageLayout(
            isDrawerPresented: showBrowserDrawer,
            onDismiss: closeBrowserDrawer,
            drawerWidth: activeDrawerWidth
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
        HStack(alignment: .top, spacing: drawerSpacing) {
            RegistryBrowserDrawer(
                store: browserStore,
                query: $dockerHubQuery,
                customRegistryServer: $customRegistryServer,
                customRepository: $customRepository,
                isRegistryV2Expanded: $isRegistryV2Expanded,
                onClose: closeBrowserDrawer,
                onPull: { reference in
                    Task { await runtimeStore.pullImage(reference) }
                },
                onShowTagDetail: showTagDetail
            )

            if let selectedTagDetail {
                RegistryTagDetailDrawer(
                    selection: selectedTagDetail,
                    isLoading: selectedTagDetail.isRegistryV2 && browserStore.isLoadingCustomTagDetails,
                    onClose: closeTagDetail,
                    onPull: { reference in
                        Task { await runtimeStore.pullImage(reference) }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: activeDrawerWidth, alignment: .trailing)
    }

    private func openDockerHubBrowser() {
        if dockerHubQuery.trimmed.isEmpty {
            dockerHubQuery = "nginx"
        }
        browserStore.searchQuery = dockerHubQuery.trimmed
        isRegistryV2Expanded = false
        selectedTagDetail = nil
        showBrowserDrawer = true
    }

    private func openRegistryV2Browser(for registry: RegistrySummary) {
        customRegistryServer = registry.registryBrowseServer
        customRepository = ""
        browserStore.customRegistryServer = customRegistryServer
        browserStore.customRepository = customRepository
        browserStore.selectedCustomRegistryTag = nil
        browserStore.customRegistryTags = []
        browserStore.customRegistryNextCursor = nil
        browserStore.customRegistryCursorStack = []
        isRegistryV2Expanded = true
        selectedTagDetail = nil
        showBrowserDrawer = true
    }

    private func openBrowser(for registry: RegistrySummary) {
        if registry.isDockerHubRegistry {
            openDockerHubBrowser()
        } else {
            openRegistryV2Browser(for: registry)
        }
    }

    private func showTagDetail(_ selection: RegistryTagDetailSelection) {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagDetail = selection
        }
    }

    private func closeTagDetail() {
        withAnimation(.snappy(duration: 0.2)) {
            selectedTagDetail = nil
        }
    }

    private func closeBrowserDrawer() {
        showBrowserDrawer = false
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

                    Button {
                        Task { await runtimeStore.refreshRegistries(reportSuccess: true) }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                    .disabled(runtimeStore.isRegistryOperationRunning)
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
                                DestructiveRowActionButton(systemImage: "rectangle.portrait.and.arrow.right") {
                                    pendingLogout = registry
                                }
                                .help(language.resolved == .zhHans ? "退出登录" : "Logout")
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

            Picker(language.resolved == .zhHans ? "仓库" : "Registry", selection: $loginServer) {
                ForEach(FormPresetOptions.choices(current: loginServer, suggestions: FormPresetOptions.registries), id: \.self) { server in
                    Text(server).tag(server)
                }
            }
            .labelsHidden()
            .frame(width: 320)
            .disabled(runtimeStore.isRegistryOperationRunning)

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
                Button {
                    let server = loginServer
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
            }
        }
        .padding(16)
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
    @Bindable var store: RegistryBrowserStore
    @Binding var query: String
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    @Binding var isRegistryV2Expanded: Bool
    var onClose: () -> Void
    var onPull: (String) -> Void
    var onShowTagDetail: (RegistryTagDetailSelection) -> Void

    var body: some View {
        VStack(spacing: 0) {
            DrawerHeader(
                title: language.resolved == .zhHans ? "浏览镜像" : "Browse Images",
                subtitle: "Docker Hub + Registry v2",
                systemImage: "magnifyingglass",
                onClose: onClose
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RegistryBrowserNotice()
                    RegistryBrowserPanel(
                        store: store,
                        query: $query,
                        customRegistryServer: $customRegistryServer,
                        customRepository: $customRepository,
                        isRegistryV2Expanded: $isRegistryV2Expanded,
                        onPull: onPull,
                        onShowTagDetail: onShowTagDetail
                    )
                }
                .padding(16)
            }
        }
        .drawerSurface(width: 840)
        .task {
            if store.repositories.isEmpty {
                store.searchQuery = query
                await store.searchDockerHub()
            }
        }
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
                Text(language.resolved == .zhHans ? "登录信息由 container CLI 写入 macOS 钥匙串；自定义 Registry 浏览只用于本次查询，不在 ContainerDesktop 保存密码。" : "Credentials are written by the container CLI to macOS Keychain. Custom Registry browser credentials are used for this query only and are not saved by ContainerDesktop.")
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
    @Bindable var store: RegistryBrowserStore
    @Binding var query: String
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    @Binding var isRegistryV2Expanded: Bool
    var onPull: (String) -> Void
    var onShowTagDetail: (RegistryTagDetailSelection) -> Void

    var body: some View {
        PanelView(
            title: language.resolved == .zhHans ? "Registry 浏览" : "Registry Browser",
            subtitle: "Docker Hub + Registry v2",
            systemImage: "magnifyingglass"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    TextField("nginx", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button {
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
                    .disabled(store.isSearching)
                }

                if let errorMessage = store.errorMessage {
                    StatusBanner(text: errorMessage, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        repositoryList
                            .frame(maxWidth: .infinity)
                        tagList
                            .frame(maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        repositoryList
                        tagList
                    }
                }

                RegistryV2BrowserSection(
                    store: store,
                    isExpanded: $isRegistryV2Expanded,
                    customRegistryServer: $customRegistryServer,
                    customRepository: $customRepository,
                    onPull: onPull,
                    onShowTagDetail: onShowTagDetail
                )
            }
        }
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
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            HStack {
                Button(language.resolved == .zhHans ? "上一页" : "Previous") {
                    Task { await store.loadPreviousRepositoryPage() }
                }
                .disabled(store.repositoryPage <= 1 || store.isSearching)
                Text("\(store.repositoryPage)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button(language.resolved == .zhHans ? "下一页" : "Next") {
                    Task { await store.loadNextRepositoryPage() }
                }
                .disabled(!store.repositoryHasNext || store.isSearching)
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

    private var tagList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.selectedRepository?.displayName ?? "Tags")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if let total = store.tagTotalCount {
                    Text("\(total.formatted())")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if store.isLoadingTags {
                ProgressView()
                    .controlSize(.small)
            } else if store.tags.isEmpty {
                Text(language.resolved == .zhHans ? "选择仓库查看 tag。" : "Select a repository to inspect tags.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.tags.prefix(12)) { tag in
                    HStack(spacing: 10) {
                        Button {
                            store.selectedTag = tag
                            if let repository = store.selectedRepository {
                                onShowTagDetail(RegistryTagDetailSelection(
                                    source: .dockerHub,
                                    title: language.resolved == .zhHans ? "Docker Hub Tag 详情" : "Docker Hub Tag Details",
                                    repository: repository.pullReference,
                                    tag: tag
                                ))
                            }
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tag.name)
                                        .font(.callout.weight(.semibold).monospaced())
                                    Text("\(tag.sizeDisplay) · \(tag.updatedText) · \(tag.mediaTypeText) · \(tag.platformCountText) platforms")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.selectedTag == tag {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(CDTheme.dockerBlue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button(language.t(.pull)) {
                            if let repository = store.selectedRepository?.pullReference.nilIfBlank {
                                onPull("\(repository):\(tag.name)")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 7)
                    Divider()
                }
            }
            HStack {
                Button(language.resolved == .zhHans ? "上一页" : "Previous") {
                    Task { await store.loadPreviousTagPage() }
                }
                .disabled(store.tagPage <= 1 || store.isLoadingTags)
                Text("\(store.tagPage)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button(language.resolved == .zhHans ? "下一页" : "Next") {
                    Task { await store.loadNextTagPage() }
                }
                .disabled(!store.tagHasNext || store.isLoadingTags)
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

private struct RegistryV2BrowserSection: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: RegistryBrowserStore
    @Binding var isExpanded: Bool
    @Binding var customRegistryServer: String
    @Binding var customRepository: String
    var onPull: (String) -> Void
    var onShowTagDetail: (RegistryTagDetailSelection) -> Void

    private var repositoryReference: String {
        "\(customRegistryServer.trimmed)/\(customRepository.trimmed)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(CDTheme.dockerBlue)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Registry v2 tags/list")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(language.resolved == .zhHans ? "用于私有仓库或非 Docker Hub 的一次性查询" : "One-off lookup for private registries or non-Docker Hub repositories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if store.isLoadingTags || store.isLoadingCustomTagDetails {
                        StableLoadingIndicator(text: language.resolved == .zhHans ? "读取中" : "Loading")
                    }
                }
                .contentShape(Rectangle())
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    registryInputs
                    customTagList
                    paginationControls
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var registryInputs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Picker("scheme", selection: $store.customRegistryScheme) {
                    Text("https").tag("https")
                    Text("http").tag("http")
                }
                .labelsHidden()
                .frame(width: 88)
                TextField("registry-1.docker.io", text: $customRegistryServer)
                    .textFieldStyle(.roundedBorder)
                TextField("library/nginx", text: $customRepository)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 8) {
                TextField(language.resolved == .zhHans ? "用户名（可选）" : "Username (optional)", text: $store.customRegistryUsername)
                    .textFieldStyle(.roundedBorder)
                SecureField(language.resolved == .zhHans ? "密码或 Token（不保存）" : "Password or token (not saved)", text: $store.customRegistryPassword)
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.customRegistryServer = customRegistryServer
                    store.customRepository = customRepository
                    Task { await store.loadCustomRegistryTags() }
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
                .disabled(store.isLoadingTags)
            }
        }
    }

    private var customTagList: some View {
        VStack(spacing: 0) {
            if store.customRegistryTags.isEmpty {
                VStack(spacing: 8) {
                    if store.isLoadingTags {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                    }
                    Text(store.isLoadingTags
                        ? (language.resolved == .zhHans ? "正在读取 tags..." : "Loading tags...")
                        : (language.resolved == .zhHans ? "输入仓库后查询 tags。" : "Enter a repository and search tags."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ForEach(store.customRegistryTags.prefix(18)) { tag in
                    customTagRow(tag)
                    if tag.id != store.customRegistryTags.prefix(18).last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(minHeight: 220, alignment: .top)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.hairline)
        }
    }

    private func customTagRow(_ tag: RegistryImageTag) -> some View {
        HStack(spacing: 10) {
            Button {
                store.selectedCustomRegistryTag = tag
                onShowTagDetail(customTagDetailSelection(for: tag))
                Task { @MainActor in
                    await store.selectCustomRegistryTag(tag)
                    if let selectedCustomRegistryTag = store.selectedCustomRegistryTag,
                       selectedCustomRegistryTag.name == tag.name {
                        onShowTagDetail(customTagDetailSelection(for: selectedCustomRegistryTag))
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tag.name)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                        Text("\(tag.mediaTypeText) · \(tag.platformCountText) platforms")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if store.selectedCustomRegistryTag == tag {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(CDTheme.dockerBlue)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(language.t(.pull)) {
                onPull("\(repositoryReference):\(tag.name)")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(store.selectedCustomRegistryTag == tag ? CDTheme.selectionSurface : Color.clear)
    }

    private func customTagDetailSelection(for tag: RegistryImageTag) -> RegistryTagDetailSelection {
        RegistryTagDetailSelection(
            source: .registryV2,
            title: language.resolved == .zhHans ? "Registry v2 Tag 详情" : "Registry v2 Tag Details",
            repository: repositoryReference,
            tag: tag
        )
    }

    private var paginationControls: some View {
        HStack {
            Button(language.resolved == .zhHans ? "上一页" : "Previous") {
                Task { await store.loadPreviousCustomRegistryPage() }
            }
            .disabled(store.customRegistryCursorStack.isEmpty || store.isLoadingTags)
            Button(language.resolved == .zhHans ? "下一页" : "Next") {
                Task { await store.loadNextCustomRegistryPage() }
            }
            .disabled(store.customRegistryNextCursor == nil || store.isLoadingTags)
            Spacer()
        }
    }
}

private struct RegistryTagDetailDrawer: View {
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
        }
        .drawerSurface(width: 520)
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
                Button(language.t(.pull)) {
                    onPull()
                }
                .buttonStyle(.borderedProminent)
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
