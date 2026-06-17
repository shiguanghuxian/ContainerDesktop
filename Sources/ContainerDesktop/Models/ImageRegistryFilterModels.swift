import Foundation

enum ImageListDisplayMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    static let defaultsKey = "containerdesktop.images.displayMode"

    case tags
    case repositories

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .tags:
            language.resolved == .zhHans ? "按 Tag" : "By tag"
        case .repositories:
            language.resolved == .zhHans ? "合并" : "Grouped"
        }
    }

    func fullTitle(language: AppLanguage) -> String {
        switch self {
        case .tags:
            language.resolved == .zhHans ? "按 Tag 多行" : "By tag"
        case .repositories:
            language.resolved == .zhHans ? "按仓库合并" : "Grouped by repository"
        }
    }
}

struct ImageReferenceParts: Hashable, Sendable {
    var reference: String
    var registryIdentity: ImageRegistryIdentity
    var repository: String
    var tag: String?
    var digest: String?

    var repositoryKey: String {
        "\(registryIdentity.key)/\(repository.lowercased())"
    }

    var repositoryDisplayName: String {
        if registryIdentity.key == ImageRegistryIdentity.dockerHubKey {
            if repository.hasPrefix("library/") {
                return String(repository.dropFirst("library/".count))
            }
            return "\(registryIdentity.server)/\(repository)"
        }
        return "\(registryIdentity.server)/\(repository)"
    }

    var tagDisplayName: String {
        if let tag, !tag.isEmpty { return tag }
        if let digest, !digest.isEmpty { return digest }
        return "latest"
    }

    static func parse(_ rawReference: String) -> ImageReferenceParts {
        let reference = rawReference.trimmed
        let digestSplit = reference.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let namePart = String(digestSplit.first ?? "")
        let digest = digestSplit.count > 1 ? String(digestSplit[1]).nilIfBlank : nil

        let pathSplit = namePart.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let firstComponent = pathSplit.first.map(String.init) ?? ""
        let hasExplicitRegistry = pathSplit.count > 1 && Self.isExplicitRegistry(firstComponent)
        let registry = hasExplicitRegistry ? firstComponent : ImageRegistryIdentity.dockerHubKey
        let repositoryAndTag: String
        if hasExplicitRegistry {
            repositoryAndTag = pathSplit.count > 1 ? String(pathSplit[1]) : ""
        } else {
            repositoryAndTag = namePart
        }

        let (repositoryName, tag) = splitTag(from: repositoryAndTag)
        let normalizedRepository = normalizedRepositoryName(
            repositoryName.nilIfBlank ?? reference,
            registry: registry
        )
        return ImageReferenceParts(
            reference: reference,
            registryIdentity: ImageRegistryIdentity(server: registry),
            repository: normalizedRepository,
            tag: tag,
            digest: digest
        )
    }

    private static func isExplicitRegistry(_ component: String) -> Bool {
        let lowercased = component.lowercased()
        return lowercased == "localhost"
            || component.contains(".")
            || component.contains(":")
    }

    private static func splitTag(from value: String) -> (repository: String, tag: String?) {
        guard let colonIndex = value.lastIndex(of: ":") else {
            return (value, nil)
        }
        let lastSlashIndex = value.lastIndex(of: "/")
        if let lastSlashIndex, colonIndex < lastSlashIndex {
            return (value, nil)
        }
        let repository = String(value[..<colonIndex])
        let tag = String(value[value.index(after: colonIndex)...]).nilIfBlank
        return (repository, tag)
    }

    private static func normalizedRepositoryName(_ repository: String, registry: String) -> String {
        let trimmedRepository = repository.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let registryIdentity = ImageRegistryIdentity(server: registry)
        if registryIdentity.key == ImageRegistryIdentity.dockerHubKey,
           !trimmedRepository.contains("/") {
            return "library/\(trimmedRepository.lowercased())"
        }
        return trimmedRepository.lowercased()
    }
}

struct ImageRepositoryGroup: Identifiable, Hashable, Sendable {
    var id: String { repositoryKey }
    var repositoryKey: String
    var registryIdentity: ImageRegistryIdentity
    var repository: String
    var displayName: String
    var images: [ImageSummary]

    var references: [String] {
        images.map(\.reference)
    }

    var primaryImage: ImageSummary {
        images.max { lhs, rhs in
            switch (lhs.configuration.creationDate, rhs.configuration.creationDate) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case (nil, nil):
                return lhs.reference.localizedStandardCompare(rhs.reference) == .orderedDescending
            }
        } ?? images[0]
    }

    var tagCount: Int {
        images.count
    }

    var tagSummary: String {
        "\(tagCount) tags"
    }

    var imageIDText: String {
        String(primaryImage.id.prefix(12))
    }

    var createdText: String {
        primaryImage.createdText
    }

    var sizeDisplay: String {
        let bytes = uniqueImagesByDigest.reduce(Int64(0)) { partial, image in
            partial + image.sizeInBytes
        }
        guard bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var searchText: String {
        ([displayName, registryIdentity.displayName, repository] + images.flatMap { image in
            [image.reference, image.digest, image.referenceParts.tagDisplayName]
        })
        .joined(separator: " ")
        .lowercased()
    }

    static func make(images: [ImageSummary]) -> [ImageRepositoryGroup] {
        var orderedKeys: [String] = []
        var groupedImages: [String: [ImageSummary]] = [:]
        var partsByKey: [String: ImageReferenceParts] = [:]

        for image in images {
            let parts = image.referenceParts
            if groupedImages[parts.repositoryKey] == nil {
                orderedKeys.append(parts.repositoryKey)
                partsByKey[parts.repositoryKey] = parts
                groupedImages[parts.repositoryKey] = []
            }
            groupedImages[parts.repositoryKey]?.append(image)
        }

        return orderedKeys.compactMap { key in
            guard let parts = partsByKey[key],
                  let images = groupedImages[key],
                  !images.isEmpty else { return nil }
            return ImageRepositoryGroup(
                repositoryKey: key,
                registryIdentity: parts.registryIdentity,
                repository: parts.repository,
                displayName: parts.repositoryDisplayName,
                images: sortedImages(images)
            )
        }
    }

    private var uniqueImagesByDigest: [ImageSummary] {
        var seen = Set<String>()
        return images.filter { image in
            let digest = image.digest
            guard !seen.contains(digest) else { return false }
            seen.insert(digest)
            return true
        }
    }

    private static func sortedImages(_ images: [ImageSummary]) -> [ImageSummary] {
        images.sorted { lhs, rhs in
            let lhsTag = lhs.referenceParts.tagDisplayName
            let rhsTag = rhs.referenceParts.tagDisplayName
            if lhsTag == "latest", rhsTag != "latest" { return true }
            if rhsTag == "latest", lhsTag != "latest" { return false }
            return lhsTag.localizedStandardCompare(rhsTag) == .orderedAscending
        }
    }
}

