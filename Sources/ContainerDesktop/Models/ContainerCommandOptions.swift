import Foundation

struct ContainerRunOptions: Hashable, Sendable {
    var createOnly = false
    var name: String?
    var image: String
    var command: [String] = []
    var detached = true
    var interactive = false
    var tty = false
    var removeWhenStopped = false
    var readOnlyRoot = false
    var initProcess = false
    var rosetta = false
    var sshAgent = false
    var virtualization = false
    var noDNS = false
    var cpus: String?
    var memory: String?
    var platform: String?
    var os: String?
    var arch: String?
    var user: String?
    var uid: String?
    var gid: String?
    var workdir: String?
    var entrypoint: String?
    var runtime: String?
    var kernel: String?
    var cidfile: String?
    var initImage: String?
    var shmSize: String?
    var dnsDomain: String?
    var scheme: String?
    var progress: String?
    var maxConcurrentDownloads: String?
    var env: [String] = []
    var envFiles: [String] = []
    var labels: [String] = []
    var ports: [String] = []
    var volumes: [String] = []
    var mounts: [String] = []
    var networks: [String] = []
    var publishSockets: [String] = []
    var tmpfs: [String] = []
    var dns: [String] = []
    var dnsSearch: [String] = []
    var dnsOptions: [String] = []
    var capAdd: [String] = []
    var capDrop: [String] = []
    var ulimits: [String] = []

    var arguments: [String] {
        var arguments = [createOnly ? "create" : "run"]
        if detached, !createOnly { arguments.append("-d") }
        if interactive { arguments.append("-i") }
        if tty { arguments.append("-t") }
        if removeWhenStopped { arguments.append("--rm") }
        if readOnlyRoot { arguments.append("--read-only") }
        if initProcess { arguments.append("--init") }
        if rosetta { arguments.append("--rosetta") }
        if sshAgent { arguments.append("--ssh") }
        if virtualization { arguments.append("--virtualization") }
        if noDNS { arguments.append("--no-dns") }

        arguments.appendOption("--name", name)
        arguments.appendOption("-c", cpus)
        arguments.appendOption("-m", memory)
        arguments.appendOption("--platform", platform)
        arguments.appendOption("--os", os)
        arguments.appendOption("-a", arch)
        arguments.appendOption("-u", user)
        arguments.appendOption("--uid", uid)
        arguments.appendOption("--gid", gid)
        arguments.appendOption("-w", workdir)
        arguments.appendOption("--entrypoint", entrypoint)
        arguments.appendOption("--runtime", runtime)
        arguments.appendOption("-k", kernel)
        arguments.appendOption("--cidfile", cidfile)
        arguments.appendOption("--init-image", initImage)
        arguments.appendOption("--shm-size", shmSize)
        arguments.appendOption("--dns-domain", dnsDomain)
        arguments.appendOption("--scheme", scheme)
        arguments.appendOption("--progress", progress)
        arguments.appendOption("--max-concurrent-downloads", maxConcurrentDownloads)

        arguments.appendRepeated("-e", env)
        arguments.appendRepeated("--env-file", envFiles)
        arguments.appendRepeated("-l", labels)
        arguments.appendRepeated("-p", ports)
        arguments.appendRepeated("-v", volumes)
        arguments.appendRepeated("--mount", mounts)
        arguments.appendRepeated("--network", networks)
        arguments.appendRepeated("--publish-socket", publishSockets)
        arguments.appendRepeated("--tmpfs", tmpfs)
        arguments.appendRepeated("--dns", dns)
        arguments.appendRepeated("--dns-search", dnsSearch)
        arguments.appendRepeated("--dns-option", dnsOptions)
        arguments.appendRepeated("--cap-add", capAdd)
        arguments.appendRepeated("--cap-drop", capDrop)
        arguments.appendRepeated("--ulimit", ulimits)

        arguments.append(image.trimmed)
        arguments.append(contentsOf: command)
        return arguments
    }
}

struct ImageBuildOptions: Hashable, Sendable {
    var contextPath: String?
    var dockerfilePath: String?
    var tag: String?
    var cpus: String?
    var memory: String?
    var target: String?
    var output: String?
    var progress: String?
    var noCache = false
    var pull = false
    var quiet = false
    var platforms: [String] = []
    var architectures: [String] = []
    var operatingSystems: [String] = []
    var buildArgs: [String] = []
    var labels: [String] = []
    var secrets: [String] = []
    var dns: [String] = []
    var dnsSearch: [String] = []
    var dnsOptions: [String] = []
    var dnsDomain: String?

