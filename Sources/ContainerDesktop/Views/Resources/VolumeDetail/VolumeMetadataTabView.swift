import SwiftUI

struct VolumeMetadataTabView: View {
    @Environment(\.appLanguage) private var language
    var volume: VolumeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            metadataSection(
                title: language.resolved == .zhHans ? "标签" : "Labels",
                values: volume.configuration.labels,
                emptyText: language.resolved == .zhHans ? "没有标签。" : "No labels."
            )
            metadataSection(
                title: language.resolved == .zhHans ? "驱动选项" : "Driver Options",
                values: volume.configuration.options,
                emptyText: language.resolved == .zhHans ? "没有驱动选项。" : "No driver options."
            )
        }
    }

    private func metadataSection(title: String, values: [String: String], emptyText: String) -> some View {
        DetailSection(title: title) {
            DetailInfoCard {
                if values.isEmpty {
                    Text(emptyText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(values.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        DetailInfoRow(title: key, value: value)
                    }
                }
            }
        }
    }
}
