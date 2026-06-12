import SwiftUI

struct PageHeader<Actions: View>: View {
    var title: String
    var subtitle: String
    var systemImage: String
    @ViewBuilder var actions: Actions

    var body: some View {
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

            Spacer(minLength: 16)
            actions
        }
        .padding(.vertical, 8)
    }
}
