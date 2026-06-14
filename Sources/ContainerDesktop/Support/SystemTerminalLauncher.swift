import AppKit
import Foundation

enum SystemTerminalLauncher {
    static func openDependencyInstallScript(targets: [DependencyInstallTarget]) throws {
        let uniqueTargets = DependencyInstallTarget.allCases.filter { targets.contains($0) }
        guard !uniqueTargets.isEmpty else { return }

        try openCommandScript(
            fileName: "containerdesktop-install-dependencies.command",
            body: dependencyInstallScript(targets: uniqueTargets)
        )
    }

    static func openContainerShell(id: String) throws {
        try openCommandScript(
            fileName: "container-\(safeFileComponent(id))-exec.command",
            body: """
            #!/bin/zsh
            clear
            printf '%s\\n\\n' \(ShellEscaper.singleQuoted("ContainerDesktop - Container \(id)"))
            if ! command -v container >/dev/null 2>&1; then
              echo "container CLI was not found in this terminal session."
              echo "Press Return to close."
              read
              exit 127
            fi
            exec container exec -it \(ShellEscaper.singleQuoted(id)) sh
            """
        )
    }

    static func openMachineShell(id: String) throws {
        try openCommandScript(
            fileName: "machine-\(safeFileComponent(id))-shell.command",
            body: """
            #!/bin/zsh
            clear
            printf '%s\\n\\n' \(ShellEscaper.singleQuoted("ContainerDesktop - Machine \(id)"))
            if ! command -v container >/dev/null 2>&1; then
              echo "container CLI was not found in this terminal session."
              echo "Press Return to close."
              read
              exit 127
            fi
            exec container machine run -n \(ShellEscaper.singleQuoted(id)) -i -t -- sh
            """
        )
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

        print_step "ContainerDesktop dependency installer"
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

        printf '\\nReturn to ContainerDesktop and click Refresh.\\n'
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

    private static func openCommandScript(fileName: String, body: String) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ContainerDesktop", isDirectory: true)
            .appendingPathComponent("Terminal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let scriptURL = directory.appendingPathComponent(fileName)
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        NSWorkspace.shared.open(scriptURL)
    }

    private static func safeFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let result = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "resource" : result
    }
}
