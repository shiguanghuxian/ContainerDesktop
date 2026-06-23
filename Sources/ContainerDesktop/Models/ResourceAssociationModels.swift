import Foundation

struct ResourceAssociationItem: Identifiable, Hashable, Sendable {
    enum Action: Hashable, Sendable {
        case route(AppResourceRoute)
        case copy(String)
    }

    var id: String
    var title: String
    var subtitle: String
    var systemImage: String
    var action: Action?
}

struct ResourceAssociationSection: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var systemImage: String
    var items: [ResourceAssociationItem]
}

struct ContainerResourceAssociations: Hashable, Sendable {
    var sections: [ResourceAssociationSection]

    static func make(
        container: ContainerSummary,
        inspectText: String,
        images: [ImageSummary],
        volumes: [VolumeSummary],
        networks: [NetworkSummary],
        composeProjects: [ComposeProject],
        browserPortTargets: [ContainerBrowserPortTarget],
        operations: [AppOperationRecord],
        language: AppLanguage
    ) -> ContainerResourceAssociations {
        var sections: [ResourceAssociationSection] = []

        if let image = images.first(where: { $0.reference == container.imageName }) {
            sections.append(ResourceAssociationSection(
                id: "image",
                title: language.resolved == .zhHans ? "关联镜像" : "Image",
                subtitle: image.sizeDisplay,
                systemImage: "photo.stack",
                items: [
                    ResourceAssociationItem(
                        id: "image.\(image.reference)",
                        title: image.reference,
                        subtitle: image.digest,
                        systemImage: "photo.stack",
                        action: .route(.image(reference: image.reference, tab: nil))
                    ),
                ]
            ))
        }

        let composeItems = composeProjects.flatMap { project in
            project.runtimeSummaries(containers: [container]).compactMap { summary -> ResourceAssociationItem? in
                guard summary.containers.contains(where: { $0.id == container.id }) else { return nil }
                return ResourceAssociationItem(
                    id: "compose.\(project.id).\(summary.service.name)",
                    title: "\(project.name) / \(summary.service.name)",
                    subtitle: project.path.path,
                    systemImage: "square.stack.3d.up",
                    action: .route(.composeProject(id: project.id))
                )
            }
        }
        if !composeItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "compose",
                title: "Compose",
                subtitle: language.resolved == .zhHans ? "匹配的项目和服务" : "Matched project and services",
                systemImage: "square.stack.3d.up",
                items: composeItems
            ))
        }

        let inspect = ContainerInspectAssociations.parse(inspectText)
        let volumeItems = inspect.volumeNames.compactMap { name -> ResourceAssociationItem? in
            let volume = volumes.first { $0.name == name }
            return ResourceAssociationItem(
                id: "volume.\(name)",
                title: name,
                subtitle: volume?.source ?? (language.resolved == .zhHans ? "Inspect 挂载项" : "Inspect mount"),
                systemImage: "externaldrive",
                action: volume == nil ? nil : .route(.volume(name: name, tab: nil))
            )
        }
        if !volumeItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "volumes",
                title: language.resolved == .zhHans ? "挂载卷" : "Mounted Volumes",
                subtitle: "\(volumeItems.count)",
                systemImage: "externaldrive",
                items: volumeItems
            ))
        }

        let networkItems = inspect.networkNames.map { name in
            let network = networks.first { $0.name == name }
            return ResourceAssociationItem(
                id: "network.\(name)",
                title: name,
                subtitle: network?.subnetText ?? (language.resolved == .zhHans ? "Inspect 网络" : "Inspect network"),
                systemImage: "network",
                action: network == nil ? nil : .route(.network(name: name, tab: nil))
            )
        }
        if !networkItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "networks",
                title: language.resolved == .zhHans ? "网络" : "Networks",
                subtitle: "\(networkItems.count)",
                systemImage: "network",
                items: networkItems
            ))
        }

        let portItems = browserPortTargets.prefix(8).map { target in
            ResourceAssociationItem(
                id: "port.\(target.id)",
                title: target.title,
                subtitle: target.url?.absoluteString ?? target.copyValue ?? target.endpointText,
                systemImage: target.systemImage,
                action: (target.copyValue ?? target.url?.absoluteString).map { .copy($0) }
            )
        }
        if !portItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "ports",
                title: language.resolved == .zhHans ? "端口连接" : "Port Connections",
                subtitle: language.resolved == .zhHans ? "打开或复制连接信息" : "Open or copy connection details",
                systemImage: "point.3.connected.trianglepath.dotted",
                items: portItems
            ))
        }

        let operationItems = operations
            .filter { $0.target.localizedCaseInsensitiveContains(container.id) || $0.commandPreview.localizedCaseInsensitiveContains(container.id) }
            .prefix(5)
            .map { record in
                ResourceAssociationItem(
                    id: "operation.\(record.id)",
                    title: record.title,
                    subtitle: "\(record.status.title(language: language)) · \(record.durationText)",
                    systemImage: record.status == .failed ? "exclamationmark.triangle" : "clock.arrow.circlepath",
                    action: .copy(record.diagnosticReport(language: language))
                )
            }
        if !operationItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "operations",
                title: language.resolved == .zhHans ? "最近操作" : "Recent Operations",
                subtitle: language.resolved == .zhHans ? "复制诊断摘要" : "Copy diagnostic summary",
                systemImage: "clock.arrow.circlepath",
                items: operationItems
            ))
        }

        return ContainerResourceAssociations(sections: sections)
    }
}

