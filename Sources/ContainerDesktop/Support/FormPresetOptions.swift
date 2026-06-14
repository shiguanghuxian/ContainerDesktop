import Foundation

enum FormPresetOptions {
    static let containerImages = [
        "alpine:latest",
        "ubuntu:24.04",
        "debian:bookworm",
        "nginx:latest",
        "redis:latest",
        "postgres:16",
    ]

    static let machineImages = [
        "alpine:3.22",
        "alpine:3.21",
        "alpine:3.20",
        "alpine:latest",
    ]

    static let builderImages = [
        "ghcr.io/apple/container-builder-shim/builder:latest",
    ]

    static let vminitImages = [
        "ghcr.io/apple/containerization/vminit:latest",
    ]

    static let registries = [
        "docker.io",
        "ghcr.io",
        "quay.io",
        "registry.k8s.io",
    ]

    static let volumeSizes = [
        "1G",
        "5G",
        "10G",
        "20G",
        "50G",
        "100G",
    ]

    static let memorySizes = [
        "512M",
        "1G",
        "2G",
        "4G",
        "8G",
        "16G",
        "32G",
        "64G",
    ]

    static let machineMemorySizes = [
        "1G",
        "2G",
        "4G",
        "8G",
        "16G",
        "32G",
        "64G",
    ]

    static func imageChoices(current: String, localImages: [ImageSummary], suggestions: [String]) -> [String] {
        unique([current] + localImages.map(\.reference) + suggestions)
    }

    static func choices(current: String, suggestions: [String]) -> [String] {
        unique([current] + suggestions)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let trimmed = value.trimmed
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
            seen.insert(trimmed)
            return trimmed
        }
    }
}
