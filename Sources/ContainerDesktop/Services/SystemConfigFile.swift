import Foundation
import TOMLKit

struct SystemConfigFile {
    let url: URL

    init(url: URL = AppPaths.containerConfigURL) {
        self.url = url
    }

    func load() throws -> SystemConfig {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SystemConfig()
        }
        let toml = try TOMLTable(string: String(contentsOf: url, encoding: .utf8))
        return try TOMLDecoder().decode(SystemConfig.self, from: toml)
    }

    func save(_ config: SystemConfig) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let backupURL = url.deletingLastPathComponent().appendingPathComponent("config.toml.bak")
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: url, to: backupURL)
        }
        let table: TOMLTable = try TOMLEncoder().encode(config)
        let text = table.convert(to: .toml)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