struct ImageResourceAssociations: Hashable, Sendable {
    var sections: [ResourceAssociationSection]

    static func make(
        image: ImageSummary,
        containers: [ContainerSummary],
        operations: [AppOperationRecord],
        language: AppLanguage
    ) -> ImageResourceAssociations {
        var sections: [ResourceAssociationSection] = []
        let usedContainers = containers.filter { $0.imageName == image.reference }
        if !usedContainers.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "containers",
                title: language.resolved == .zhHans ? "正在使用" : "In Use",
                subtitle: "\(usedContainers.count)",
                systemImage: "shippingbox",
                items: usedContainers.map {
                    ResourceAssociationItem(
                        id: "container.\($0.id)",
                        title: $0.id,
                        subtitle: $0.state,
                        systemImage: "shippingbox",
                        action: .route(.container(id: $0.id, tab: nil))
                    )
                }
            ))
        }

        let copyItems = [
            ResourceAssociationItem(
                id: "copy.reference",
                title: language.resolved == .zhHans ? "复制镜像引用" : "Copy image reference",
                subtitle: image.reference,
                systemImage: "doc.on.doc",
                action: .copy(image.reference)
            ),
            ResourceAssociationItem(
                id: "copy.run",
                title: language.resolved == .zhHans ? "复制运行命令" : "Copy run command",
                subtitle: "container run -d \(image.reference)",
                systemImage: "terminal",
                action: .copy(AppOperationCommandPreview.make(executable: "container", arguments: ContainerRunOptions(image: image.reference).arguments))
            ),
        ]
        sections.append(ResourceAssociationSection(
            id: "copy",
            title: language.resolved == .zhHans ? "快捷复制" : "Quick Copy",
            subtitle: language.resolved == .zhHans ? "引用和运行命令" : "Reference and run command",
            systemImage: "doc.on.doc",
            items: copyItems
        ))

        let operationItems = operations
            .filter { $0.target.localizedCaseInsensitiveContains(image.reference) || $0.commandPreview.localizedCaseInsensitiveContains(image.reference) }
            .prefix(5)
            .map { record in
                ResourceAssociationItem(
                    id: "operation.\(record.id)",
                    title: record.title,
                    subtitle: "\(record.status.title(language: language)) · \(record.durationText)",
                    systemImage: record.status == .failed ? "exclamationmark.triangle" : "clock.arrow.circlepath",
                    action: .copy(record.diagnosticReport(language: language))
                )
            }
        if !operationItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "operations",
                title: language.resolved == .zhHans ? "最近镜像任务" : "Recent Image Tasks",
                subtitle: language.resolved == .zhHans ? "复制诊断摘要" : "Copy diagnostic summary",
                systemImage: "clock.arrow.circlepath",
                items: operationItems
            ))
        }

        return ImageResourceAssociations(sections: sections)
    }
}

struct VolumeResourceAssociations: Hashable, Sendable {
    var sections: [ResourceAssociationSection]

