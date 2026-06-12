import SwiftUI

struct ResourceRowCard<Leading: View, Metadata: View, Actions: View>: View {
    var isSelected: Bool
    @ViewBuilder var leading: Leading
    @ViewBuilder var metadata: Metadata
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leading
            Spacer(minLength: 16)
            metadata
            actions
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(isSelected ? CDTheme.dockerBlue.opacity(0.08) : Color.clear)
    }
}
