import Foundation
import Observation

private enum RuntimeStoreOperationError: LocalizedError {
    case machineConfigRestartFailed(id: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .machineConfigRestartFailed(let id, let detail):
            return "Machine \(id) 配置已保存，但自动重启失败。\n\(detail)"
        }
    }
}

@MainActor
@Observable
final class RuntimeStore {
    private let client: ContainerCLIClient
    private let resourceMonitorClient: ResourceMonitorClient
    private let componentVersionChecker: ComponentVersionChecking
    private let maxResourceMonitorSamples = 120

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
    var machines: [MachineSummary] = []
    var images: [ImageSummary] = []
    var volumes: [VolumeSummary] = []
    var networks: [NetworkSummary] = []
    var registries: [RegistrySummary] = []
    var systemVersions: [SystemVersionEntry] = []
    var componentVersions: [ComponentVersionItem] = []
    var systemProperties: JSONValue?
    var diskUsage: DiskUsageSummary?
    var selectedInspectorTitle = "Inspect"
    var selectedInspectorText = "选择一个资源查看 JSON 详情。"
    var selectedLogs = ""
    var selectedStats: [ContainerStatsSnapshot] = []
    var selectedStatsText = ""
    var selectedExecOutput = ""
    var selectedFileContent = ""
    var selectedFilePath = "/"
    var isRefreshing = false
    var busyMessage: String?
    var errorMessage: String?
    var registryStatusMessage: String?
    var registryStatusIsError = false
    var isRegistryOperationRunning = false
    var cleanupStatusMessage: String?
    var cleanupStatusIsError = false
    var isCleanupRunning = false
    var cleanupBeforeDiskUsage: DiskUsageSummary?
    var cleanupAfterDiskUsage: DiskUsageSummary?
    var imageOperationStatusMessage: String?
    var imageOperationStatusIsError = false
    var isImageOperationRunning = false
    var volumeStatusMessage: String?
    var volumeStatusIsError = false
    var isVolumeOperationRunning = false
    var globalLogsText = ""
    var globalStats: [ContainerStatsSnapshot] = []
    var containerResourceSamples: [ContainerResourceSample] = []
    var resourceMonitorSnapshot: EnvironmentResourceSnapshot?
    var resourceMonitorHistory: [EnvironmentResourceSnapshot] = []
    var hostProcessSnapshots: [HostProcessResourceSnapshot] = []
    var isResourceMonitoring = false
    var resourceMonitorErrorMessage: String?
    var isObservabilityRefreshing = false
    var isCheckingComponentVersions = false
    var componentVersionErrorMessage: String?
    var componentVersionsLastCheckedAt: Date?
    var activeOperationKey: String?
    var lastUpdated: Date?
    var hasBootstrapped = false
    @ObservationIgnored private var latestComponentVersionCheck: ComponentLatestVersionCheck?
    @ObservationIgnored private var resourceMonitorTask: Task<Void, Never>?
    @ObservationIgnored private var isResourceMonitorSampling = false

    init(
        client: ContainerCLIClient = ContainerCLIClient(),
        resourceMonitorClient: ResourceMonitorClient? = nil,
        componentVersionChecker: ComponentVersionChecking = ComponentVersionService()
    ) {
        self.client = client
        self.resourceMonitorClient = resourceMonitorClient ?? ResourceMonitorClient(containerClient: client)
        self.componentVersionChecker = componentVersionChecker
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

    func isOperationActive(_ key: String) -> Bool {
        activeOperationKey == key
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
            machines = []
            images = []
            volumes = []
            networks = []
            registries = []
            systemVersions = []
            systemProperties = nil
            diskUsage = nil
            rebuildComponentVersions()
            stopResourceMonitoring()
            return
        }

        do {
            systemVersions = try await client.systemVersion()
        } catch {
            errorMessage = error.localizedDescription
        }

        containers = (try? await client.listContainers()) ?? []
        machines = (try? await client.listMachines()) ?? []
        images = (try? await client.listImages()) ?? []
        volumes = (try? await client.listVolumes()) ?? []
        networks = (try? await client.listNetworks()) ?? []
        await refreshRegistries()
        systemProperties = try? await client.systemProperties()
        diskUsage = try? await client.systemDF()
        rebuildComponentVersions()
    }

