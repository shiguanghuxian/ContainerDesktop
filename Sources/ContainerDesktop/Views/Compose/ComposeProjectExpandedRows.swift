import SwiftUI

struct ComposeProjectExpandedRows: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    var project: ComposeProject
    var runtimeSummaries: [ComposeServiceRuntimeSummary]
    var activeContainerActionKey: String?
    var activeRuntimeOperationKey: String?
    var onOpenContainer: (ContainerSummary) -> Void
    var onOpenTerminal: (ComposeServiceRuntimeSummary, ExternalTerminalDestination) -> Void
    var onObserveService: (ComposeServiceRuntimeSummary) -> Void
    var onStartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStopContainers: (ComposeServiceRuntimeSummary) -> Void
    var onRestartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStartContainer: (ContainerSummary) -> Void
    var onStopContainer: (ContainerSummary) -> Void
    var browserPortTargets: (ContainerSummary) -> [ContainerBrowserPortTarget]
    var isBrowserPortTargetsLoading: (ContainerSummary) -> Bool
    var browserPortTargetError: (ContainerSummary) -> String?
    var onLoadBrowserPortTargets: (ContainerSummary) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(project.services.enumerated()), id: \.element.id) { index, service in
                serviceSection(summary(for: service))

                if index < project.services.count - 1 {
                    Rectangle()
                        .fill(expandedSeparator)
                        .frame(height: 1)
                        .padding(.leading, 8)
                }
            }
        }
        .padding(.leading, 40)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background {
            ZStack(alignment: .leading) {
                CDTheme.rowStripeSurface
                CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.085 : 0.045)

                Rectangle()
                    .fill(CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.58 : 0.38))
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(expandedBoundary)
                .frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(expandedBoundary)
                .frame(height: 1)
        }
    }

    private func serviceSection(_ summary: ComposeServiceRuntimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            serviceHeader(summary)

            if summary.containers.isEmpty {
                Text(language.resolved == .zhHans ? "未创建容器" : "No containers created")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.containers.enumerated()), id: \.element.id) { index, container in
                        ComposeContainerInlineRow(
                            container: container,
                            activeRuntimeOperationKey: activeRuntimeOperationKey,
                            onOpenContainer: onOpenContainer,
                            onStartContainer: onStartContainer,
                            onStopContainer: onStopContainer,
                            browserPortTargets: browserPortTargets,
                            isBrowserPortTargetsLoading: isBrowserPortTargetsLoading,
                            browserPortTargetError: browserPortTargetError,
                            onLoadBrowserPortTargets: onLoadBrowserPortTargets
                        )

                        if index < summary.containers.count - 1 {
                            Rectangle()
                                .fill(containerSeparator)
                                .frame(height: 1)
                                .padding(.leading, 30)
                                .padding(.trailing, 62)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func serviceHeader(_ summary: ComposeServiceRuntimeSummary) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(summary.service.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    CompactComposeStatusPill(
                        title: summary.state.displayText,
                        systemImage: "shippingbox",
                        tint: tint(for: summary.state)
                    )

                    Text(containerCountText(summary))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: summary.service.image == nil ? "folder" : "shippingbox")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(summary.service.image ?? summary.service.buildContext ?? "—")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            ComposeServiceRuntimeMenu(
                summary: summary,
                onOpenContainer: onOpenContainer,
                onOpenTerminal: onOpenTerminal,
                onObserveService: onObserveService,
                onStartContainers: onStartContainers,
                onStopContainers: onStopContainers,
                onRestartContainers: onRestartContainers,
                isBusy: activeContainerActionKey == composeContainerOperationKey(projectID: project.id, serviceName: summary.service.name)
            )
        }
    }

    private func summary(for service: ComposeProject.Service) -> ComposeServiceRuntimeSummary {
        runtimeSummaries.first { $0.service.name == service.name }
            ?? ComposeServiceRuntimeSummary(service: service, containers: [])
    }

    private func containerCountText(_ summary: ComposeServiceRuntimeSummary) -> String {
        if summary.containers.isEmpty {
            return language.resolved == .zhHans ? "0 个容器" : "0 containers"
        }
        return "\(summary.runningCount)/\(summary.containers.count) running"
    }

    private func tint(for state: ComposeServiceRuntimeState) -> Color {
        switch state {
        case .running:
            CDTheme.lime
        case .mixed:
            CDTheme.violet
        case .stopped:
            CDTheme.ember
        case .missing:
            .secondary
        }
    }

    private var expandedBoundary: Color {
        CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.24 : 0.18)
    }

    private var expandedSeparator: Color {
        CDTheme.separator.opacity(colorScheme == .dark ? 0.52 : 0.42)
    }

    private var containerSeparator: Color {
        CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.16 : 0.10)
    }
}

