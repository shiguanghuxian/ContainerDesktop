import SwiftUI

struct VolumeDetailTabBar: View {
    @Environment(\.appLanguage) private var language
    @Binding var selection: VolumeDetailTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(VolumeDetailTab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.systemImage)
                        Text(tab.title(language: language))
                    }
                    .font(.callout.weight(selection == tab ? .semibold : .medium))
                    .foregroundStyle(selection == tab ? CDTheme.dockerBlue : .secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .background(selection == tab ? CDTheme.dockerBlue.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(selection == tab ? CDTheme.dockerBlue.opacity(0.26) : Color.clear)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(selection == tab ? CDTheme.dockerBlue : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
