import SwiftUI

enum DockerCompatibilityTerminalSettingsSection: String, CaseIterable, Identifiable {
    case language
    case outputBuffer
    case appearance

    var id: Self { self }

    var systemImage: String {
        switch self {
        case .language:
            "globe"
        case .outputBuffer:
            "text.line.last.and.arrowtriangle.forward"
        case .appearance:
            "paintpalette"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .language:
            DockerCompatibilityTerminalStrings.languageTitle(language)
        case .outputBuffer:
            DockerCompatibilityTerminalStrings.outputBufferTitle(language)
        case .appearance:
            DockerCompatibilityTerminalStrings.styleSectionTitle(language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .language:
            DockerCompatibilityTerminalStrings.languageSubtitle(language)
        case .outputBuffer:
            DockerCompatibilityTerminalStrings.outputBufferSubtitle(language)
        case .appearance:
            DockerCompatibilityTerminalStrings.styleSectionSubtitle(language)
        }
    }
}

struct DockerCompatibilityTerminalSettingsView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("containerdesktop.language", store: .containerDesktopShared) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(DockerCompatibilityTerminalStyle.defaultsKey, store: .containerDesktopShared) private var styleRaw = DockerCompatibilityTerminalStyle.defaultStyle.rawValue
    @AppStorage(DockerCompatibilityTerminalHistorySettings.outputEventLimitDefaultsKey, store: .containerDesktopShared)
    private var outputEventLimit = DockerCompatibilityTerminalHistorySettings.defaultOutputEventLimit
    @State private var selectedSection: DockerCompatibilityTerminalSettingsSection = .language

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

    private var selectedOutputEventLimitBinding: Binding<Int> {
        Binding(
            get: {
                DockerCompatibilityTerminalHistorySettings.clampedOutputEventLimit(outputEventLimit)
            },
            set: {
                outputEventLimit = DockerCompatibilityTerminalHistorySettings.clampedOutputEventLimit($0)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(alignment: .top, spacing: 16) {
                settingsSidebar
                settingsContent
            }
        }
        .padding(20)
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

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(DockerCompatibilityTerminalSettingsSection.allCases) { section in
                settingsSidebarButton(section)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: 220, alignment: .topLeading)
        .frame(minHeight: 360, alignment: .topLeading)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func settingsSidebarButton(_ section: DockerCompatibilityTerminalSettingsSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = section
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? CDTheme.dockerBlue : Color.secondary)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title(language: language))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(section.subtitle(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? CDTheme.selectionSurface : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? CDTheme.dockerBlue.opacity(0.55) : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var settingsContent: some View {
        ScrollView {
            selectedSectionContent
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.trailing, 2)
        }
        .frame(minHeight: 360, alignment: .topLeading)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .language:
            settingsGroup(title: DockerCompatibilityTerminalStrings.languageTitle(language), subtitle: DockerCompatibilityTerminalStrings.languageSubtitle(language)) {
                ThemedSegmentedPicker(
                    options: AppLanguage.allCases,
                    selection: selectedLanguageBinding,
                    title: { $0.displayName }
                )
                .frame(width: 340)
            }
        case .outputBuffer:
            settingsGroup(title: DockerCompatibilityTerminalStrings.outputBufferTitle(language), subtitle: DockerCompatibilityTerminalStrings.outputBufferSubtitle(language)) {
                outputBufferSettings
            }
        case .appearance:
            settingsGroup(title: DockerCompatibilityTerminalStrings.styleSectionTitle(language), subtitle: DockerCompatibilityTerminalStrings.styleSectionSubtitle(language)) {
                styleSettings
            }
        }
    }

    private var outputBufferSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(DockerCompatibilityTerminalStrings.outputBufferLinesTitle(language))
                    .font(.callout.weight(.medium))
                Spacer()
                TextField(
                    "\(DockerCompatibilityTerminalHistorySettings.defaultOutputEventLimit)",
                    value: selectedOutputEventLimitBinding,
                    formatter: outputEventLimitFormatter
                )
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
                Stepper(
                    "",
                    value: selectedOutputEventLimitBinding,
                    in: DockerCompatibilityTerminalHistorySettings.outputEventLimitRange,
                    step: DockerCompatibilityTerminalHistorySettings.outputEventLimitStep
                )
                .labelsHidden()
            }

            Text(DockerCompatibilityTerminalStrings.outputBufferLinesHelp(language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var styleSettings: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
            ForEach(DockerCompatibilityTerminalStyle.allCases) { style in
                styleCard(style)
            }
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

    private var outputEventLimitFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.minimum = NSNumber(value: DockerCompatibilityTerminalHistorySettings.minimumOutputEventLimit)
        formatter.maximum = NSNumber(value: DockerCompatibilityTerminalHistorySettings.maximumOutputEventLimit)
        formatter.generatesDecimalNumbers = false
        return formatter
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
