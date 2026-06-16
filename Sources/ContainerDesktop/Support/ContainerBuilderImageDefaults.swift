import Foundation

enum ContainerBuilderImageDefaults {
    static let repository = "ghcr.io/apple/container-builder-shim/builder"
    static let legacyLatestImage = "\(repository):latest"
    static let currentImage = "\(repository):0.12.0"

    static func isLegacyLatestImage(_ image: String) -> Bool {
        image == legacyLatestImage
    }

    static func isLegacyLatestImageLoosely(_ image: String) -> Bool {
        image.trimmed == legacyLatestImage
    }

    static func appendingLegacyLatestFailureGuidance(to output: String) -> String {
        guard containsLegacyLatestFailure(output) else { return output }
        guard !output.contains(legacyLatestFailureGuidance) else { return output }
        return "\(output)\n\n\(legacyLatestFailureGuidance)"
    }

    static let legacyLatestFailureGuidance =
        "检测到 container 构建器镜像 \(legacyLatestImage) 不存在或无法拉取。\(AppBranding.displayName) 已将推荐构建器镜像更新为 \(currentImage)；请确认 System 设置中的 Builder Image 已更新，必要时重启 container system 后重试 Compose build/up。"

    static func migrationMessage(configPath: String) -> String {
        "已将旧的 Builder Image \(legacyLatestImage) 自动更新为 \(currentImage)，并保存到 \(configPath)。重启 container system 后生效。"
    }

    static func staleConfigurationWarning(language: AppLanguage) -> String {
        if language.resolved == .zhHans {
            return "当前 Builder Image 仍是 \(legacyLatestImage)，带 build: 的 Compose 项目会构建失败。请保存/重新加载 System 设置，将其更新为 \(currentImage)，必要时重启 container system 后重试。"
        }
        return "The current Builder Image is still \(legacyLatestImage). Compose projects with build: can fail to build. Save or reload System settings so it uses \(currentImage), then restart container system if needed."
    }

    private static func containsLegacyLatestFailure(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        let referencesLegacyBuilder = lowercased.contains("ghcr.io/v2/apple/container-builder-shim/builder/manifests/latest")
            || lowercased.contains("\(repository)/manifests/latest")
            || lowercased.contains(legacyLatestImage.lowercased())
            || lowercased.contains("\(repository):latest")
        let reportsMissingManifest = lowercased.contains("404")
            || lowercased.contains("manifest_unknown")
            || lowercased.contains("manifest unknown")
        return referencesLegacyBuilder && reportsMissingManifest
    }
}
