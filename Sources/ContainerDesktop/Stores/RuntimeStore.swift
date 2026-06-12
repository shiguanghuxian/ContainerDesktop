import Foundation
import Observation

@MainActor
@Observable
final class RuntimeStore {
    private let client: ContainerCLIClient

    var environment = EnvironmentProbe(
        macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: "unknown",
        containerAvailable: false,
        containerComposeAvailable: false,
        systemRunning: false,
        systemVersion: nil,
        errorMessage: nil
    )

    var containers: [ContainerSummary] = []
    var images: [ImageSummary] = []
    var volumes: [VolumeSummary] = []
    var networks: [NetworkSummary] = []
    var registries: [RegistrySummary] = []
    var systemVersions: [SystemVersionEntry] = []
    var systemProperties: JSONValue?
    var diskUsage: DiskUsageSummary?
    var selectedInspectorTitle = "Inspect"
    var selectedInspectorText = "选择一个资源查看 JSON 详情。"
    var selectedLogs = ""
    var selectedStats: [ContainerStatsSnapshot] = []
    var selectedStatsText = ""
    var isRefreshing = false
    var busyMessage: String?
    var errorMessage: String?
    var lastUpdated: Date?
    var hasBootstrapped = false

    init(client: ContainerCLIClient = ContainerCLIClient()) {
        self.client = client
    }

    var isReady: Bool {
        environment.containerAvailable && environment.systemRunning
    }

    var menuBarTitle: String {
        isReady ? "ContainerDesktop" : "ContainerDesktop"
    }

    var menuBarIcon: String {
        if !environment.containerAvailable { return "shippingbox.circle" }
        return environment.systemRunning ? "shippingbox.circle.fill" : "shippingbox.circle"
    }

    var statusTitle: String {
        if !environment.containerAvailable { return "container 未安装" }
        if !environment.systemRunning { return "container system 未运行" }
        return "运行中"
    }

    func statusTitle(language: AppLanguage) -> String {
        if !environment.containerAvailable { return language.t(.containerMissing) }
        if !environment.systemRunning { return language.t(.systemNotRunning) }
        return language.t(.running)
    }

    var onboardingIssues: [String] {
        var issues: [String] = []
        if !environment.architecture.contains("arm64") {
            issues.append("当前架构不是 arm64，apple/container 需要 Apple silicon。")
        }
        if !environment.macOSVersion.contains("26") {
            issues.append("建议使用 macOS 26 或更新版本。")
        }
        if !environment.containerAvailable {
            issues.append("未找到 container CLI。")
        }
        if !environment.containerComposeAvailable {
            issues.append("未找到 container-compose CLI。")
        }
        if environment.containerAvailable && !environment.systemRunning {
            issues.append("container system 尚未启动。")
        }
        return issues
    }

    func onboardingIssues(language: AppLanguage) -> [String] {
        var issues: [String] = []
        let isChinese = language.resolved == .zhHans
        if !environment.architecture.contains("arm64") {
            issues.append(isChinese ? "当前架构不是 arm64，apple/container 需要 Apple silicon。" : "The current architecture is not arm64. apple/container requires Apple silicon.")
        }
        if !environment.macOSVersion.contains("26") {
            issues.append(isChinese ? "建议使用 macOS 26 或更新版本。" : "macOS 26 or newer is recommended.")
        }
        if !environment.containerAvailable {
            issues.append(isChinese ? "未找到 container CLI。" : "container CLI was not found.")
        }
        if !environment.containerComposeAvailable {
            issues.append(isChinese ? "未找到 container-compose CLI。" : "container-compose CLI was not found.")
        }
        if environment.containerAvailable && !environment.systemRunning {
            issues.append(isChinese ? "container system 尚未启动。" : "container system is not running.")
        }
        return issues
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await refreshAll()
    }

    func refreshAll() async {
        isRefreshing = true
        errorMessage = nil
        defer {
            isRefreshing = false
            lastUpdated = Date()
        }

        environment = await client.probe()
        guard environment.containerAvailable, environment.systemRunning else {
            containers = []
            images = []
            volumes = []
            networks = []
            registries = []
            systemVersions = []
            systemProperties = nil
            diskUsage = nil
            return
        }

        do {
            systemVersions = try await client.systemVersion()
        } catch {
            errorMessage = error.localizedDescription
        }

        containers = (try? await client.listContainers()) ?? []
        images = (try? await client.listImages()) ?? []
        volumes = (try? await client.listVolumes()) ?? []
        networks = (try? await client.listNetworks()) ?? []
        registries = (try? await client.listRegistries()) ?? []
        systemProperties = try? await client.systemProperties()
        diskUsage = try? await client.systemDF()
    }

