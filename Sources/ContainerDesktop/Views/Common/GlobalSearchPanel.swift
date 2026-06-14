import SwiftUI

struct GlobalSearchResult: Identifiable {
    enum Target {
        case section(AppSection)
        case refresh
        case startSystem
        case stopSystem
        case settings
    }

    var id: String
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color
    var target: Target
}

struct GlobalSearchPanel: View {
    @Environment(\.appLanguage) private var language
    var query: String
    var results: [GlobalSearchResult]
    var onSelect: (GlobalSearchResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language.resolved == .zhHans ? "全局搜索" : "Global Search")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("Return")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            if results.isEmpty {
                Text(language.resolved == .zhHans ? "没有匹配：\(query)" : "No matches: \(query)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(results) { result in
                    Button {
                        onSelect(result)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: result.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(result.tint)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.callout.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 360)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(CDTheme.separator)
        }
        .shadow(color: CDTheme.panelShadow, radius: 18, x: 0, y: 10)
    }
}
