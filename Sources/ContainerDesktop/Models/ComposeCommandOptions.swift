import Foundation

struct ComposeOperationOptions: Hashable, Sendable {
    var services: [String] = []
    var detach = true
    var buildBeforeUp = false
    var noCache = false
    var interactive = false
    var tty = false
    var user: String?
    var uid: String?
    var gid: String?
    var workdir: String?
    var env: [String] = []
    var envFiles: [String] = []
    var ulimits: [String] = []

    func buildArguments(composePath: URL) -> [String] {
        var arguments = ["build", "-f", composePath.path]
        appendSharedOptions(to: &arguments)
        if noCache { arguments.append("--no-cache") }
        arguments.append(contentsOf: services.map(\.trimmed).filter { !$0.isEmpty })
        return arguments
    }

    func upArguments(composePath: URL) -> [String] {
        var arguments = ["up", "-f", composePath.path]
        appendSharedOptions(to: &arguments)
        if detach { arguments.append("-d") }
        if buildBeforeUp { arguments.append("-b") }
        if noCache { arguments.append("--no-cache") }
        arguments.append(contentsOf: services.map(\.trimmed).filter { !$0.isEmpty })
        return arguments
    }

    func downArguments(composePath: URL) -> [String] {
        var arguments = ["down", "-f", composePath.path]
        appendSharedOptions(to: &arguments)
        arguments.append(contentsOf: services.map(\.trimmed).filter { !$0.isEmpty })
        return arguments
    }

    private func appendSharedOptions(to arguments: inout [String]) {
        if interactive { arguments.append("-i") }
        if tty { arguments.append("-t") }
        arguments.appendOption("-u", user)
        arguments.appendOption("--uid", uid)
        arguments.appendOption("--gid", gid)
        arguments.appendOption("-w", workdir)
        arguments.appendRepeated("-e", env)
        arguments.appendRepeated("--env-file", envFiles)
        arguments.appendRepeated("--ulimit", ulimits)
    }
}