    func checkComponentLatestVersions() async {
        guard !isCheckingComponentVersions else { return }
        isCheckingComponentVersions = true
        componentVersionErrorMessage = nil
        defer {
            isCheckingComponentVersions = false
            componentVersionsLastCheckedAt = Date()
        }

        let check = await componentVersionChecker.checkLatestVersions()
        latestComponentVersionCheck = check
        componentVersionErrorMessage = check.errorMessage
        rebuildComponentVersions()
    }

    private func rebuildComponentVersions() {
        componentVersions = ComponentVersionCatalog.makeItems(
            environment: environment,
            systemVersions: systemVersions,
            latestCheck: latestComponentVersionCheck
        )
    }

    func startResourceMonitoring(interval: TimeInterval = 2) {
        guard !isResourceMonitoring else { return }
        guard environment.containerAvailable, environment.systemRunning else { return }
        isResourceMonitoring = true
        resourceMonitorTask = Task { [weak self] in
            await self?.refreshResourceMonitorOnce()
            while !Task.isCancelled {
                let seconds = max(interval, 1)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.refreshResourceMonitorOnce()
            }
        }
    }

    func stopResourceMonitoring() {
        resourceMonitorTask?.cancel()
        resourceMonitorTask = nil
        isResourceMonitoring = false
        isResourceMonitorSampling = false
    }

    func refreshResourceMonitorOnce(containerIDs: [String] = []) async {
        guard environment.containerAvailable, environment.systemRunning else {
            resourceMonitorSnapshot = nil
            containerResourceSamples = []
            hostProcessSnapshots = []
            resourceMonitorErrorMessage = environment.containerAvailable ? "container system 未运行。" : "未找到 container CLI。"
            return
        }
        guard !isResourceMonitorSampling else { return }
        isResourceMonitorSampling = true
        defer { isResourceMonitorSampling = false }

        let selectedIDs = containerIDs.map(\.trimmed).filter { !$0.isEmpty }
        let previousSamples = Dictionary(uniqueKeysWithValues: containerResourceSamples.map { ($0.id, $0) })
        let runningCount = containers.filter { $0.state == "running" }.count

        do {
            let snapshot = try await resourceMonitorClient.sample(
                containerIDs: selectedIDs,
                previousSamples: previousSamples,
                runningContainerCount: runningCount
            )
            containerResourceSamples = snapshot.containerSamples
            hostProcessSnapshots = snapshot.hostProcesses
            resourceMonitorSnapshot = snapshot.environment
            resourceMonitorHistory.append(snapshot.environment)
            if resourceMonitorHistory.count > maxResourceMonitorSamples {
                resourceMonitorHistory.removeFirst(resourceMonitorHistory.count - maxResourceMonitorSamples)
            }
            globalStats = snapshot.containerSamples.map(\.snapshot)
            resourceMonitorErrorMessage = nil
            lastUpdated = snapshot.date
        } catch {
            resourceMonitorErrorMessage = error.localizedDescription
            hostProcessSnapshots = []
        }
    }

    func refreshRegistries(reportSuccess: Bool = false) async {
        let hadRegistryError = registryStatusIsError
        do {
            registries = try await client.listRegistries()
            registryStatusIsError = false
            if reportSuccess {
                registryStatusMessage = "已刷新仓库登录状态。"
            } else if hadRegistryError {
                registryStatusMessage = nil
            }
        } catch {
            registries = []
            registryStatusIsError = true
            registryStatusMessage = "刷新仓库登录状态失败：\(error.localizedDescription)"
            errorMessage = error.localizedDescription
        }
    }

    func startSystem() async {
        await perform("启动 container system", operationKey: RuntimeOperationKey.systemStart) {
            try await client.startSystem()
        }
    }

    func stopSystem() async {
        await perform("停止 container system", operationKey: RuntimeOperationKey.systemStop) {
            try await client.stopSystem()
        }
    }

    func startContainer(_ id: String) async {
        await perform("启动容器 \(id)", operationKey: RuntimeOperationKey.containerStart(id)) {
            try await client.startContainer(id)
        }
    }

