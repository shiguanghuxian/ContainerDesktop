import SwiftUI

struct PanelView<Content: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                if let systemImage {
                    IconTile(systemImage: systemImage, tint: CDTheme.dockerBlue, size: 30)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            content
        }
        .padding(16)
        .glassPanel(accent: systemImage == nil ? nil : CDTheme.dockerBlue.opacity(0.75))
    }
}
