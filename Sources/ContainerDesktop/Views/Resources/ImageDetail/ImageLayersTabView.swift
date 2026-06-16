import SwiftUI

struct ImageLayersTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ImageDetailStore
    var image: ImageSummary

    private var selectedVariant: ImageSummary.Variant? {
        store.selectedVariant(in: image)
    }

    private var layers: [ImageLayerEntry] {
        selectedVariant?.layers ?? []
    }

    private var filesystemLayerCount: Int {
        layers.filter { !$0.isEmptyLayer }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ImageVariantPicker(image: image, selectedDigest: $store.selectedVariantDigest)

            if let selectedVariant {
                layerSummary(variant: selectedVariant)
            }

            if layers.isEmpty {
                EmptyStateView(
                    title: language.resolved == .zhHans ? "没有层信息" : "No layer data",
                    message: language.resolved == .zhHans ? "当前镜像变体没有 history 或 rootfs 数据。" : "This image variant does not include history or rootfs data.",
                    systemImage: "square.3.layers.3d"
                )
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            } else {
                ScrollView(.horizontal) {
                    VStack(spacing: 0) {
                        layerHeader
                        Divider()
                        ForEach(layers) { layer in
                            ImageLayerRow(layer: layer)
                        }
                    }
                    .frame(minWidth: 980, alignment: .leading)
                }
                .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            }
        }
    }

    private func layerSummary(variant: ImageSummary.Variant) -> some View {
        HStack(spacing: 14) {
            Label("\(layers.count) \(language.resolved == .zhHans ? "条历史" : "history entries")", systemImage: "list.number")
            Label("\(filesystemLayerCount) \(language.resolved == .zhHans ? "个文件层" : "filesystem layers")", systemImage: "externaldrive")
            Label(variant.sizeDisplay, systemImage: "tray.full")
            Spacer(minLength: 0)
            Text(language.resolved == .zhHans ? "单层大小：当前 CLI 未提供" : "Per-layer size: unavailable from current CLI")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(10)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var layerHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "#", width: 46)
            ResourceTableHeaderLabel(title: language.resolved == .zhHans ? "指令" : "Instruction", width: 390)
            ResourceTableHeaderLabel(title: "Diff ID", width: 230)
            ResourceTableHeaderLabel(title: language.t(.created), width: 150)
            ResourceTableHeaderLabel(title: language.resolved == .zhHans ? "类型" : "Type", width: 100)
            ResourceTableHeaderLabel(title: language.t(.size), width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(CDTheme.tableHeaderSurface)
    }
}

private struct ImageLayerRow: View {
    @Environment(\.appLanguage) private var language
    var layer: ImageLayerEntry

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(layer.index)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .leading)

                Text(layer.displayInstruction)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(layer.displayInstruction)
                    .frame(width: 390, alignment: .leading)

                Text(layer.digestText)
                    .font(.caption.monospaced())
                    .foregroundStyle(layer.diffID == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .help(layer.digestText)
                    .frame(width: 230, alignment: .leading)

                Text(layer.createdText)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 150, alignment: .leading)

                StatusPill(
                    title: layer.isEmptyLayer
                        ? (language.resolved == .zhHans ? "元数据" : "metadata")
                        : (language.resolved == .zhHans ? "文件层" : "filesystem"),
                    systemImage: layer.isEmptyLayer ? "doc.plaintext" : "externaldrive",
                    tint: layer.isEmptyLayer ? .secondary : CDTheme.lime
                )
                .frame(width: 100, alignment: .leading)

                Text(layer.sizeDisplay)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 74, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)

            Divider()
                .padding(.leading, 14)
        }
    }
}