    func startSystem() async {
        await perform("启动 container system") {
            try await client.startSystem()
        }
    }

    func stopSystem() async {
        await perform("停止 container system") {
            try await client.stopSystem()
        }
    }

    func startContainer(_ id: String) async {
        await perform("启动容器 \(id)") {
            try await client.startContainer(id)
        }
    }

    func runContainer(name: String?, image: String, commandText: String) async {
        let trimmedImage = image.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedImage.isEmpty else { return }
        let command: [String]
        do {
            command = try CommandLineTokenizer.split(commandText)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await perform("运行容器 \(trimmedImage)") {
            try await client.runContainer(name: name?.nilIfBlank, image: trimmedImage, command: command)
        }
    }

    func stopContainer(_ id: String) async {
        await perform("停止容器 \(id)") {
            try await client.stopContainer(id)
        }
    }

    func deleteContainer(_ id: String) async {
        await perform("删除容器 \(id)") {
            try await client.deleteContainer(id)
        }
    }

    func pullImage(_ reference: String) async {
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await perform("拉取镜像 \(reference)") {
            try await client.pullImage(reference)
        }
    }

    func deleteImage(_ reference: String) async {
        await perform("删除镜像 \(reference)") {
            try await client.deleteImage(reference)
        }
    }

    func createVolume(name: String, size: String?) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedSize = size?.trimmingCharacters(in: .whitespacesAndNewlines)
        await perform("创建存储卷 \(trimmed)") {
            try await client.createVolume(name: trimmed, size: normalizedSize?.isEmpty == true ? nil : normalizedSize)
        }
    }

    func deleteVolume(_ name: String) async {
        await perform("删除存储卷 \(name)") {
            try await client.deleteVolume(name)
        }
    }

    func createNetwork(name: String, subnet: String?, subnetV6: String?, internalOnly: Bool) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await perform("创建网络 \(trimmed)") {
            try await client.createNetwork(
                name: trimmed,
                internalOnly: internalOnly,
                subnet: subnet?.nilIfBlank,
                subnetV6: subnetV6?.nilIfBlank
            )
        }
    }

    func deleteNetwork(_ name: String) async {
        await perform("删除网络 \(name)") {
            try await client.deleteNetwork(name)
        }
    }

    func loginRegistry(server: String, username: String, password: String) async {
        let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty, !trimmedUsername.isEmpty, !password.isEmpty else {
            errorMessage = "仓库地址、用户名和密码不能为空。"
            return
        }
        await perform("登录仓库 \(trimmedServer)") {
            try await client.loginRegistry(server: trimmedServer, username: trimmedUsername, password: password)
        }
    }

    func logoutRegistry(_ registry: String) async {
        await perform("退出登录 \(registry)") {
            try await client.logoutRegistry(registry)
        }
    }

    func inspectContainer(_ id: String) async {
        await inspect(title: "Container \(id)") {
            try await client.inspectContainer(id)
        }
    }

    func inspectImage(_ reference: String) async {
        await inspect(title: "Image \(reference)") {
            try await client.inspectImage(reference)
        }
    }

    func inspectVolume(_ name: String) async {
        await inspect(title: "Volume \(name)") {
            try await client.inspectVolume(name)
        }
    }

    func inspectNetwork(_ name: String) async {
        await inspect(title: "Network \(name)") {
            try await client.inspectNetwork(name)
        }
    }

    func loadContainerLogs(_ id: String, boot: Bool = false) async {
        selectedLogs = "加载日志..."
        do {
            selectedLogs = try await client.containerLogs(id, boot: boot)
        } catch {
            selectedLogs = error.localizedDescription
        }
    }

    func loadContainerStats(_ id: String) async {
        selectedStatsText = "加载 stats..."
        selectedStats = []
        do {
            selectedStats = try await client.containerStats([id])
            selectedStatsText = selectedStats.isEmpty ? "无 stats 数据。" : selectedStats.map {
                "\($0.id): \($0.memoryUsageDisplay) / \($0.memoryLimitDisplay), \($0.networkDisplay)"
            }.joined(separator: "\n")
        } catch {
            selectedStatsText = error.localizedDescription
        }
    }

    private func inspect(title: String, operation: () async throws -> JSONValue) async {
        selectedInspectorTitle = title
        selectedInspectorText = "加载详情..."
        do {
            selectedInspectorText = try await operation().prettyString
        } catch {
            selectedInspectorText = error.localizedDescription
        }
    }

    private func perform(_ message: String, operation: () async throws -> Void) async {
        busyMessage = message
        errorMessage = nil
        defer { busyMessage = nil }
        do {
            try await operation()
            await refreshAll()
        } catch {
            errorMessage = error.localizedDescription
            await refreshAll()
        }
    }
}
