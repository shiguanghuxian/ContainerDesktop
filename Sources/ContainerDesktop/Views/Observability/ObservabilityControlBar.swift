import SwiftUI

struct ObservabilityControlBar: View {
    @Environment(\.appLanguage) private var language
    @Binding var searchText: String
    @Binding var logFilterText: String
    @Binding var logSource: ObservabilityLogSource
    @Binding var logLines: String
    @Binding var systemLogLast: String
    @Binding var composeScope: ObservabilityComposeScope
    @Binding var statsSort: ObservabilityStatsSort
    @Binding var onlyRunning: Bool
    @Binding var autoRefresh: Bool
    @Binding var refreshInterval: String
    var composeScopes: [ObservabilityComposeScope]
    var composeScopeTitle: (ObservabilityComposeScope) -> String
    var composeScopeDisabled: Bool
    var filteredCount: Int

    private var isSystemLogSource: Bool {
        logSource == .system
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    logSourcePicker
                        .frame(width: 360)
                    logWindowControl
                    Spacer(minLength: 12)
                    Text(language.itemCount(filteredCount))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    logSourcePicker
                    HStack(spacing: 12) {
                        logWindowControl
                        Spacer()
                        Text(language.itemCount(filteredCount))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    searchField(
                        title: language.t(.search),
                        systemImage: "magnifyingglass",
                        text: $searchText,
                        width: 220
                    )
                    searchField(
                        title: language.resolved == .zhHans ? "过滤日志" : "Filter logs",
                        systemImage: "line.3.horizontal.decrease.circle",
                        text: $logFilterText,
                        width: 220
                    )
                    composePicker
                    statsSortPicker
                    Toggle(language.t(.onlyRunning), isOn: $onlyRunning)
                        .toggleStyle(.switch)
                    autoRefreshControls
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        searchField(
                            title: language.t(.search),
                            systemImage: "magnifyingglass",
                            text: $searchText
                        )
                        searchField(
                            title: language.resolved == .zhHans ? "过滤日志" : "Filter logs",
                            systemImage: "line.3.horizontal.decrease.circle",
                            text: $logFilterText
                        )
                    }
                    HStack(spacing: 10) {
                        composePicker
                        statsSortPicker
                        Toggle(language.t(.onlyRunning), isOn: $onlyRunning)
                            .toggleStyle(.switch)
                        autoRefreshControls
                    }
                }
            }
        }
        .padding(12)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var logSourcePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(language.resolved == .zhHans ? "日志类型" : "Log source")
            ThemedSegmentedPicker(
                options: ObservabilityLogSource.allCases,
                selection: $logSource,
                title: { $0.title(language: language) }
            )
        }
    }

    @ViewBuilder
    private var logWindowControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(isSystemLogSource ? "container system logs --last" : "container logs -n")
            TextField(isSystemLogSource ? "5m" : "120", text: isSystemLogSource ? $systemLogLast : $logLines)
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
        }
    }

    private var composePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(language.resolved == .zhHans ? "Compose 范围" : "Compose scope")
            Picker(language.resolved == .zhHans ? "Compose 范围" : "Compose Scope", selection: $composeScope) {
                ForEach(composeScopes) { scope in
                    Text(composeScopeTitle(scope)).tag(scope)
                }
            }
            .labelsHidden()
            .frame(width: 190)
            .disabled(composeScopeDisabled)
        }
    }

    private var statsSortPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(language.resolved == .zhHans ? "Stats 排序" : "Stats sort")
            Picker(language.resolved == .zhHans ? "排序" : "Sort", selection: $statsSort) {
                ForEach(ObservabilityStatsSort.allCases) { sort in
                    Text(sort.title(language: language)).tag(sort)
                }
            }
            .labelsHidden()
            .frame(width: 132)
        }
    }

    private var autoRefreshControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(language.resolved == .zhHans ? "刷新" : "Refresh")
            HStack(spacing: 8) {
                Toggle(language.resolved == .zhHans ? "自动" : "Auto", isOn: $autoRefresh)
                    .toggleStyle(.switch)
                TextField("10s", text: $refreshInterval)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 58)
                    .disabled(!autoRefresh)
            }
        }
    }

    private func searchField(title: String, systemImage: String, text: Binding<String>, width: CGFloat? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .frame(width: width)
        .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