    @discardableResult
    func startContainers(_ ids: [String]) async -> (succeeded: Bool, output: String) {
        await performContainerBatch(title: "启动容器", ids: ids) {
            try await client.startContainer($0)
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

    func runContainer(options: ContainerRunOptions) async {
        let trimmedImage = options.image.trimmed
        guard !trimmedImage.isEmpty else {
            errorMessage = "镜像不能为空。"
            return
        }
        var resolvedOptions = options
        resolvedOptions.image = trimmedImage
        await perform(
            options.createOnly ? "创建容器 \(trimmedImage)" : "运行容器 \(trimmedImage)",
            operationKey: RuntimeOperationKey.containerRun
        ) {
            try await client.runContainer(resolvedOptions)
        }
    }

    @discardableResult
    func createMachine(
        name: String?,
        image: String,
        cpus: String?,
        memory: String?,
        homeMount: String?,
        buildRecipe: MachineTemplateBuildRecipe? = nil,
        setDefault: Bool,
        noBoot: Bool
    ) async -> Bool {
        let trimmedImage = image.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedImage.isEmpty else {
            errorMessage = "镜像不能为空。"
            return false
        }
        let resolvedName = name?.nilIfBlank ?? MachineNameGenerator.automaticName(
            for: trimmedImage,
            existingIDs: machines.map(\.id)
        )
        return await perform("创建 Machine \(trimmedImage)", operationKey: RuntimeOperationKey.machineCreate) {
            if let buildRecipe {
                busyMessage = "构建 Machine 模板镜像 \(trimmedImage)"
                _ = try await client.buildMachineTemplate(buildRecipe)
                busyMessage = "校验并创建 Machine \(trimmedImage)"
            }
            try await client.validateMachineImage(reference: trimmedImage)
            try await client.createMachine(
                name: resolvedName,
                image: trimmedImage,
                cpus: cpus?.nilIfBlank,
                memory: memory?.nilIfBlank,
                homeMount: homeMount?.nilIfBlank,
                setDefault: setDefault,
                noBoot: noBoot
            )
        }
    }

    func stopContainer(_ id: String) async {
        await perform("停止容器 \(id)", operationKey: RuntimeOperationKey.containerStop(id)) {
            try await client.stopContainer(id)
        }
    }

    @discardableResult
    func stopContainers(_ ids: [String]) async -> (succeeded: Bool, output: String) {
        await performContainerBatch(title: "停止容器", ids: ids) {
            try await client.stopContainer($0)
        }
    }

    func bootMachine(_ id: String) async {
        await perform(
            "启动 Machine \(id)",
            operationKey: RuntimeOperationKey.machineBoot(id),
            errorMessage: { error in
                await self.machineBootErrorMessage(id: id, error: error)
            }
        ) {
            try await client.bootMachine(id)
        }
    }

    func stopMachine(_ id: String) async {
        await perform("停止 Machine \(id)", operationKey: RuntimeOperationKey.machineStop(id)) {
            try await client.stopMachine(id)
        }
    }

    func deleteContainer(_ id: String) async {
        await perform("删除容器 \(id)", operationKey: RuntimeOperationKey.containerDelete(id)) {
            try await client.deleteContainer(id)
        }
    }

    func deleteMachine(_ id: String) async {
        await perform("删除 Machine \(id)", operationKey: RuntimeOperationKey.machineDelete(id)) {
            try await client.deleteMachine(id)
        }
    }

    func setDefaultMachine(_ id: String) async {
        await perform("设置默认 Machine \(id)", operationKey: RuntimeOperationKey.machineSetDefault(id)) {
            try await client.setDefaultMachine(id)
        }
    }

    func loadMachineInspection(id: String) async throws -> MachineInspection? {
        try await client.inspectMachine(id).details.first
    }

    @discardableResult
    func updateMachineConfig(
        id: String,
        update: MachineConfigurationUpdate,
        restartIfRunning: Bool = false,
        onWillRestart: (() async -> Void)? = nil
    ) async -> Bool {
        guard update.cpus > 0 else {
            errorMessage = "CPU 数量必须大于 0。"
            return false
        }
        let wasRunning = machines.first { $0.id == id }?.isRunning == true
        let shouldRestart = restartIfRunning && wasRunning

        return await perform("保存 Machine \(id) 配置", operationKey: RuntimeOperationKey.machineConfig(id)) {
            busyMessage = "保存 Machine \(id) 配置"
            try await client.setMachineConfig(
                id: id,
                cpus: String(update.cpus),
                memory: update.memory?.nilIfBlank,
                homeMount: update.homeMount.rawValue
            )
            guard shouldRestart else { return }

            await onWillRestart?()
            do {
                busyMessage = "停止 Machine \(id)"
                try await client.stopMachine(id)
                busyMessage = "启动 Machine \(id)"
                try await client.bootMachine(id)
            } catch {
                let base = error.localizedDescription
                let logs = (try? await client.machineLogs(id, lines: 80))?.nilIfBlank
                let detail = logs.map { "\(base)\n\n最近 Machine 日志：\n\($0)" } ?? base
                throw RuntimeStoreOperationError.machineConfigRestartFailed(id: id, detail: detail)
            }
        }
    }

    func pullImage(_ reference: String) async {
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        await perform("拉取镜像 \(reference)", operationKey: RuntimeOperationKey.imagePull) {
            try await client.pullImage(reference)
        }
    }

    func buildImage(_ options: ImageBuildOptions) async {
        await performImageOperation("构建镜像") {
            try await client.buildImage(options)
        }
    }

    func tagImage(source: String, target: String) async {
        let source = source.trimmed
        let target = target.trimmed
        guard !source.isEmpty, !target.isEmpty else {
            imageOperationStatusMessage = "源镜像和目标引用不能为空。"
            imageOperationStatusIsError = true
            return
        }
        await performImageOperation("标记镜像 \(target)") {
            try await client.tagImage(source: source, target: target)
            return "已创建镜像引用 \(target)。"
        }
    }

    func pushImage(_ options: ImagePushOptions) async {
        guard !options.reference.trimmed.isEmpty else {
            imageOperationStatusMessage = "镜像引用不能为空。"
            imageOperationStatusIsError = true
            return
        }
        await performImageOperation("推送镜像 \(options.reference)") {
            try await client.pushImage(options)
        }
    }

    func saveImages(_ options: ImageSaveOptions) async {
        guard !options.references.map(\.trimmed).filter({ !$0.isEmpty }).isEmpty else {
            imageOperationStatusMessage = "请选择要导出的镜像。"
            imageOperationStatusIsError = true
            return
        }
        await performImageOperation("导出镜像") {
            try await client.saveImages(options)
        }
    }

    func loadImage(_ options: ImageLoadOptions) async {
        guard options.inputPath?.nilIfBlank != nil else {
            imageOperationStatusMessage = "请选择要导入的 OCI tar 文件。"
            imageOperationStatusIsError = true
            return
        }
        await performImageOperation("导入镜像") {
            try await client.loadImage(options)
        }
    }

    func deleteImage(_ reference: String) async {
        await perform("删除镜像 \(reference)", operationKey: RuntimeOperationKey.imageDelete(reference)) {
            try await client.deleteImage(reference)
        }
    }

    func pruneDanglingImages() async {
        await performImageOperation("清理 dangling 镜像") {
            try await client.pruneDanglingImages()
        }
    }

    func cleanupCache() async {
        guard !isCleanupRunning else { return }

        isCleanupRunning = true
        busyMessage = "安全清理缓存"
        errorMessage = nil
        cleanupStatusMessage = nil
        cleanupStatusIsError = false
        cleanupBeforeDiskUsage = (try? await client.systemDF()) ?? diskUsage
        cleanupAfterDiskUsage = nil
        defer {
            isCleanupRunning = false
            busyMessage = nil
        }

        do {
            _ = try await client.pruneStoppedContainers()
            _ = try await client.pruneDanglingImages()
            await refreshCleanupResources()
            cleanupAfterDiskUsage = diskUsage
            cleanupStatusMessage = cleanupSuccessMessage(before: cleanupBeforeDiskUsage, after: cleanupAfterDiskUsage)
        } catch {
            cleanupStatusIsError = true
            cleanupStatusMessage = "安全清理失败：\(error.localizedDescription)"
            errorMessage = error.localizedDescription
            await refreshCleanupResources()
            cleanupAfterDiskUsage = diskUsage
        }
    }

    func createVolume(name: String, size: String?) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedSize = size?.trimmingCharacters(in: .whitespacesAndNewlines)
        await perform("创建存储卷 \(trimmed)", operationKey: RuntimeOperationKey.volumeCreate) {
            try await client.createVolume(name: trimmed, size: normalizedSize?.isEmpty == true ? nil : normalizedSize)
        }
    }

    func createVolume(options: VolumeCreateOptions) async {
        let trimmed = options.name.trimmed
        guard !trimmed.isEmpty else {
            volumeStatusMessage = "卷名称不能为空。"
            volumeStatusIsError = true
            return
        }
        var resolved = options
        resolved.name = trimmed
        volumeStatusMessage = nil
        volumeStatusIsError = false
        await perform("创建存储卷 \(trimmed)", operationKey: RuntimeOperationKey.volumeCreate) {
            try await client.createVolume(resolved)
        }
    }

    func cloneVolume(source: VolumeSummary, targetOptions: VolumeCreateOptions) async {
        guard !isVolumeOperationRunning else { return }
        let targetName = targetOptions.name.trimmed
        guard !targetName.isEmpty else {
            volumeStatusMessage = "目标卷名称不能为空。"
            volumeStatusIsError = true
            return
        }
        guard targetName != source.name else {
            volumeStatusMessage = "目标卷名称不能和源卷相同。"
            volumeStatusIsError = true
            return
        }

        var resolved = targetOptions
        resolved.name = targetName
        isVolumeOperationRunning = true
        busyMessage = "克隆存储卷 \(source.name)"
        errorMessage = nil
        volumeStatusMessage = nil
        volumeStatusIsError = false
        var createdTarget = false
        defer {
            isVolumeOperationRunning = false
            busyMessage = nil
        }

        do {
            try await client.createVolume(resolved)
            createdTarget = true
            let latestVolumes = try await client.listVolumes()
            guard let target = latestVolumes.first(where: { $0.name == targetName }) else {
                throw VolumeBrowserError.invalidDestination
            }
            let output = try await VolumeBrowserService().cloneVolume(
                sourcePath: source.source,
                destinationPath: target.source
            )
            volumeStatusMessage = output.nilIfBlank ?? "已克隆卷 \(source.name) 到 \(targetName)。"
            await refreshAll()
        } catch {
            if createdTarget {
                try? await client.deleteVolume(targetName)
            }
            volumeStatusMessage = "克隆卷失败：\(error.localizedDescription)"
            volumeStatusIsError = true
            errorMessage = error.localizedDescription
            await refreshAll()
        }
    }

    func emptyVolume(_ volume: VolumeSummary) async {
        guard !isVolumeOperationRunning else { return }
        isVolumeOperationRunning = true
        busyMessage = "清空存储卷 \(volume.name)"
        errorMessage = nil
        volumeStatusMessage = nil
        volumeStatusIsError = false
        defer {
            isVolumeOperationRunning = false
            busyMessage = nil
        }

        do {
            let output = try await VolumeBrowserService().emptyVolume(sourcePath: volume.source)
            volumeStatusMessage = output.nilIfBlank ?? "已清空卷 \(volume.name)。"
            await refreshAll()
        } catch {
            volumeStatusMessage = "清空卷失败：\(error.localizedDescription)"
            volumeStatusIsError = true
            errorMessage = error.localizedDescription
            await refreshAll()
        }
    }

    func deleteVolume(_ name: String) async {
        await perform("删除存储卷 \(name)", operationKey: RuntimeOperationKey.volumeDelete(name)) {
            try await client.deleteVolume(name)
        }
    }

    func pruneVolumes() async {
        volumeStatusMessage = nil
        volumeStatusIsError = false
        await perform("清理未使用卷", operationKey: RuntimeOperationKey.volumePrune) {
            _ = try await client.pruneVolumes()
        }
        if errorMessage == nil {
            volumeStatusMessage = "已清理未被容器引用的存储卷。"
        } else {
            volumeStatusMessage = errorMessage
            volumeStatusIsError = true
        }
    }

    func createNetwork(name: String, subnet: String?, subnetV6: String?, internalOnly: Bool) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await perform("创建网络 \(trimmed)", operationKey: RuntimeOperationKey.networkCreate) {
            try await client.createNetwork(
                name: trimmed,
                internalOnly: internalOnly,
                subnet: subnet?.nilIfBlank,
                subnetV6: subnetV6?.nilIfBlank
            )
        }
    }

