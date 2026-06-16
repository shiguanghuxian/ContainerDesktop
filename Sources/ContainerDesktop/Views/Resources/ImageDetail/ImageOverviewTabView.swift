import SwiftUI

struct ImageOverviewTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: ImageDetailStore
    var image: ImageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailSection(title: language.resolved == .zhHans ? "镜像" : "Image") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: image.reference)
                    DetailInfoRow(title: language.t(.tag), value: image.tag)
                    DetailInfoRow(title: language.t(.imageID), value: String(image.id.prefix(18)), monospaced: true)
                    DetailInfoRow(title: "Digest", value: image.digest, monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: image.createdText)
                    DetailInfoRow(title: language.t(.size), value: image.sizeDisplay)
                }
            }

            DetailSection(title: "Variants") {
                VStack(alignment: .leading, spacing: 10) {
                    ImageVariantPicker(image: image, selectedDigest: $store.selectedVariantDigest)

                    VStack(spacing: 0) {
                        ForEach(image.variants, id: \.digest) { variant in
                            ImageVariantRow(
                                variant: variant,
                                isSelected: store.selectedVariantDigest == variant.digest
                            ) {
                                store.selectedVariantDigest = variant.digest
                            }
                        }
                    }
                    .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(CDTheme.separator)
                    }
                }
            }
        }
    }
}

struct ImageVariantPicker: View {
    @Environment(\.appLanguage) private var language
    var image: ImageSummary
    @Binding var selectedDigest: String?

    var body: some View {
        HStack(spacing: 10) {
            Label(language.resolved == .zhHans ? "平台变体" : "Platform variant", systemImage: "cpu")
                .font(.callout.weight(.semibold))
                .foregroundStyle(CDTheme.dockerBlue)
                .fixedSize()

            Picker(language.resolved == .zhHans ? "平台变体" : "Platform variant", selection: $selectedDigest) {
                ForEach(image.variants, id: \.digest) { variant in
                    Text("\(variant.platformText) · \(variant.sizeDisplay)")
                        .tag(Optional(variant.digest))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 340)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

private struct ImageVariantRow: View {
    var variant: ImageSummary.Variant
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CDTheme.dockerBlue : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(variant.platformText)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(variant.digest)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(variant.sizeDisplay)
                        .font(.callout.monospacedDigit())
                    Text("\(variant.layers.count) layers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(isSelected ? CDTheme.selectionSurface : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider()
            .padding(.leading, 12)
    }
}
