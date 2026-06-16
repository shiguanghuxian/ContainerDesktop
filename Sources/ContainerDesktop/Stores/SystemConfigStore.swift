import Foundation
import Observation

@MainActor
@Observable
final class SystemConfigStore {
    private let file: SystemConfigFile
    private let client: ContainerCLIClient

    var config = SystemConfig()
    var runtimeProperties: JSONValue?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var saveMessage: String?
    var configPath: String
    var hasLoaded = false

    init(
        file: SystemConfigFile = SystemConfigFile(),
        client: ContainerCLIClient = ContainerCLIClient()
    ) {
        self.file = file
        self.client = client
        self.configPath = file.url.path
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        saveMessage = nil
        defer { isLoading = false }
        do {
            var loadedConfig = try file.load()
            var migrationMessages: [String] = []
            if ContainerBuilderImageDefaults.isLegacyLatestImage(loadedConfig.build.image) {
                loadedConfig.build.image = ContainerBuilderImageDefaults.currentImage
                migrationMessages.append(ContainerBuilderImageDefaults.migrationMessage(configPath: file.url.path))
            }
            if ContainerVminitImageDefaults.isLegacyLatestImage(loadedConfig.vminit.image) {
                loadedConfig.vminit.image = ContainerVminitImageDefaults.currentImage
                migrationMessages.append(ContainerVminitImageDefaults.migrationMessage(configPath: file.url.path))
            }
            if !migrationMessages.isEmpty {
                config = loadedConfig
                do {
                    try file.save(loadedConfig)
                    saveMessage = migrationMessages.joined(separator: "\n")
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                config = loadedConfig
            }
        } catch {
            errorMessage = error.localizedDescription
            config = SystemConfig()
        }
        runtimeProperties = try? await client.systemProperties()
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        saveMessage = nil
        defer { isSaving = false }
        do {
            try file.save(config)
            saveMessage = "已保存到 \(file.url.path)，重启 container system 后生效。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetToDefaults() {
        config = SystemConfig()
        saveMessage = "已恢复默认值，尚未写入文件。"
    }
}