    var arguments: [String] {
        var arguments = ["build"]
        if noCache { arguments.append("--no-cache") }
        if pull { arguments.append("--pull") }
        if quiet { arguments.append("-q") }
        arguments.appendOption("-f", dockerfilePath)
        arguments.appendOption("-t", tag)
        arguments.appendOption("-c", cpus)
        arguments.appendOption("-m", memory)
        arguments.appendOption("--target", target)
        arguments.appendOption("-o", output)
        arguments.appendOption("--progress", progress)
        arguments.appendOption("--dns-domain", dnsDomain)
        arguments.appendRepeated("--platform", platforms)
        arguments.appendRepeated("-a", architectures)
        arguments.appendRepeated("--os", operatingSystems)
        arguments.appendRepeated("--build-arg", buildArgs)
        arguments.appendRepeated("-l", labels)
        arguments.appendRepeated("--secret", secrets)
        arguments.appendRepeated("--dns", dns)
        arguments.appendRepeated("--dns-search", dnsSearch)
        arguments.appendRepeated("--dns-option", dnsOptions)
        if let contextPath = contextPath?.nilIfBlank {
            arguments.append(contextPath)
        }
        return arguments
    }
}

struct ImageSaveOptions: Hashable, Sendable {
    var references: [String]
    var outputPath: String?
    var platform: String?
    var os: String?
    var arch: String?

    var arguments: [String] {
        var arguments = ["image", "save"]
        arguments.appendOption("-o", outputPath)
        arguments.appendOption("--platform", platform)
        arguments.appendOption("--os", os)
        arguments.appendOption("-a", arch)
        arguments.append(contentsOf: references.map(\.trimmed).filter { !$0.isEmpty })
        return arguments
    }
}

struct ImageLoadOptions: Hashable, Sendable {
    var inputPath: String?
    var force = false

    var arguments: [String] {
        var arguments = ["image", "load"]
        if force { arguments.append("-f") }
        arguments.appendOption("-i", inputPath)
        return arguments
    }
}

struct ImagePushOptions: Hashable, Sendable {
    var reference: String
    var scheme: String?
    var progress: String?
    var platform: String?
    var os: String?
    var arch: String?

    var arguments: [String] {
        var arguments = ["image", "push"]
        arguments.appendOption("--scheme", scheme)
        arguments.appendOption("--progress", progress)
        arguments.appendOption("--platform", platform)
        arguments.appendOption("--os", os)
        arguments.appendOption("-a", arch)
        arguments.append(reference.trimmed)
        return arguments
    }
}

struct VolumeCreateOptions: Hashable, Sendable {
    var name: String
    var size: String?
    var options: [String] = []
    var labels: [String] = []

    var arguments: [String] {
        var arguments = ["volume", "create"]
        arguments.appendRepeated("--label", labels)
        arguments.appendRepeated("--opt", options)
        arguments.appendOption("-s", size)
        arguments.append(name.trimmed)
        return arguments
    }
}

struct NetworkCreateOptions: Hashable, Sendable {
    var name: String
    var internalOnly = false
    var plugin: String?
    var subnet: String?
    var subnetV6: String?
    var labels: [String] = []
    var options: [String] = []

    var arguments: [String] {
        var arguments = ["network", "create"]
        if internalOnly { arguments.append("--internal") }
        arguments.appendRepeated("--label", labels)
        arguments.appendRepeated("--option", options)
        arguments.appendOption("--plugin", plugin)
        arguments.appendOption("--subnet", subnet)
        arguments.appendOption("--subnet-v6", subnetV6)
        arguments.append(name.trimmed)
        return arguments
    }
}

extension Array where Element == String {
    mutating func appendOption(_ name: String, _ value: String?) {
        guard let value = value?.nilIfBlank else { return }
        append(contentsOf: [name, value])
    }

    mutating func appendRepeated(_ name: String, _ values: [String]) {
        for value in values.map(\.trimmed).filter({ !$0.isEmpty }) {
            append(contentsOf: [name, value])
        }
    }
}
