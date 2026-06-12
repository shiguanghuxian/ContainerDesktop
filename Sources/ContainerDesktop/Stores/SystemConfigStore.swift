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
        defer { isLoading = false }
        do {
            config = try file.load()
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
