import Foundation
import Yams

enum ComposeParser {
    static func parse(fileURL: URL) throws -> ComposeProject {
        let data = try Data(contentsOf: fileURL)
        let yaml = String(decoding: data, as: UTF8.self)
        guard let root = try Yams.load(yaml: yaml) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let services = parseServices(root["services"] as? [String: Any] ?? [:])
        let volumes = Array((root["volumes"] as? [String: Any] ?? [:]).keys).sorted()
        let networks = Array((root["networks"] as? [String: Any] ?? [:]).keys).sorted()
        let name = (root["name"] as? String)?.nilIfBlank
            ?? fileURL.deletingLastPathComponent().lastPathComponent.nilIfBlank
            ?? fileURL.deletingPathExtension().lastPathComponent
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let modified = (attributes[.modificationDate] as? Date) ?? Date()

        return ComposeProject(
            path: fileURL,
            name: name,
            services: services,
            volumes: volumes,
            networks: networks,
            lastModified: modified
        )
    }

    private static func parseServices(_ raw: [String: Any]) -> [ComposeProject.Service] {
        raw.sorted(by: { $0.key < $1.key }).compactMap { name, value in
            guard let service = value as? [String: Any] else { return nil }
            let image = service["image"] as? String
            let buildContext: String?
            if let build = service["build"] as? [String: Any] {
                buildContext = build["context"] as? String
            } else if let build = service["build"] as? String {
                buildContext = build
            } else {
                buildContext = nil
            }

            return ComposeProject.Service(
                name: name,
                image: image,
                containerName: (service["container_name"] as? String)?.nilIfBlank,
                buildContext: buildContext,
                command: parseStringArray(service["command"]),
                ports: parseStringArray(service["ports"]),
                volumes: parseStringArray(service["volumes"]),
                dependsOn: parseDependsOn(service["depends_on"]),
                environment: parseEnvironment(service["environment"]),
                networks: parseStringArray(service["networks"]),
                platform: service["platform"] as? String
            )
        }
    }

    private static func parseStringArray(_ value: Any?) -> [String] {
        if let values = value as? [String] {
            return values
        }
        if let value = value as? String {
            return [value]
        }
        if let values = value as? [Any] {
            return values.compactMap { $0 as? String }
        }
        return []
    }

    private static func parseDependsOn(_ value: Any?) -> [String] {
        if let values = value as? [String] {
            return values
        }
        if let mapping = value as? [String: Any] {
            return Array(mapping.keys).sorted()
        }
        if let value = value as? String {
            return [value]
        }
        return []
    }

    private static func parseEnvironment(_ value: Any?) -> [String: String] {
        if let mapping = value as? [String: String] {
            return mapping
        }
        if let mapping = value as? [String: Any] {
            var result: [String: String] = [:]
            for (key, value) in mapping {
                result[key] = "\(value)"
            }
            return result
        }
        if let values = value as? [String] {
            var result: [String: String] = [:]
            for item in values {
                guard let index = item.firstIndex(of: "=") else { continue }
                let key = String(item[..<index])
                let val = String(item[item.index(after: index)...])
                result[key] = val
            }
            return result
        }
        return [:]
    }
}
