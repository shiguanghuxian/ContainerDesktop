import SwiftUI

struct PanelView<Content: View, HeaderAccessory: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String?
    @ViewBuilder var headerAccessory: HeaderAccessory
    @ViewBuilder var content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) where HeaderAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.headerAccessory = EmptyView()
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

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
                headerAccessory
            }
            content
        }
        .padding(16)
        .glassPanel(accent: systemImage == nil ? nil : CDTheme.dockerBlue.opacity(0.75))
    }
}