    static func make(
        volume: VolumeSummary,
        operations: [AppOperationRecord],
        language: AppLanguage
    ) -> VolumeResourceAssociations {
        var sections = [
            ResourceAssociationSection(
                id: "copy",
                title: language.resolved == .zhHans ? "快捷复制" : "Quick Copy",
                subtitle: language.resolved == .zhHans ? "路径和常用命令" : "Path and common commands",
                systemImage: "doc.on.doc",
                items: [
                    ResourceAssociationItem(
                        id: "open.files",
                        title: language.resolved == .zhHans ? "打开文件" : "Open files",
                        subtitle: language.resolved == .zhHans ? "Files tab · clone / export / import" : "Files tab · clone / export / import",
                        systemImage: "folder",
                        action: .route(.volume(name: volume.name, tab: .files))
                    ),
                    ResourceAssociationItem(
                        id: "copy.source",
                        title: language.resolved == .zhHans ? "复制源目录" : "Copy source path",
                        subtitle: volume.source,
                        systemImage: "folder",
                        action: .copy(volume.source)
                    ),
                    ResourceAssociationItem(
                        id: "copy.inspect",
                        title: language.resolved == .zhHans ? "复制 Inspect 命令" : "Copy inspect command",
                        subtitle: "container volume inspect \(volume.name)",
                        systemImage: "terminal",
                        action: .copy(AppOperationCommandPreview.make(executable: "container", arguments: ["volume", "inspect", volume.name]))
                    ),
                ]
            ),
        ]

        let operationItems = operations
            .filter { $0.target.localizedCaseInsensitiveContains(volume.name) || $0.commandPreview.localizedCaseInsensitiveContains(volume.name) }
            .prefix(5)
            .map { record in
                ResourceAssociationItem(
                    id: "operation.\(record.id)",
                    title: record.title,
                    subtitle: "\(record.status.title(language: language)) · \(record.durationText)",
                    systemImage: record.status == .failed ? "exclamationmark.triangle" : "clock.arrow.circlepath",
                    action: .copy(record.diagnosticReport(language: language))
                )
            }
        if !operationItems.isEmpty {
            sections.append(ResourceAssociationSection(
                id: "operations",
                title: language.resolved == .zhHans ? "最近卷操作" : "Recent Volume Operations",
                subtitle: language.resolved == .zhHans ? "复制诊断摘要" : "Copy diagnostic summary",
                systemImage: "clock.arrow.circlepath",
                items: operationItems
            ))
        }

        return VolumeResourceAssociations(sections: sections)
    }
}

enum ContainerInspectAssociations {
    static func parse(_ inspectText: String) -> (volumeNames: [String], networkNames: [String]) {
        guard let data = inspectText.data(using: .utf8),
              let value = try? JSONDecoder.containerDesktop.decode(JSONValue.self, from: data) else {
            return ([], [])
        }
        let root = firstObject(value)
        let volumeNames = collectVolumeNames(from: root)
        let networkNames = collectNetworkNames(from: root)
        return (volumeNames, networkNames)
    }

    private static func firstObject(_ value: JSONValue) -> [String: JSONValue] {
        switch value {
        case .object(let object):
            return object
        case .array(let values):
            for value in values {
                if case .object(let object) = value {
                    return object
                }
            }
            return [:]
        default:
            return [:]
        }
    }

    private static func collectVolumeNames(from object: [String: JSONValue]) -> [String] {
        var names: [String] = []
        for key in ["Mounts", "mounts"] {
            guard case .array(let mounts)? = object[key] else { continue }
            for mount in mounts {
                guard case .object(let mountObject) = mount else { continue }
                let type = stringValue(mountObject, keys: ["Type", "type"])
                let name = stringValue(mountObject, keys: ["Name", "name", "Source", "source"])
                if type == nil || type?.localizedCaseInsensitiveContains("volume") == true {
                    if let name = name?.nilIfBlank {
                        names.append(lastPathComponentIfNeeded(name))
                    }
                }
            }
        }

        if let configuration = nestedObject(object, keys: ["configuration", "Configuration"]),
           case .array(let values)? = configuration["mounts"] ?? configuration["Mounts"] {
            for value in values {
                guard case .object(let mount) = value else { continue }
                if let source = stringValue(mount, keys: ["source", "Source", "volume", "Volume"])?.nilIfBlank {
                    names.append(lastPathComponentIfNeeded(source))
                }
            }
        }

        return names.uniquedCaseInsensitive()
    }

    private static func collectNetworkNames(from object: [String: JSONValue]) -> [String] {
        var names: [String] = []
        if let networkSettings = nestedObject(object, keys: ["NetworkSettings", "networkSettings", "network_settings"]),
           let networks = nestedObject(networkSettings, keys: ["Networks", "networks"]) {
            names.append(contentsOf: networks.keys)
        }

        if let configuration = nestedObject(object, keys: ["configuration", "Configuration"]),
           case .array(let values)? = configuration["networks"] ?? configuration["Networks"] {
            for value in values {
                if case .string(let name) = value {
                    names.append(name)
                } else if case .object(let network) = value,
                          let name = stringValue(network, keys: ["name", "Name", "network", "Network"]) {
                    names.append(name)
                }
            }
        }

        return names.uniquedCaseInsensitive()
    }

    private static func nestedObject(_ object: [String: JSONValue], keys: [String]) -> [String: JSONValue]? {
        for key in keys {
            if case .object(let nested)? = object[key] {
                return nested
            }
        }
        return nil
    }

    private static func stringValue(_ object: [String: JSONValue], keys: [String]) -> String? {
        for key in keys {
            if case .string(let value)? = object[key] {
                return value
            }
        }
        return nil
    }

    private static func lastPathComponentIfNeeded(_ value: String) -> String {
        if value.contains("/") {
            return URL(fileURLWithPath: value).lastPathComponent
        }
        return value
    }
}

private extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        return filter { value in
            seen.insert(value.lowercased()).inserted
        }
    }
}
