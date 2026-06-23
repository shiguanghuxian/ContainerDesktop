import Foundation

@MainActor
enum ExternalTerminalLauncher {
    static func open(
        destination: ExternalTerminalDestination,
        target: TerminalShellTarget
    ) throws {
        switch destination {
        case .systemTerminal:
            try SystemTerminalLauncher.openShell(
                target: target,
                terminalApp: SystemTerminalAppPreference.selectedTerminalApp()
            )
        case .dockerCompatibilityTerminal:
            ContainerDesktopWindowRouter.openDockerCompatibilityTerminal(
                request: DockerCompatibilityTerminalOpenRequest(shellTarget: target)
            )
        }
    }
}
