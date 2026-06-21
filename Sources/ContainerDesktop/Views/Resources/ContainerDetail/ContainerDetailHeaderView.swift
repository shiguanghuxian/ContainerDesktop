import SwiftUI

struct ContainerDetailHeaderView: View {
    @Environment(\.appLanguage) private var language
    var container: ContainerSummary
    var inspectText: String
    var parentTitle: String
    var onBack: () -> Void
    var onStartStop: () -> Void
    var onRestart: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SecondaryPageBackBar(
                parentTitle: parentTitle,
                detailTitle: container.id,
                onBack: onBack
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    titleBlock
                        .layoutPriority(2)

                    Spacer(minLength: 12)

                    statusBlock
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock

                    HStack(alignment: .center, spacing: 12) {
                        statusBlock
                        Spacer(minLength: 0)
                        actionButtons
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 10)], spacing: 10) {
                detailChip(title: language.t(.image), value: container.imageName, systemImage: "cube")
                detailChip(title: "IP", value: container.primaryIP, systemImage: "network", copyableIP: true)
                detailChip(title: "Platform", value: container.platformName, systemImage: "desktopcomputer")
                detailChip(title: "Resources", value: "\(container.cpuCount) CPU / \(container.memoryDisplay)", systemImage: "cpu")
            }
        }
        .padding(16)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: "shippingbox", tint: CDTheme.dockerBlue, size: 48)

            VStack(alignment: .leading, spacing: 8) {
                Text(container.id)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(String(container.id.prefix(12)), systemImage: "number")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .textSelection(.enabled)
                    Label(container.imageName, systemImage: "cube")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    portSummaryLine
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language.t(.status).uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            StatusPill(
                title: container.state,
                systemImage: container.state == "running" ? "bolt.fill" : "bolt.slash",
                tint: container.state == "running" ? CDTheme.lime : .secondary
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onStartStop) {
                Image(systemName: container.state == "running" ? "stop.fill" : "play.fill")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .help(container.state == "running"
                ? (language.resolved == .zhHans ? "停止容器" : "Stop container")
                : (language.resolved == .zhHans ? "启动容器" : "Start container"))

            Button(action: onRestart) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.bordered)
            .help(language.resolved == .zhHans ? "重启容器" : "Restart container")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .help(language.resolved == .zhHans ? "删除容器" : "Delete container")
        }
        .fixedSize()
    }

    private var portSummaryLine: some View {
        HStack(spacing: 8) {
            Label(portSummary, systemImage: "point.3.connected.trianglepath.dotted")
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            ContainerBrowserPortInlineMenuButton(
                targets: browserPortTargets,
                isDisabled: container.state != "running"
            )
        }
    }

    private func detailChip(title: String, value: String, systemImage: String, copyableIP: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if copyableIP {
                    CopyableIPAddressText(
                        value: value,
                        font: .callout,
                        foregroundStyle: AnyShapeStyle(.primary),
                        textSelectionEnabled: true,
                        minimumScaleFactor: 0.75
                    )
                } else {
                    Text(value)
                        .font(.callout)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var portSummary: String {
        ContainerBrowserPortTarget.portSummary(from: inspectText)
    }

    private var browserPortTargets: [ContainerBrowserPortTarget] {
        ContainerBrowserPortTarget.targets(from: inspectText, container: container)
    }
}
