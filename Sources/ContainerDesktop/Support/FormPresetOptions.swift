import Foundation

struct MachineTemplateBuildRecipe: Hashable, Sendable {
    var reference: String
    var dockerfile: String

    static let ubuntu2404 = MachineTemplateBuildRecipe(
        reference: "local/ubuntu-machine:latest",
        dockerfile: """
        FROM ubuntu:24.04

        ENV container container

        RUN apt-get update && \\
            apt-get install -y \\
            dbus systemd openssh-server net-tools iproute2 iputils-ping curl wget vim-tiny man sudo && \\
            apt-get clean && \\
            rm -rf /var/lib/apt/lists/* && \\
            yes | unminimize

        RUN >/etc/machine-id
        RUN >/var/lib/dbus/machine-id

        RUN systemctl set-default multi-user.target
        RUN systemctl mask \\
              dev-hugepages.mount \\
              sys-fs-fuse-connections.mount \\
              systemd-update-utmp.service \\
              systemd-tmpfiles-setup.service \\
              console-getty.service
        RUN systemctl disable \\
              networkd-dispatcher.service

        RUN sed -i -e 's/^AcceptEnv LANG LC_\\*$/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config
        """
    )

    static let debianBookworm = MachineTemplateBuildRecipe(
        reference: "local/debian-machine:latest",
        dockerfile: """
        FROM debian:bookworm

        ENV container container

        RUN apt-get update && \\
            apt-get install -y \\
            dbus systemd openssh-server net-tools iproute2 iputils-ping curl wget vim-tiny man sudo && \\
            apt-get clean && \\
            rm -rf /var/lib/apt/lists/*

        RUN >/etc/machine-id
        RUN >/var/lib/dbus/machine-id

        RUN systemctl set-default multi-user.target
        RUN systemctl mask \\
              dev-hugepages.mount \\
              sys-fs-fuse-connections.mount \\
              systemd-update-utmp.service \\
              systemd-tmpfiles-setup.service \\
              console-getty.service

        RUN sed -i -e 's/^AcceptEnv LANG LC_\\*$/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config
        """
    )
}

struct MachineImagePreset: Identifiable, Hashable {
    var reference: String
    var titleZH: String
    var titleEN: String
    var descriptionZH: String
    var descriptionEN: String
    var buildRecipe: MachineTemplateBuildRecipe?

    var id: String { reference }
    var requiresLocalBuild: Bool { buildRecipe != nil }

    func title(language: AppLanguage) -> String {
        language.resolved == .zhHans ? titleZH : titleEN
    }

    func description(language: AppLanguage) -> String {
        language.resolved == .zhHans ? descriptionZH : descriptionEN
    }

    func pickerTitle(language: AppLanguage) -> String {
        "\(title(language: language)) · \(reference)"
    }
}

enum FormPresetOptions {
    static let containerImages = [
        "alpine:latest",
        "ubuntu:24.04",
        "debian:bookworm",
        "nginx:latest",
        "redis:latest",
        "postgres:16",
    ]

    static let machineImagePresets = [
        MachineImagePreset(
            reference: "alpine:3.22",
            titleZH: "Alpine 3.22",
            titleEN: "Alpine 3.22",
            descriptionZH: "官方 Quickstart 同类轻量 Linux 镜像，可直接作为 Machine 镜像校验。",
            descriptionEN: "Lightweight Linux image in the same family as the official quickstart; validates directly as a Machine image.",
            buildRecipe: nil
        ),
        MachineImagePreset(
            reference: "alpine:3.21",
            titleZH: "Alpine 3.21",
            titleEN: "Alpine 3.21",
            descriptionZH: "Alpine 稳定版本，适合轻量命令行开发和测试环境。",
            descriptionEN: "Stable Alpine release for lightweight command-line development and testing.",
            buildRecipe: nil
        ),
        MachineImagePreset(
            reference: "alpine:3.20",
            titleZH: "Alpine 3.20",
            titleEN: "Alpine 3.20",
            descriptionZH: "Alpine 旧稳定版本，便于兼容性测试。",
            descriptionEN: "Older stable Alpine release for compatibility testing.",
            buildRecipe: nil
        ),
        MachineImagePreset(
            reference: "alpine:latest",
            titleZH: "Alpine Latest",
            titleEN: "Alpine Latest",
            descriptionZH: "Apple container Machine 文档 Quickstart 使用的默认示例。",
            descriptionEN: "Default example used by the Apple container Machine quickstart.",
            buildRecipe: nil
        ),
        MachineImagePreset(
            reference: "local/ubuntu-machine:latest",
            titleZH: "Ubuntu 24.04 Machine 模板",
            titleEN: "Ubuntu 24.04 Machine Template",
            descriptionZH: "创建时会先按官方 BYO Machine Image 示例自动构建本地 Ubuntu/systemd 镜像。",
            descriptionEN: "Built automatically during create from the official BYO Machine Image Ubuntu/systemd example.",
            buildRecipe: .ubuntu2404
        ),
        MachineImagePreset(
            reference: "local/debian-machine:latest",
            titleZH: "Debian Machine 模板",
            titleEN: "Debian Machine Template",
            descriptionZH: "创建时会先自动构建面向 Debian 目标发行版的本地 systemd Machine 镜像。",
            descriptionEN: "Built automatically during create as a local systemd Machine image for Debian target environments.",
            buildRecipe: .debianBookworm
        ),
    ]

    static var machineImages: [String] {
        machineImagePresets.map(\.reference)
    }

    static func machineImagePreset(reference: String) -> MachineImagePreset? {
        machineImagePresets.first { $0.reference == reference.trimmed }
    }

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
