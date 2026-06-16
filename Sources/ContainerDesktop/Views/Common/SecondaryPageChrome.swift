import SwiftUI

struct SecondaryDetailPageContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .thinScrollBars()
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct SecondaryPageBackBar: View {
    @Environment(\.appLanguage) private var language
    var parentTitle: String
    var detailTitle: String
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text(language.resolved == .zhHans ? "返回" : "Back")
                        .font(.callout.weight(.semibold))
                }
                .foregroundStyle(CDTheme.dockerBlue)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "返回\(parentTitle)" : "Back to \(parentTitle)")

            Text(parentTitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(CDTheme.dockerBlue)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            Text(detailTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}
