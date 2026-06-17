import SwiftUI

struct NetworkMetadataTabView: View {
    @Environment(\.appLanguage) private var language
    var network: NetworkSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if network.sortedLabels.isEmpty && network.sortedOptions.isEmpty {
                emptyMetadataState
            } else {
                if !network.sortedLabels.isEmpty {
                    metadataSection(
                        title: language.resolved == .zhHans ? "标签" : "Labels",
                        rows: network.sortedLabels
                    )
                }

                if !network.sortedOptions.isEmpty {
                    metadataSection(
                        title: language.resolved == .zhHans ? "插件选项" : "Plugin Options",
                        rows: network.sortedOptions
                    )
                }
            }
        }
    }

    private var emptyMetadataState: some View {
        DetailSection(title: language.resolved == .zhHans ? "元数据" : "Metadata") {
            DetailInfoCard {
                Label(
                    language.resolved == .zhHans ? "没有标签或插件选项。" : "No labels or plugin options.",
                    systemImage: "tag.slash"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataSection(title: String, rows: [(key: String, value: String)]) -> some View {
        DetailSection(title: title) {
            DetailInfoCard {
                ForEach(rows, id: \.key) { key, value in
                    DetailInfoRow(title: key, value: value)
                }
            }
        }
    }
}
