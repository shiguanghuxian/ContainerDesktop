import SwiftUI

struct SidebarView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: AppSection
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    var isCollapsed: Bool

    var body: some View {
        Group {
            if isCollapsed {
                collapsedSidebar
            } else {
                expandedSidebar
            }
        }
        .background {
            sidebarBackground
        }
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(runtimeStore.isReady ? CDTheme.lime.opacity(0.18) : CDTheme.ember.opacity(0.18))
                        Image(systemName: runtimeStore.menuBarIcon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(runtimeStore.isReady ? CDTheme.lime : CDTheme.ember)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.t(.environment))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(primaryText)
                        Text(runtimeStore.statusTitle(language: language))
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                }

                HStack(spacing: 8) {
                    StatusPill(
                        title: runtimeStore.environment.containerAvailable ? "CLI" : language.t(.cliMissing),
                        systemImage: runtimeStore.environment.containerAvailable ? "checkmark.circle" : "exclamationmark.triangle",
                        tint: runtimeStore.environment.containerAvailable ? .green : .orange
                    )
                    .font(.caption2)
                    StatusPill(
                        title: runtimeStore.environment.systemRunning ? "System" : language.t(.systemStopped),
                        systemImage: runtimeStore.environment.systemRunning ? "bolt.fill" : "bolt.slash",
                        tint: runtimeStore.environment.systemRunning ? .blue : .secondary
                    )
                    .font(.caption2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sidebarCardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SidebarGroup(title: language.t(.localResources).uppercased()) {
                        ForEach([AppSection.dashboard, .containers, .machines, .images, .volumes, .networks], id: \.self) { section in
                            SidebarNavButton(section: section, language: language, isSelected: selection == section) {
                                selection = section
                            }
                        }
                    }

                    SidebarGroup(title: language.t(.workflows).uppercased()) {
                        ForEach([AppSection.compose, .observability, .registries, .commandConverter], id: \.self) { section in
                            SidebarNavButton(section: section, language: language, isSelected: selection == section) {
                                selection = section
                            }
                        }
                    }

                    SidebarGroup(title: language.t(.admin).uppercased()) {
                        SidebarNavButton(section: .system, language: language, isSelected: selection == .system) {
                            selection = .system
                        }
                    }

                    SidebarGroup(title: (language.resolved == .zhHans ? "支持" : "Support").uppercased()) {
                        ForEach([AppSection.help, .about], id: \.self) { section in
                            SidebarNavButton(section: section, language: language, isSelected: selection == section) {
                                selection = section
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .thinScrollBars()

            Spacer(minLength: 0)

            authorInfoCard
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(sidebarCardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private var authorInfoCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(language.resolved == .zhHans ? "作者信息" : "Author")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(CDTheme.cyan)

            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text("时光弧线")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
            }

            Link(destination: URL(string: "mailto:zuoxiupeng@live.com")!) {
                authorLinkLabel(text: "zuoxiupeng@live.com", systemImage: "envelope")
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "发送邮件给作者" : "Email the author")

            Link(destination: URL(string: "https://github.com/shiguanghuxian")!) {
                authorLinkLabel(text: "github.com/shiguanghuxian", systemImage: "link")
            }
            .buttonStyle(.plain)
            .help(language.resolved == .zhHans ? "打开作者 GitHub 主页" : "Open the author's GitHub profile")
        }
    }

    private func authorLinkLabel(text: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .contentShape(Rectangle())
    }

    private var collapsedSidebar: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(CDTheme.dockerBlue, in: RoundedRectangle(cornerRadius: 8))
                .padding(.top, 10)

            Circle()
                .fill(runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember)
                .frame(width: 9, height: 9)

            Divider()
                .overlay(CDTheme.separator)
                .padding(.vertical, 4)

            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(AppSection.allCases) { section in
                        Button {
                            selection = section
                        } label: {
                            Image(systemName: section.symbolName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(selection == section ? .white : secondaryText)
                                .frame(width: 40, height: 38)
                                .background(selection == section ? CDTheme.dockerBlue : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: .infinity)
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                        .help(section.title(language: language))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.never)

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(width: 60)
    }

    private var sidebarBackground: Color {
        colorScheme == .dark ? CDTheme.sidebar : CDTheme.appBackground
    }

    private var sidebarCardBackground: Color {
        colorScheme == .dark ? CDTheme.sidebarElevated : CDTheme.panelSurface
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.58) : .secondary
    }
}

private struct SidebarGroup<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(1.15)
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.42) : .secondary)
                .padding(.horizontal, 10)
            content
        }
    }
}

private struct SidebarNavButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var section: AppSection
    var language: AppLanguage
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? .white : secondaryText)

                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title(language: language))
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(section.subtitle(language: language))
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white.opacity(0.76) : secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isSelected ? .white : primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? CDTheme.dockerBlue : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(language.resolved == .zhHans ? "打开\(section.title(language: language))" : "Open \(section.title(language: language))")
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white.opacity(0.78) : .primary
    }

    private var secondaryText: Color {
        colorScheme == .dark ? .white.opacity(0.50) : .secondary
    }
}
