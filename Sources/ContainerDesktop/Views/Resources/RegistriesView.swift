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

    private var filteredRegistries: [RegistrySummary] {
        let query = searchText.trimmed.lowercased()
        guard !query.isEmpty else { return runtimeStore.registries }
        return runtimeStore.registries.filter { $0.server.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.registries),
                subtitle: language.t(.registriesSubtitle),
                systemImage: "key.icloud"
            ) {
                HStack(spacing: 8) {
                    Button {
                        showLoginPopover = true
                    } label: {
                        Label(language.resolved == .zhHans ? "登录仓库" : "Login", systemImage: "person.badge.key")
                    }
                    .buttonStyle(.borderedProminent)
                    .popover(isPresented: $showLoginPopover, arrowEdge: .bottom) {
                        loginForm
                    }

                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Text(language.itemCount(filteredRegistries.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 16) {
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

                                Text(registry.server)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                StatusPill(title: "logged in", systemImage: "checkmark.seal", tint: CDTheme.lime)
                                    .frame(width: 120, alignment: .leading)

                                HStack(spacing: 8) {
                                    DestructiveRowActionButton(systemImage: "rectangle.portrait.and.arrow.right") {
                                        pendingLogout = registry
                                    }
                                }
                                .frame(width: 78, alignment: .trailing)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                PanelView(title: language.t(.loginInstructions), subtitle: "macOS Keychain", systemImage: "lock.shield") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(language.resolved == .zhHans ? "登录信息由 container CLI 写入 macOS 钥匙串，ContainerDesktop 不保存密码。" : "Credentials are written by the container CLI to macOS Keychain. ContainerDesktop does not persist the password.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        TerminalBlock(text: "container registry login --password-stdin --username <user> <server>\ncontainer registry logout <server>", minHeight: 120)
                    }
                }
                .frame(width: 380)
            }
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

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.resolved == .zhHans ? "登录镜像仓库" : "Login to Registry")
                .font(.headline)

            TextField("docker.io", text: $loginServer)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            TextField(language.resolved == .zhHans ? "用户名" : "Username", text: $loginUsername)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            SecureField(language.resolved == .zhHans ? "密码或 Token" : "Password or token", text: $loginPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            HStack {
                Spacer()
                Button("取消") {
                    showLoginPopover = false
                    loginPassword = ""
                }
                Button(language.resolved == .zhHans ? "登录" : "Login") {
                    let server = loginServer
                    let username = loginUsername
                    let password = loginPassword
                    loginPassword = ""
                    showLoginPopover = false
                    Task {
                        await runtimeStore.loginRegistry(server: server, username: username, password: password)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
    }

    private var registryHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: "Server")
            ResourceTableHeaderLabel(title: language.t(.status), width: 120)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 78, alignment: .trailing)
        }
    }
}
