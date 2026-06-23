import AppKit
import Foundation

enum SystemTerminalLauncher {
    enum LaunchError: LocalizedError {
        case selectedTerminalUnavailable(String)
        case defaultTerminalOpenFailed(URL)

        var errorDescription: String? {
            switch self {
            case .selectedTerminalUnavailable(let terminalName):
                "The selected terminal app is not available: \(terminalName)"
            case .defaultTerminalOpenFailed(let scriptURL):
                "Could not open terminal script: \(scriptURL.path)"
            }
        }
    }

    static func openDependencyInstallScript(targets: [DependencyInstallTarget]) throws {
        let uniqueTargets = DependencyInstallTarget.allCases.filter { targets.contains($0) }
        guard !uniqueTargets.isEmpty else { return }

        try openCommandScript(
            fileName: "containerdesktop-install-dependencies.command",
            body: dependencyInstallScript(targets: uniqueTargets)
        )
    }

    static func openContainerShell(id: String) throws {
        try openShell(target: .container(id: id))
    }

    static func openMachineShell(id: String) throws {
        try openShell(target: .machine(id: id))
    }

    static func openDockerCompatibilityShell(
        workingDirectory: URL = AppPaths.homeDirectory,
        terminalApp: SystemTerminalApp? = nil
    ) throws {
        let environment = try DockerCompatibilityTerminalService().prepareEnvironment()
        try openCommandScript(
            fileName: "containerdesktop-docker-compatible-terminal.command",
            body: dockerCompatibilityShellScript(workingDirectory: workingDirectory, environment: environment),
            terminalApp: terminalApp
        )
    }

    static func openShell(target: TerminalShellTarget, terminalApp: SystemTerminalApp? = nil) throws {
        try openCommandScript(
            fileName: target.systemTerminalScriptFileName,
            body: """
            #!/bin/zsh
            clear
            printf '%s\\n\\n' \(ShellEscaper.singleQuoted(target.systemTerminalWindowTitle))
            if ! command -v container >/dev/null 2>&1; then
              echo "container CLI was not found in this terminal session."
              echo "Press Return to close."
              read
              exit 127
            fi
            exec \(target.containerCLIArguments.map(ShellEscaper.singleQuoted).joined(separator: " "))
            """,
            terminalApp: terminalApp
        )
    }

    static func dockerCompatibilityShellScript(
        workingDirectory: URL,
        environment: DockerCompatibilityTerminalEnvironment
    ) -> String {
        """
        #!/bin/zsh
        clear
        set -u

        session_zdotdir="$(mktemp -d /tmp/containerdesktop-docker-zdotdir.XXXXXX)"
        cat > "$session_zdotdir/.zshrc" <<'CONTAINERDESKTOP_ZSHRC'
        if [ -r "$HOME/.zshrc" ]; then
          source "$HOME/.zshrc"
        fi

        export CONTAINERDESKTOP_DOCKER_SHIM_BIN=\(ShellEscaper.singleQuoted(environment.shimBinDirectory.path))
        case ":$PATH:" in
          *":$CONTAINERDESKTOP_DOCKER_SHIM_BIN:"*) ;;
          *) export PATH="$CONTAINERDESKTOP_DOCKER_SHIM_BIN:$PATH" ;;
        esac
        export DOCKER_CLI_HINTS=false

        printf '\\033[1;36m%s\\033[0m\\n' "\(AppBranding.displayName) Docker-compatible system terminal"
        printf 'docker/docker-compose -> container/container-compose\\n'
        printf 'shim: %s\\n\\n' "$CONTAINERDESKTOP_DOCKER_SHIM_BIN"
        CONTAINERDESKTOP_ZSHRC

        cd \(ShellEscaper.singleQuoted(workingDirectory.standardizedFileURL.path)) || exit 1
        ZDOTDIR="$session_zdotdir" /bin/zsh -i
        exit_code=$?
        rm -rf "$session_zdotdir"
        exit "$exit_code"
        """
    }

