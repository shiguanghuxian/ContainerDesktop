import Foundation
import Testing
@testable import ContainerDesktop

@Suite("System config file")
struct SystemConfigFileTests {
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
}
