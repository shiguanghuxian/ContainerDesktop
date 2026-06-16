import SwiftUI

struct MachineDetailHeaderView: View {
    @Environment(\.appLanguage) private var language
    var machine: MachineSummary
    var inspection: MachineInspection?
    var isConfigSaving = false
    var onBack: () -> Void
    var onStartStop: () -> Void
    var onSetDefault: () -> Void
    var onEditConfig: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SecondaryPageBackBar(
                parentTitle: language.t(.machines),
                detailTitle: machine.id,
                onBack: onBack
            )

            HStack(alignment: .center, spacing: 16) {
                IconTile(systemImage: "desktopcomputer", tint: CDTheme.dockerBlue, size: 48)

                VStack(alignment: .leading, spacing: 8) {
                    Text(machine.id)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                        .textSelection(.enabled)

                    HStack(spacing: 12) {
                        Label(inspection?.image.referenceText ?? "—", systemImage: "cube")
                            .lineLimit(1)
                            .textSelection(.enabled)
                        Label(inspection?.platformText ?? "—", systemImage: "cpu")
                            .lineLimit(1)
                            .textSelection(.enabled)
                        Label(inspection?.userSetup.username ?? "—", systemImage: "person.crop.circle")
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(language.t(.status).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    StatusPill(
                        title: machine.statusText,
                        systemImage: machine.isRunning ? "bolt.fill" : "bolt.slash",
                        tint: machine.isRunning ? CDTheme.lime : .secondary
                    )
                }

                HStack(spacing: 8) {
                    Button(action: onStartStop) {
                        Image(systemName: machine.isRunning ? "stop.fill" : "play.fill")
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .help(machine.isRunning
                        ? (language.resolved == .zhHans ? "停止 Machine" : "Stop Machine")
                        : (language.resolved == .zhHans ? "启动 Machine" : "Start Machine"))

                    Button(action: onSetDefault) {
                        Image(systemName: machine.isDefault ? "star.fill" : "star")
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .help(machine.isDefault
                        ? (language.resolved == .zhHans ? "当前默认 Machine" : "Current default Machine")
                        : (language.resolved == .zhHans ? "设为默认 Machine" : "Set as default Machine"))

                    Button(action: onEditConfig) {
                        if isConfigSaving {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 34, height: 30)
                        } else {
                            Image(systemName: "pencil")
                                .frame(width: 34, height: 30)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isConfigSaving)
                    .help(language.resolved == .zhHans ? "编辑 Machine 配置" : "Edit Machine configuration")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .help(language.resolved == .zhHans ? "删除 Machine" : "Delete Machine")
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                detailChip(title: "IP", value: machine.ipAddressText, systemImage: "network")
                detailChip(title: "Resources", value: "\(machine.cpus) CPU / \(machine.memoryDisplay)", systemImage: "cpu")
                detailChip(title: "Disk", value: machine.diskSizeDisplay, systemImage: "internaldrive")
                detailChip(title: language.t(.homeMount), value: inspection?.homeMount ?? "—", systemImage: "house")
            }
        }
        .padding(16)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func detailChip(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(CDTheme.dockerBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
}