    func deleteNetwork(_ name: String) async {
        await perform("删除网络 \(name)", operationKey: RuntimeOperationKey.networkDelete(name)) {
            try await client.deleteNetwork(name)
        }
    }

    func loginRegistry(server: String, username: String, password: String) async {
        let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedServer.isEmpty, !trimmedUsername.isEmpty, !password.isEmpty else {
            let message = "仓库地址、用户名和密码不能为空。"
            registryStatusMessage = message
            registryStatusIsError = true
            errorMessage = message
            return
        }

        isRegistryOperationRunning = true
        busyMessage = "登录仓库 \(trimmedServer)"
        errorMessage = nil
        registryStatusMessage = nil
        registryStatusIsError = false
        defer {
            isRegistryOperationRunning = false
            busyMessage = nil
        }

        do {
            try await client.loginRegistry(server: trimmedServer, username: trimmedUsername, password: password)
            await refreshRegistries()
            if !registryStatusIsError {
                registryStatusMessage = "已登录仓库 \(registryDisplayName(for: trimmedServer))。"
            }
        } catch {
            registryStatusMessage = "登录仓库失败：\(error.localizedDescription)"
            registryStatusIsError = true
            errorMessage = error.localizedDescription
        }
    }

    func logoutRegistry(_ registry: String) async {
        isRegistryOperationRunning = true
        busyMessage = "退出登录 \(registry)"
        errorMessage = nil
        registryStatusMessage = nil
        registryStatusIsError = false
        defer {
            isRegistryOperationRunning = false
            busyMessage = nil
        }

        do {
            try await client.logoutRegistry(registry)
            await refreshRegistries()
            if !registryStatusIsError {
                registryStatusMessage = "已退出仓库 \(registryDisplayName(for: registry))。"
            }
        } catch {
            registryStatusMessage = "退出仓库登录失败：\(error.localizedDescription)"
            registryStatusIsError = true
            errorMessage = error.localizedDescription
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

    @discardableResult
    private func perform(
        _ message: String,
        operationKey: String? = nil,
        errorMessage resolvedErrorMessage: ((Error) async -> String)? = nil,
        operation: () async throws -> Void
    ) async -> Bool {
        if let operationKey {
            guard activeOperationKey == nil else { return false }
            activeOperationKey = operationKey
        }
        busyMessage = message
        errorMessage = nil
        defer {
            busyMessage = nil
            if let operationKey, activeOperationKey == operationKey {
                activeOperationKey = nil
            }
        }
        do {
            try await operation()
            await refreshAll()
            return true
        } catch {
            let resolvedMessage: String
            if let resolvedErrorMessage {
                resolvedMessage = await resolvedErrorMessage(error)
            } else {
                resolvedMessage = error.localizedDescription
            }
            await refreshAll()
            errorMessage = resolvedMessage
            return false
        }
    }

    private func machineBootErrorMessage(id: String, error: Error) async -> String {
        let base = error.localizedDescription
        let logs = (try? await client.machineLogs(id, lines: 80)) ?? ""
        if logs.contains("/sbin/init: not found") {
            return """
            Machine \(id) 无法启动：所选镜像缺少 /sbin/init，不能作为持久 Machine 根文件系统启动。
            请使用包含 init 的镜像重新创建，推荐先用 alpine:3.22。原始错误：\(base)
            """
        }
        guard let logs = logs.nilIfBlank else { return base }
        return "\(base)\n\n最近 Machine 日志：\n\(logs)"
    }

    private func registryDisplayName(for server: String) -> String {
        RegistrySummary(server: server).displayName
    }

    private func refreshCleanupResources() async {
        if let latestContainers = try? await client.listContainers() {
            containers = latestContainers
        }
        if let latestImages = try? await client.listImages() {
            images = latestImages
        }
        if let latestDiskUsage = try? await client.systemDF() {
            diskUsage = latestDiskUsage
        }
        lastUpdated = Date()
    }

    private func cleanupSuccessMessage(before: DiskUsageSummary?, after: DiskUsageSummary?) -> String {
        guard let before, let after else {
            return "安全清理完成，已刷新本地资源。"
        }

        let reclaimed = max(before.totalSizeInBytes - after.totalSizeInBytes, 0)
        let reclaimedText = ByteCountFormatter.string(fromByteCount: reclaimed, countStyle: .file)
        return "安全清理完成，释放约 \(reclaimedText)。可回收空间从 \(before.reclaimableDisplay) 更新为 \(after.reclaimableDisplay)。"
    }

    func restartContainer(_ id: String) async {
        await stopContainer(id)
        await startContainer(id)
    }

    @discardableResult
    func restartContainers(_ ids: [String]) async -> (succeeded: Bool, output: String) {
        await performContainerBatch(title: "重启容器", ids: ids) {
            try await client.restartContainer($0)
        }
    }

    func execContainerCommand(id: String, command: String) async {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            selectedExecOutput = "请填写要执行的命令。"
            return
        }
        selectedExecOutput = "执行命令..."
        do {
            selectedExecOutput = try await client.execContainer(id: id, command: trimmed)
        } catch {
            selectedExecOutput = error.localizedDescription
        }
    }

    func readContainerFile(id: String, path: String) async {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            selectedFileContent = "请填写要读取的文件路径。"
            return
        }
        selectedFilePath = trimmed
        selectedFileContent = "读取文件..."
        do {
            selectedFileContent = try await client.containerFileContent(id: id, path: trimmed)
        } catch {
            selectedFileContent = error.localizedDescription
        }
    }