    private static func dependencyInstallScript(targets: [DependencyInstallTarget]) -> String {
        let installContainer = targets.contains(.container)
        let installCompose = targets.contains(.containerCompose)

        return """
        #!/bin/zsh
        clear
        set -u

        print_step() {
          printf '\\n==> %s\\n' "$1"
        }

        print_note() {
          printf '    %s\\n' "$1"
        }

        print_step "\(AppBranding.displayName) dependency installer"
        print_note "This script only installs components that were missing when it was generated."
        print_note "Keep this Terminal window open so you can approve installer or Homebrew prompts."

        \(installContainer ? installContainerScriptBlock : "")

        \(installCompose ? installComposeScriptBlock : "")

        print_step "Verification"
        if command -v container >/dev/null 2>&1; then
          container system status || true
        else
          print_note "container is still not available in PATH."
        fi

        if command -v container-compose >/dev/null 2>&1; then
          container-compose version || true
        else
          print_note "container-compose is still not available in PATH."
        fi

        printf '\\nReturn to \(AppBranding.displayName) and click Refresh.\\n'
        printf 'Press Return to close.\\n'
        read
        """
    }

    private static var installContainerScriptBlock: String {
        """
        print_step "Installing apple/container"
        if command -v container >/dev/null 2>&1; then
          print_note "container is already available."
        else
          tmp_dir="$(mktemp -d /tmp/containerdesktop-container.XXXXXX)"
          pkg_path="$tmp_dir/apple-container.pkg"
          pkg_url="$(curl -fsSL https://api.github.com/repos/apple/container/releases/latest | /usr/bin/awk -F '"' '/browser_download_url/ && /\\.pkg"/ {print $4; exit}')"
          if [ -z "$pkg_url" ]; then
            print_note "Could not find a .pkg asset in the latest apple/container release."
            print_note "Open https://github.com/apple/container/releases/latest and install the signed package manually."
          else
            print_note "Downloading $pkg_url"
            if curl -fL "$pkg_url" -o "$pkg_path"; then
              print_note "Running macOS installer. You may be asked for your password."
              sudo installer -pkg "$pkg_path" -target / || print_note "apple/container installer failed."
            else
              print_note "Download failed. Check your network and try again."
            fi
          fi
        fi

        if command -v container >/dev/null 2>&1; then
          print_note "Starting container system."
          container system start || true
        fi
        """
    }

    private static var installComposeScriptBlock: String {
        """
        print_step "Installing Container-Compose"
        if command -v container-compose >/dev/null 2>&1; then
          print_note "container-compose is already available."
        elif ! command -v brew >/dev/null 2>&1; then
          print_note "Homebrew was not found. Install Homebrew first, then run:"
          print_note "brew update && brew install container-compose"
          print_note "Homebrew: https://brew.sh"
          print_note "Container-Compose: https://github.com/Mcrich23/Container-Compose"
        else
          brew update && brew install container-compose || print_note "container-compose install failed."
        fi
        """
    }

    private static func openCommandScript(
        fileName: String,
        body: String,
        terminalApp: SystemTerminalApp? = nil
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContainerDesktop", isDirectory: true)
            .appendingPathComponent("Terminal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let scriptURL = directory.appendingPathComponent(fileName)
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        guard let terminalApp,
              !terminalApp.isSystemDefault
        else {
            if !NSWorkspace.shared.open(scriptURL) {
                throw LaunchError.defaultTerminalOpenFailed(scriptURL)
            }
            return
        }

        guard let appURL = terminalApp.appURL else {
            throw LaunchError.selectedTerminalUnavailable(terminalApp.displayName)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([scriptURL], withApplicationAt: appURL, configuration: configuration) { _, error in
            if let error {
                NSLog("ContainerDesktop failed to open terminal script with %@: %@", terminalApp.displayName, error.localizedDescription)
            }
        }
    }
}
