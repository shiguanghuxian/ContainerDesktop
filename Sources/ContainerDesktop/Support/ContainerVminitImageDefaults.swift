import Foundation

enum ContainerVminitImageDefaults {
    static let repository = "ghcr.io/apple/containerization/vminit"
    static let legacyLatestImage = "\(repository):latest"
    static let currentImage = "\(repository):0.33.4"

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
        "检测到 container 运行时 init 镜像 \(legacyLatestImage) 不存在或无法拉取。\(AppBranding.displayName) 已将推荐 vminit 镜像更新为 \(currentImage)；请确认 System 设置中的 vminit Image 已更新，必要时重启 container system 后重试 Compose build/up。"

    static func migrationMessage(configPath: String) -> String {
        "已将旧的 vminit Image \(legacyLatestImage) 自动更新为 \(currentImage)，并保存到 \(configPath)。重启 container system 后生效。"
    }

    static func staleConfigurationWarning(language: AppLanguage) -> String {
        if language.resolved == .zhHans {
            return "当前 vminit Image 仍是 \(legacyLatestImage)，创建容器时可能失败。请保存/重新加载 System 设置，将其更新为 \(currentImage)，必要时重启 container system 后重试。"
        }
        return "The current vminit Image is still \(legacyLatestImage). Container creation can fail. Save or reload System settings so it uses \(currentImage), then restart container system if needed."
    }

    private static func containsLegacyLatestFailure(_ output: String) -> Bool {
        let lowercased = output.lowercased()
        let referencesLegacyVminit = lowercased.contains("ghcr.io/v2/apple/containerization/vminit/manifests/latest")
            || lowercased.contains("\(repository)/manifests/latest")
            || lowercased.contains(legacyLatestImage.lowercased())
            || lowercased.contains("\(repository):latest")
        let reportsMissingManifest = lowercased.contains("404")
            || lowercased.contains("manifest_unknown")
            || lowercased.contains("manifest unknown")
        return referencesLegacyVminit && reportsMissingManifest
    }
}
