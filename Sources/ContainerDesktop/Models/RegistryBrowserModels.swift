import Foundation

enum RegistryTagDetailSource: String, Hashable, Sendable {
    case dockerHub
    case registryV2
}

struct RegistryTagDetailSelection: Identifiable, Hashable, Sendable {
    var source: RegistryTagDetailSource
    var title: String
    var repository: String
    var tag: RegistryImageTag

    var id: String {
        "\(source.rawValue):\(repository):\(tag.name)"
    }

    var reference: String {
        "\(repository):\(tag.name)"
    }

    var isRegistryV2: Bool {
        source == .registryV2
    }
}

extension RegistrySummary {
    var isDockerHubRegistry: Bool {
        isDockerHub
    }

    var registryBrowseServer: String {
        isDockerHubRegistry ? "registry-1.docker.io" : server.trimmed
    }
}

struct RegistryRepositoryResult: Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var description: String
    var stars: Int
    var pulls: Int
    var isOfficial: Bool

    var displayName: String {
        isOfficial && name.hasPrefix("library/") ? String(name.dropFirst("library/".count)) : name
    }

    var pullReference: String {
        isOfficial && name.hasPrefix("library/") ? String(name.dropFirst("library/".count)) : name
    }

    var pullsDisplay: String {
        pulls.formatted(.number.notation(.compactName))
    }
}

struct RegistryPage<Element: Hashable & Sendable>: Hashable, Sendable {
    var items: [Element]
    var totalCount: Int?
    var nextCursor: String?
    var previousCursor: String?
    var page: Int

    var hasNext: Bool { nextCursor != nil }
    var hasPrevious: Bool { previousCursor != nil || page > 1 }
}

struct RegistryImageTag: Identifiable, Hashable, Sendable {
    var id: String { name }
    var name: String
    var size: Int64?
    var updatedAt: Date?
    var digest: String?
    var mediaType: String?
    var platforms: [String]

    var sizeDisplay: String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var updatedText: String {
        guard let updatedAt else { return "—" }
        return updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var platformsText: String {
        platforms.isEmpty ? "—" : platforms.joined(separator: ", ")
    }

    var digestText: String {
        digest?.nilIfBlank ?? "—"
    }

    var mediaTypeText: String {
        RegistryManifestDetails.displayName(for: mediaType) ?? "—"
    }

    var platformCountText: String {
        platforms.isEmpty ? "—" : "\(platforms.count)"
    }

    func enriched(with details: RegistryManifestDetails) -> RegistryImageTag {
        RegistryImageTag(
            name: name,
            size: size ?? details.size,
            updatedAt: updatedAt,
            digest: details.digest?.nilIfBlank ?? digest,
            mediaType: details.mediaType?.nilIfBlank ?? mediaType,
            platforms: details.platforms.isEmpty ? platforms : details.platforms
        )
    }
}

struct RegistryBrowseCredentials: Hashable, Sendable {
    var username: String
    var password: String

    var isUsable: Bool {
        !username.trimmed.isEmpty && !password.isEmpty
    }

    var basicAuthorizationHeader: String? {
        guard isUsable else { return nil }
        let value = "\(username.trimmed):\(password)"
        guard let data = value.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }
}

struct RegistryManifestDetails: Hashable, Sendable {
    static let acceptedMediaTypes = [
        "application/vnd.oci.image.index.v1+json",
        "application/vnd.oci.image.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.list.v2+json",
        "application/vnd.docker.distribution.manifest.v2+json",
        "application/vnd.docker.distribution.manifest.v1+json",
        "application/vnd.docker.distribution.manifest.v1+prettyjws",
    ]

    var digest: String?
    var mediaType: String?
    var platforms: [String]
    var size: Int64?

    static func parse(data: Data, contentDigest: String?, contentType: String?) throws -> RegistryManifestDetails {
        let document = try JSONDecoder.containerDesktop.decode(RegistryManifestDocument.self, from: data)
        let resolvedMediaType = document.mediaType?.nilIfBlank ?? normalizedContentType(contentType)
        return RegistryManifestDetails(
            digest: contentDigest?.nilIfBlank,
            mediaType: resolvedMediaType,
            platforms: document.platforms,
            size: document.totalSize
        )
    }

    static func displayName(for mediaType: String?) -> String? {
        guard let mediaType = mediaType?.nilIfBlank else { return nil }
        switch mediaType {
        case "application/vnd.oci.image.index.v1+json":
            return "OCI index"
        case "application/vnd.oci.image.manifest.v1+json":
            return "OCI image"
        case "application/vnd.docker.distribution.manifest.list.v2+json":
            return "Docker manifest list"
        case "application/vnd.docker.distribution.manifest.v2+json":
            return "Docker image"
        case "application/vnd.docker.distribution.manifest.v1+json",
             "application/vnd.docker.distribution.manifest.v1+prettyjws":
            return "Docker schema v1"
        default:
            return mediaType
        }
    }

    private static func normalizedContentType(_ contentType: String?) -> String? {
        contentType?
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmed
            .nilIfBlank
    }
}

private struct RegistryManifestDocument: Decodable, Sendable {
    var schemaVersion: Int?
    var mediaType: String?
    var manifests: [RegistryManifestDescriptor]?
    var config: RegistryManifestDescriptor?
    var layers: [RegistryManifestDescriptor]?

    var platforms: [String] {
        let values = manifests?.compactMap(\.platform?.displayText) ?? []
        return Array(Set(values)).sorted()
    }

    var totalSize: Int64? {
        let sizes = ([config].compactMap { $0?.size } + (layers ?? []).compactMap(\.size))
        guard !sizes.isEmpty else { return nil }
        return sizes.reduce(0, +)
    }
}

private struct RegistryManifestDescriptor: Decodable, Sendable {
    var mediaType: String?
    var digest: String?
    var size: Int64?
    var platform: RegistryManifestPlatform?
}

private struct RegistryManifestPlatform: Decodable, Sendable {
    var architecture: String?
    var os: String?
    var variant: String?

    var displayText: String? {
        let parts = [os, architecture, variant].compactMap { $0?.nilIfBlank }
        return parts.isEmpty ? nil : parts.joined(separator: "/")
    }
}
