import SwiftUI

struct ImageDetailHeaderView: View {
    @Environment(\.appLanguage) private var language
    var image: ImageSummary
    var selectedVariant: ImageSummary.Variant?
    var parentTitle: String
    var isRefreshing: Bool
    var onBack: () -> Void
    var onRefresh: () -> Void
    var onOpenTasks: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SecondaryPageBackBar(
                parentTitle: parentTitle,
                detailTitle: image.reference,
                onBack: onBack
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    titleBlock
                        .layoutPriority(2)
                    Spacer(minLength: 12)
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 12) {
                    titleBlock
                    actionButtons
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 320), spacing: 10)], spacing: 10) {
                detailChip(title: language.t(.imageID), value: String(image.id.prefix(18)), systemImage: "number")
                detailChip(title: language.t(.created), value: image.createdText, systemImage: "calendar")
                detailChip(title: language.t(.size), value: image.sizeDisplay, systemImage: "externaldrive")
                detailChip(title: "Variant", value: selectedVariant?.platformText ?? "—", systemImage: "cpu")
                detailChip(title: language.resolved == .zhHans ? "变体大小" : "Variant size", value: selectedVariant?.sizeDisplay ?? "—", systemImage: "tray.full")
                detailChip(title: language.resolved == .zhHans ? "层数" : "Layers", value: "\(selectedVariant?.layers.count ?? 0)", systemImage: "square.3.layers.3d")
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
            IconTile(systemImage: "photo.stack", tint: CDTheme.dockerBlue, size: 48)

            VStack(alignment: .leading, spacing: 8) {
                Text(image.reference)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Label(image.tag, systemImage: "tag")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Label(String(image.digest.prefix(24)), systemImage: "fingerprint")
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Label(selectedVariant?.platformText ?? "—", systemImage: "desktopcomputer")
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

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button(action: onOpenTasks) {
                Image(systemName: "clock.arrow.circlepath")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.bordered)
            .help(language.resolved == .zhHans ? "打开镜像任务列表" : "Open image tasks")

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
        }
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
