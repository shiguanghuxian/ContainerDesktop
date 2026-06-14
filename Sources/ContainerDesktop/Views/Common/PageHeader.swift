import SwiftUI

struct PageHeader<Actions: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    @ViewBuilder var actions: Actions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
            verticalLayout
        }
        .padding(.vertical, 8)
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(systemImage: systemImage, tint: CDTheme.dockerBlue, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            titleBlock

            Spacer(minLength: 16)
            actions
                .buttonStyle(CDSecondaryButtonStyle())
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock
            actions
                .buttonStyle(CDSecondaryButtonStyle())
        }
    }
}