    func exportContainer(id: String, outputPath: String?) async {
        guard !id.trimmed.isEmpty else { return }
        await performImageOperation("导出容器文件系统 \(id)") {
            try await client.exportContainer(id: id, outputPath: outputPath)
        }
    }

    func refreshGlobalObservability(
        containerIDs: [String] = [],
        lines: Int = 120,
        logSource: ObservabilityLogSource = .containerStdio,
        systemLogLast: String = "5m"
    ) async {
        guard !isObservabilityRefreshing else { return }
        isObservabilityRefreshing = true
        errorMessage = nil
        globalLogsText = "加载日志..."
        globalStats = []
        defer {
            isObservabilityRefreshing = false
            lastUpdated = Date()
        }

        let selectedIDs = Set(containerIDs.map(\.trimmed).filter { !$0.isEmpty })
        let selectedContainers = selectedIDs.isEmpty
            ? containers
            : containers.filter { selectedIDs.contains($0.id) }

        if logSource != .system, selectedContainers.isEmpty {
            globalLogsText = "没有可观测的容器。"
            return
        }

        let ids = selectedContainers.map(\.id)
        do {
            globalStats = try await client.containerStats(ids)
        } catch {
            globalStats = []
        }

        if logSource == .system {
            do {
                globalLogsText = try await client.systemLogs(last: systemLogLast)
            } catch {
                globalLogsText = error.localizedDescription
            }
            return
        }

        var sections: [String] = []
        for container in selectedContainers.prefix(24) {
            do {
                let logs = try await client.containerLogs(container.id, boot: logSource == .containerBoot, lines: lines)
                sections.append("[\(container.id)] \(container.imageName)\n\(logs)")
            } catch {
                sections.append("[\(container.id)] \(container.imageName)\n\(error.localizedDescription)")
            }
        }
        globalLogsText = sections.joined(separator: "\n\n")
    }

