import SwiftUI

struct DockerCompatibilityTerminalSettingsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("containerdesktop.language", store: .containerDesktopShared) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(DockerCompatibilityTerminalStyle.defaultsKey, store: .containerDesktopShared) private var styleRaw = DockerCompatibilityTerminalStyle.defaultStyle.rawValue

    private var selectedLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }

    private var selectedStyleBinding: Binding<DockerCompatibilityTerminalStyle> {
        Binding(
            get: { DockerCompatibilityTerminalStyle(rawValue: styleRaw) ?? .defaultStyle },
            set: { styleRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                settingsGroup(title: DockerCompatibilityTerminalStrings.languageTitle(language), subtitle: DockerCompatibilityTerminalStrings.languageSubtitle(language)) {
                    ThemedSegmentedPicker(
                        options: AppLanguage.allCases,
                        selection: selectedLanguageBinding,
                        title: { $0.displayName }
                    )
                    .frame(width: 340)
                }

                settingsGroup(title: DockerCompatibilityTerminalStrings.styleSectionTitle(language), subtitle: DockerCompatibilityTerminalStrings.styleSectionSubtitle(language)) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                        ForEach(DockerCompatibilityTerminalStyle.allCases) { style in
                            styleCard(style)
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 820, minHeight: 520, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            IconTile(systemImage: "gearshape", tint: CDTheme.dockerBlue, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(DockerCompatibilityTerminalStrings.settingsWindowTitle(language))
                    .font(.headline.weight(.semibold))
                Text(DockerCompatibilityTerminalStrings.settingsHeaderSubtitle(language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            VStack(spacing: 0) {
                content()
                    .padding(14)
            }
        }
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func styleCard(_ style: DockerCompatibilityTerminalStyle) -> some View {
        let isSelected = selectedStyleBinding.wrappedValue == style

        return Button {
            selectedStyleBinding.wrappedValue = style
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                TerminalStylePreview(appearance: style.configuration, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title(language: language))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(style.subtitle(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? CDTheme.selectionSurface : CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? CDTheme.dockerBlue : CDTheme.separator, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

typealias DockerCompatibilityTerminalStyleSettingsView = DockerCompatibilityTerminalSettingsView

private struct TerminalStylePreview: View {
    var appearance: TerminalStyleConfiguration
    var isSelected: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(appearance.background.color)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.white.opacity(0.26) : Color.white.opacity(0.10))
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Circle().fill(Color.white.opacity(0.28)).frame(width: 8, height: 8)
                    Circle().fill(Color.white.opacity(0.20)).frame(width: 8, height: 8)
                    Circle().fill(Color.white.opacity(0.16)).frame(width: 8, height: 8)
                    Spacer()
                }
                .padding(.bottom, 2)

                Text("> docker --version")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(appearance.foreground.color)
                Text("CLI")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(appearance.caretText.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(appearance.caret.color, in: RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .frame(height: 92)
    }
}