private struct ComposeContainerInlineRow: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    var container: ContainerSummary
    var activeRuntimeOperationKey: String?
    var onOpenContainer: (ContainerSummary) -> Void
    var onStartContainer: (ContainerSummary) -> Void
    var onStopContainer: (ContainerSummary) -> Void
    var browserPortTargets: (ContainerSummary) -> [ContainerBrowserPortTarget]
    var isBrowserPortTargetsLoading: (ContainerSummary) -> Bool
    var browserPortTargetError: (ContainerSummary) -> String?
    var onLoadBrowserPortTargets: (ContainerSummary) async -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                onOpenContainer(container)
            } label: {
                HStack(spacing: 8) {
                    ResourceStatusDot(tint: container.state == "running" ? CDTheme.lime : .secondary)

                    Text(container.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                    Text(container.imageName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 160, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .help(language.resolved == .zhHans ? "打开容器详情" : "Open container details")

            HStack(spacing: 6) {
                CopyableIPAddressText(
                    value: container.primaryIP,
                    font: .caption2.monospaced(),
                    minimumScaleFactor: 0.78,
                    copyButtonSize: 20
                )
                .frame(width: 108, alignment: .leading)

                ContainerBrowserPortMenuButton(
                    targets: browserPortTargets(container),
                    isLoading: isBrowserPortTargetsLoading(container),
                    errorMessage: browserPortTargetError(container)
                )
            }
            .frame(width: 142, alignment: .leading)
            .task(id: "\(container.id)-\(container.state)") {
                await onLoadBrowserPortTargets(container)
            }

            CompactComposeStatusPill(
                title: container.state,
                systemImage: container.state == "running" ? "play.fill" : "stop.fill",
                tint: container.state == "running" ? CDTheme.lime : .secondary
            )
            .frame(width: 86, alignment: .leading)

            HStack(spacing: 5) {
                let startStopKey = container.state == "running"
                    ? RuntimeOperationKey.containerStop(container.id)
                    : RuntimeOperationKey.containerStart(container.id)
                CompactComposeRowActionButton(
                    systemImage: container.state == "running" ? "stop.fill" : "play.fill",
                    tint: container.state == "running" ? CDTheme.ember : CDTheme.lime,
                    isLoading: activeRuntimeOperationKey == startStopKey,
                    isDisabled: isContainerOperationBlocked(except: startStopKey),
                    help: container.state == "running"
                        ? (language.resolved == .zhHans ? "停止容器" : "Stop container")
                        : (language.resolved == .zhHans ? "启动容器" : "Start container")
                ) {
                    if container.state == "running" {
                        onStopContainer(container)
                    } else {
                        onStartContainer(container)
                    }
                }

                CompactComposeRowActionButton(
                    systemImage: "arrow.up.right.square",
                    help: language.resolved == .zhHans ? "打开容器详情" : "Open container details"
                ) {
                    onOpenContainer(container)
                }
            }
            .frame(width: 56, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(minHeight: 38)
        .background(containerRowBackground, in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func isContainerOperationBlocked(except key: String) -> Bool {
        if let activeRuntimeOperationKey {
            return activeRuntimeOperationKey != key
        }
        return false
    }

    private var containerRowBackground: Color {
        if isHovering {
            return CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.13 : 0.075)
        }
        return CDTheme.dockerBlue.opacity(colorScheme == .dark ? 0.035 : 0.018)
    }
}

private struct CompactComposeStatusPill: View {
    var title: String
    var systemImage: String
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 8, weight: .bold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .frame(height: 20)
        .background(tint.opacity(0.1), in: Capsule())
    }
}

private struct CompactComposeRowActionButton: View {
    var systemImage: String
    var tint: Color = CDTheme.dockerBlue
    var isLoading = false
    var isDisabled = false
    var help: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDisabled ? .secondary : tint)
                }
            }
            .frame(width: 24, height: 24)
            .background((isDisabled ? Color.secondary : tint).opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .help(help ?? "")
    }
}