    private func performImageOperation(_ message: String, operation: () async throws -> String) async {
        guard !isImageOperationRunning else { return }
        isImageOperationRunning = true
        busyMessage = message
        errorMessage = nil
        imageOperationStatusMessage = nil
        imageOperationStatusIsError = false
        defer {
            isImageOperationRunning = false
            busyMessage = nil
        }

        do {
            let output = try await operation()
            imageOperationStatusMessage = output.nilIfBlank ?? "\(message)完成。"
            await refreshAll()
        } catch {
            imageOperationStatusIsError = true
            imageOperationStatusMessage = error.localizedDescription
            errorMessage = error.localizedDescription
            await refreshAll()
        }
    }

    private func performContainerBatch(
        title: String,
        ids: [String],
        operation: (String) async throws -> Void
    ) async -> (succeeded: Bool, output: String) {
        let resolvedIDs = ids.map(\.trimmed).filter { !$0.isEmpty }
        guard !resolvedIDs.isEmpty else {
            let message = "没有可操作的容器。"
            errorMessage = message
            return (false, message)
        }

        busyMessage = "\(title) \(resolvedIDs.count) 个"
        errorMessage = nil
        defer { busyMessage = nil }

        do {
            for id in resolvedIDs {
                try await operation(id)
            }
            await refreshAll()
            return (true, "\(title)完成：\(resolvedIDs.joined(separator: ", "))")
        } catch {
            let output = "\(title)失败：\(error.localizedDescription)"
            await refreshAll()
            errorMessage = error.localizedDescription
            return (false, output)
        }
    }
}