enum ImageListEntry: Identifiable, Hashable, Sendable {
    case image(ImageSummary)
    case repository(ImageRepositoryGroup)

    var id: String {
        switch self {
        case .image(let image):
            return "image:\(image.reference)"
        case .repository(let group):
            return "repository:\(group.id)"
        }
    }

    var references: [String] {
        switch self {
        case .image(let image):
            return [image.reference]
        case .repository(let group):
            return group.references
        }
    }

    var primaryImage: ImageSummary {
        switch self {
        case .image(let image):
            return image
        case .repository(let group):
            return group.primaryImage
        }
    }

    var title: String {
        switch self {
        case .image(let image):
            return image.reference
        case .repository(let group):
            return group.displayName
        }
    }

    var tagText: String {
        switch self {
        case .image(let image):
            return image.referenceParts.tagDisplayName
        case .repository(let group):
            return group.tagSummary
        }
    }

    var imageIDText: String {
        switch self {
        case .image(let image):
            return String(image.id.prefix(12))
        case .repository(let group):
            return group.imageIDText
        }
    }

    var createdText: String {
        switch self {
        case .image(let image):
            return image.createdText
        case .repository(let group):
            return group.createdText
        }
    }

    var sizeDisplay: String {
        switch self {
        case .image(let image):
            return image.sizeDisplay
        case .repository(let group):
            return group.sizeDisplay
        }
    }

    var searchText: String {
        switch self {
        case .image(let image):
            return [image.reference, image.digest, image.referenceParts.tagDisplayName]
                .joined(separator: " ")
                .lowercased()
        case .repository(let group):
            return group.searchText
        }
    }

    static func make(images: [ImageSummary], displayMode: ImageListDisplayMode) -> [ImageListEntry] {
        switch displayMode {
        case .tags:
            return images.map { .image($0) }
        case .repositories:
            return ImageRepositoryGroup.make(images: images).map { .repository($0) }
        }
    }
}

struct ImageRegistryIdentity: Identifiable, Hashable, Sendable {
    static let dockerHubKey = "docker.io"

    var id: String { key }
    var key: String
    var server: String
    var displayName: String

    init(server rawServer: String) {
        let normalizedServer = Self.normalizedServer(rawServer)
        if Self.isDockerHubServer(normalizedServer) {
            key = Self.dockerHubKey
            server = Self.dockerHubKey
            displayName = "Docker Hub"
        } else {
            key = normalizedServer.lowercased()
            server = normalizedServer
            displayName = normalizedServer
        }
    }

    static func imageReference(_ reference: String) -> ImageRegistryIdentity {
        ImageReferenceParts.parse(reference).registryIdentity
    }

    private static func normalizedServer(_ rawServer: String) -> String {
        var value = rawServer.trimmed
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("https://") {
            value = String(value.dropFirst("https://".count))
        } else if lowercased.hasPrefix("http://") {
            value = String(value.dropFirst("http://".count))
        }
        value = value.trimmed
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value.trimmed.lowercased()
    }

    private static func isDockerHubServer(_ server: String) -> Bool {
        RegistrySummary(server: server).isDockerHub
    }
}

struct ImageRegistryFilterOption: Identifiable, Hashable, Sendable {
    static let allID = "__all_registries__"

    var identity: ImageRegistryIdentity

    var id: String { identity.key }
    var displayName: String { identity.displayName }
}

enum ImageRegistryFilterOptions {
    static func make(images: [ImageSummary], registries: [RegistrySummary]) -> [ImageRegistryFilterOption] {
        var identitiesByKey: [String: ImageRegistryIdentity] = [:]

        for image in images {
            let identity = image.registryIdentity
            identitiesByKey[identity.key] = identity
        }

        for registry in registries {
            let identity = ImageRegistryIdentity(server: registry.server)
            identitiesByKey[identity.key] = identity
        }

        return identitiesByKey.values
            .sorted { lhs, rhs in
                if lhs.key == ImageRegistryIdentity.dockerHubKey { return true }
                if rhs.key == ImageRegistryIdentity.dockerHubKey { return false }
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            .map { ImageRegistryFilterOption(identity: $0) }
    }
}

extension ImageSummary {
    var referenceParts: ImageReferenceParts {
        ImageReferenceParts.parse(reference)
    }

    var registryIdentity: ImageRegistryIdentity {
        referenceParts.registryIdentity
    }

    var sizeInBytes: Int64 {
        variants.reduce(Int64(0)) { $0 + $1.size }
    }
}
