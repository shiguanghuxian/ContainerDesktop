import SwiftUI

struct VolumeDetailHeaderView: View {
    @Environment(\.appLanguage) private var language
    var volume: VolumeSummary
    var parentTitle: String
    var isRefreshing: Bool
    var onBack: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SecondaryPageBackBar(
                parentTitle: parentTitle,
                detailTitle: volume.name,
                onBack: onBack
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    titleBlock
                        .layoutPriority(2)
                    Spacer(minLength: 12)
                    refreshButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    refreshButton
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 10)], spacing: 10) {
                detailChip(title: language.t(.type), value: volume.typeText, systemImage: "tag")
                detailChip(title: language.t(.driver), value: volume.driver, systemImage: "externaldrive")
                detailChip(title: "Format", value: volume.format, systemImage: "doc.richtext")
                detailChip(title: language.t(.size), value: volume.sizeDisplay, systemImage: "tray.full")
                detailChip(title: language.t(.created), value: volume.createdText, systemImage: "calendar")
                detailChip(
                    title: language.resolved == .zhHans ? "元数据" : "Metadata",
                    value: "\(volume.configuration.labels.count + volume.configuration.options.count)",
                    systemImage: "number"
                )
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
            IconTile(systemImage: "externaldrive", tint: CDTheme.dockerBlue, size: 48)

            VStack(alignment: .leading, spacing: 8) {
                Text(volume.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(volume.typeText, systemImage: "tag")
                    Label(volume.driver, systemImage: "externaldrive")
                    Label(volume.source, systemImage: "folder")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 34, height: 30)
            } else {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 34, height: 30)
            }
        }
        .buttonStyle(.bordered)
        .disabled(isRefreshing)
        .help(language.t(.refresh))
        .fixedSize()
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
                    .textSelection(.enabled)
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
