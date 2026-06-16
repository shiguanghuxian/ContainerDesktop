import Foundation
import Testing
@testable import ContainerDesktop

@Suite("System config file")
struct SystemConfigFileTests {
    @Test("uses versioned builder image defaults")
    func usesVersionedBuilderImageDefaults() {
        #expect(SystemConfig().build.image == ContainerBuilderImageDefaults.currentImage)
        #expect(SystemConfig().vminit.image == ContainerVminitImageDefaults.currentImage)
        #expect(FormPresetOptions.builderImages.contains(ContainerBuilderImageDefaults.currentImage))
        #expect(!FormPresetOptions.builderImages.contains(ContainerBuilderImageDefaults.legacyLatestImage))
        #expect(FormPresetOptions.vminitImages.contains(ContainerVminitImageDefaults.currentImage))
        #expect(!FormPresetOptions.vminitImages.contains(ContainerVminitImageDefaults.legacyLatestImage))
        #expect(SystemConfig.defaultFileText.contains(ContainerBuilderImageDefaults.currentImage))
        #expect(SystemConfig.defaultFileText.contains(ContainerVminitImageDefaults.currentImage))
    }

    @Test("saves, reloads, and creates a backup")
    func savesAndBacksUpConfig() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configURL = directory.appending(path: "config.toml")
        let file = SystemConfigFile(url: configURL)

        var config = SystemConfig()
        config.container.cpus = 8
        config.container.memory = "4g"
        config.dns.domain = "test"

        try file.save(config)
        config.container.cpus = 10
        try file.save(config)

        let reloaded = try file.load()
        #expect(reloaded.container.cpus == 10)
        #expect(reloaded.container.memory == "4g")
        #expect(reloaded.dns.domain == "test")
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "config.toml.bak").path))
    }

    @MainActor
    @Test("migrates legacy latest system images on load")
    func migratesLegacyLatestSystemImagesOnLoad() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configURL = directory.appending(path: "config.toml")
        try """
        [build]
        rosetta = true
        cpus = 2
        memory = "2G"
        image = "\(ContainerBuilderImageDefaults.legacyLatestImage)"

        [vminit]
        image = "\(ContainerVminitImageDefaults.legacyLatestImage)"
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let file = SystemConfigFile(url: configURL)
        let store = SystemConfigStore(file: file, client: ContainerCLIClient(runner: CommandRunner(searchRoots: [directory])))

        await store.reload()

        #expect(store.config.build.image == ContainerBuilderImageDefaults.currentImage)
        #expect(store.config.vminit.image == ContainerVminitImageDefaults.currentImage)
        #expect(store.saveMessage?.contains(ContainerBuilderImageDefaults.currentImage) == true)
        #expect(store.saveMessage?.contains(ContainerVminitImageDefaults.currentImage) == true)
        let savedConfig = try file.load()
        #expect(savedConfig.build.image == ContainerBuilderImageDefaults.currentImage)
        #expect(savedConfig.vminit.image == ContainerVminitImageDefaults.currentImage)
        let backupURL = directory.appending(path: "config.toml.bak")
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        let backupText = try String(contentsOf: backupURL, encoding: .utf8)
        #expect(backupText.contains(ContainerBuilderImageDefaults.legacyLatestImage))
        #expect(backupText.contains(ContainerVminitImageDefaults.legacyLatestImage))
    }

    @MainActor
    @Test("keeps custom builder image on load")
    func keepsCustomBuilderImageOnLoad() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configURL = directory.appending(path: "config.toml")
        let customImage = "registry.example.com/container-builder:custom"
        try """
        [build]
        rosetta = true
        cpus = 2
        memory = "2G"
        image = "\(customImage)"

        [vminit]
        image = "registry.example.com/vminit:custom"
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let file = SystemConfigFile(url: configURL)
        let store = SystemConfigStore(file: file, client: ContainerCLIClient(runner: CommandRunner(searchRoots: [directory])))

        await store.reload()

        #expect(store.config.build.image == customImage)
        #expect(store.config.vminit.image == "registry.example.com/vminit:custom")
        #expect(store.saveMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "config.toml.bak").path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
