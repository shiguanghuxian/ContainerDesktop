import SwiftUI

struct MachineDetailTabBar: View {
    @Environment(\.appLanguage) private var language
    @Binding var selection: MachineDetailTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MachineDetailTab.allCases) { tab in
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
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .contentShape(Rectangle())
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
        .padding(.horizontal, 10)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}
