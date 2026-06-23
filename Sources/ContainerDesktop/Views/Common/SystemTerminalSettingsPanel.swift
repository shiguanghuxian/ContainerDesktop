import AppKit
import SwiftUI

struct SystemTerminalSettingsPanel: View {
    @Environment(\.appLanguage) private var language
    @State private var systemTerminalIntegrationInstalled = DockerCompatibilitySystemTerminalIntegration().isInstalled
    @State private var systemTerminalApps = SystemTerminalAppDiscovery().availableTerminalApps()
    @State private var selectedSystemTerminalAppBundleID = SystemTerminalAppPreference.selectedBundleIdentifier() ?? ""
    @State private var systemTerminalFeedback: String?

    private var selectedSystemTerminalAppBinding: Binding<String> {
        Binding(
            get: { selectedSystemTerminalAppBundleID },
            set: { newValue in
                selectedSystemTerminalAppBundleID = newValue
                SystemTerminalAppPreference.setSelectedBundleIdentifier(newValue.isEmpty ? nil : newValue)
            }
        )
    }

    private var selectedSystemTerminalAppForOpening: SystemTerminalApp? {
        guard !selectedSystemTerminalAppBundleID.isEmpty else { return nil }
        return systemTerminalApps.first { $0.preferenceValue == selectedSystemTerminalAppBundleID }
            ?? .missing(bundleIdentifier: selectedSystemTerminalAppBundleID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            systemTerminalAppSelection

            Divider()

            HStack(spacing: 10) {
                Image(systemName: systemTerminalIntegrationInstalled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(systemTerminalIntegrationInstalled ? CDTheme.lime : Color.secondary)
                Text(systemTerminalIntegrationInstalled
                    ? DockerCompatibilityTerminalStrings.systemTerminalStatusInstalled(language)
                    : DockerCompatibilityTerminalStrings.systemTerminalStatusMissing(language)
                )
                .font(.callout.weight(.medium))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                Button {
                    openCompatibleSystemTerminal()
                } label: {
                    Label(DockerCompatibilityTerminalStrings.openCompatibleSystemTerminal(language), systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    installSystemTerminalIntegration()
                } label: {
                    Label(DockerCompatibilityTerminalStrings.installSystemTerminalIntegration(language), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    uninstallSystemTerminalIntegration()
                } label: {
                    Label(DockerCompatibilityTerminalStrings.uninstallSystemTerminalIntegration(language), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!systemTerminalIntegrationInstalled)

                Button {
                    copySystemTerminalShimPath()
                } label: {
                    Label(DockerCompatibilityTerminalStrings.copyShimPathLabel(language), systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if let systemTerminalFeedback {
                Text(systemTerminalFeedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .onAppear(perform: refreshSystemTerminalSettingsState)
    }

    private var systemTerminalAppSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label(DockerCompatibilityTerminalStrings.systemTerminalOpenWith(language), systemImage: "app.dashed")
                    .font(.callout.weight(.medium))
                Spacer()
                Button {
                    refreshSystemTerminalApps()
                    systemTerminalFeedback = language.resolved == .zhHans ? "已刷新终端列表。" : "Refreshed terminal apps."
                } label: {
                    Label(DockerCompatibilityTerminalStrings.refreshTerminalApps(language), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            Picker(
                DockerCompatibilityTerminalStrings.systemTerminalOpenWith(language),
                selection: selectedSystemTerminalAppBinding
            ) {
                ForEach(systemTerminalApps) { app in
                    Text(systemTerminalAppTitle(app))
                        .tag(app.preferenceValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 360, alignment: .leading)

            if let selectedApp = selectedSystemTerminalAppForOpening {
                Label(
                    selectedApp.pathText ?? DockerCompatibilityTerminalStrings.selectedTerminalAppUnavailable(language),
                    systemImage: selectedApp.isAvailable ? "checkmark.circle" : "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(selectedApp.isAvailable ? Color.secondary : CDTheme.ember)
                .textSelection(.enabled)
            }

            if systemTerminalApps.filter({ !$0.isSystemDefault }).isEmpty {
                Text(DockerCompatibilityTerminalStrings.noOtherTerminalAppsFound(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func refreshSystemTerminalSettingsState() {
        systemTerminalIntegrationInstalled = DockerCompatibilitySystemTerminalIntegration().isInstalled
        refreshSystemTerminalApps()
    }

    private func refreshSystemTerminalApps() {
        let selectedBundleIdentifier = SystemTerminalAppPreference.selectedBundleIdentifier()
        selectedSystemTerminalAppBundleID = selectedBundleIdentifier ?? ""
        systemTerminalApps = SystemTerminalAppDiscovery().availableTerminalApps(including: selectedBundleIdentifier)
    }

    private func systemTerminalAppTitle(_ app: SystemTerminalApp) -> String {
        if app.isSystemDefault {
            return DockerCompatibilityTerminalStrings.systemDefaultTerminalApp(language)
        }
        return app.isAvailable ? app.displayName : "\(app.displayName) (\(DockerCompatibilityTerminalStrings.unavailableTerminalAppSuffix(language)))"
    }

    private func openCompatibleSystemTerminal() {
        do {
            try SystemTerminalLauncher.openDockerCompatibilityShell(terminalApp: selectedSystemTerminalAppForOpening)
            systemTerminalFeedback = language.resolved == .zhHans ? "已打开兼容系统终端。" : "Opened a compatible system terminal."
        } catch {
            systemTerminalFeedback = error.localizedDescription
        }
    }

    private func installSystemTerminalIntegration() {
        do {
            let environment = try DockerCompatibilityTerminalService().prepareEnvironment()
            try DockerCompatibilitySystemTerminalIntegration().install(shimDirectory: environment.shimBinDirectory)
            systemTerminalIntegrationInstalled = true
            systemTerminalFeedback = language.resolved == .zhHans ? "已安装。新开的 zsh 终端会启用 Docker 命令转换。" : "Installed. New zsh terminal sessions will use Docker command conversion."
        } catch {
            systemTerminalFeedback = error.localizedDescription
        }
    }

    private func uninstallSystemTerminalIntegration() {
        do {
            try DockerCompatibilitySystemTerminalIntegration().uninstall()
            systemTerminalIntegrationInstalled = false
            systemTerminalFeedback = language.resolved == .zhHans ? "已卸载。新开的系统终端不再启用该 shim。" : "Uninstalled. New system terminals will no longer use this shim."
        } catch {
            systemTerminalFeedback = error.localizedDescription
        }
    }

    private func copySystemTerminalShimPath() {
        do {
            let environment = try DockerCompatibilityTerminalService().prepareEnvironment()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(environment.shimBinDirectory.path, forType: .string)
            systemTerminalFeedback = language.resolved == .zhHans ? "已复制 shim PATH。" : "Copied shim PATH."
        } catch {
            systemTerminalFeedback = error.localizedDescription
        }
    }
}
