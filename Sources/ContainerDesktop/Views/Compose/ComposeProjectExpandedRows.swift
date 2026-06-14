import SwiftUI

struct ComposeProjectExpandedRows: View {
    @Environment(\.appLanguage) private var language
    var project: ComposeProject
    var runtimeSummaries: [ComposeServiceRuntimeSummary]
    var activeContainerActionKey: String?
    var activeRuntimeOperationKey: String?
    var onOpenContainer: (ContainerSummary) -> Void
    var onOpenTerminal: (ComposeServiceRuntimeSummary) -> Void
    var onObserveService: (ComposeServiceRuntimeSummary) -> Void
    var onStartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStopContainers: (ComposeServiceRuntimeSummary) -> Void
    var onRestartContainers: (ComposeServiceRuntimeSummary) -> Void
    var onStartContainer: (ContainerSummary) -> Void
    var onStopContainer: (ContainerSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(project.services) { service in
                serviceSection(summary(for: service))
            }
        }
        .padding(.leading, 54)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .background(CDTheme.elevatedSurface.opacity(0.62))
    }

    private func serviceSection(_ summary: ComposeServiceRuntimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(summary.service.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                StatusPill(
                    title: summary.state.displayText,
                    systemImage: "shippingbox",
                    tint: tint(for: summary.state)
                )

                Text(containerCountText(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

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

            Text(summary.service.image ?? summary.service.buildContext ?? "—")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if summary.containers.isEmpty {
                Text(language.resolved == .zhHans ? "未创建容器" : "No containers created")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 6) {
                    ForEach(summary.containers) { container in
                        ComposeContainerInlineRow(
                            container: container,
                            activeRuntimeOperationKey: activeRuntimeOperationKey,
                            onOpenContainer: onOpenContainer,
                            onStartContainer: onStartContainer,
                            onStopContainer: onStopContainer
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
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
}

private struct ComposeContainerInlineRow: View {
    @Environment(\.appLanguage) private var language
    var container: ContainerSummary
    var activeRuntimeOperationKey: String?
    var onOpenContainer: (ContainerSummary) -> Void
    var onStartContainer: (ContainerSummary) -> Void
    var onStopContainer: (ContainerSummary) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onOpenContainer(container)
            } label: {
                HStack(spacing: 10) {
                    ResourceStatusDot(tint: container.state == "running" ? CDTheme.lime : .secondary)

                    Text(container.id)
                        .font(.callout.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)

                    Text(container.imageName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 170, alignment: .leading)

                    Text(container.primaryIP)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(width: 116, alignment: .leading)

                    StatusPill(
                        title: container.state,
                        systemImage: container.state == "running" ? "play.fill" : "stop.fill",
                        tint: container.state == "running" ? CDTheme.lime : .secondary
                    )
                    .frame(width: 96, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "打开容器详情" : "Open container details")

            HStack(spacing: 7) {
                let startStopKey = container.state == "running"
                    ? RuntimeOperationKey.containerStop(container.id)
                    : RuntimeOperationKey.containerStart(container.id)
                RowActionButton(
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

                RowActionButton(
                    systemImage: "arrow.up.right.square",
                    help: language.resolved == .zhHans ? "打开容器详情" : "Open container details"
                ) {
                    onOpenContainer(container)
                }
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(CDTheme.hairline)
        }
    }

    private func isContainerOperationBlocked(except key: String) -> Bool {
        if let activeRuntimeOperationKey {
            return activeRuntimeOperationKey != key
        }
        return false
    }
}

