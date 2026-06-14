import SwiftUI

struct SystemConfigEditorView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("containerdesktop.appearance") private var appearanceRaw = AppearancePreference.system.rawValue
    @AppStorage("containerdesktop.language") private var languageRaw = AppLanguage.system.rawValue
    @Bindable var systemConfigStore: SystemConfigStore

    @State private var selectedCategory: ConfigCategory = .general
    @State private var settingsSearch = ""

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { AppearancePreference(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .system },
            set: { languageRaw = $0.rawValue }
        )
    }

    private var machineUsesAutoCPUsBinding: Binding<Bool> {
        Binding(
            get: { systemConfigStore.config.machine.cpus == nil },
            set: { useAuto in
                systemConfigStore.config.machine.cpus = useAuto ? nil : (systemConfigStore.config.machine.cpus ?? 4)
            }
        )
    }

    private var machineCPUValueBinding: Binding<Int> {
        Binding(
            get: { systemConfigStore.config.machine.cpus ?? 4 },
            set: { systemConfigStore.config.machine.cpus = $0 }
        )
    }

    private var machineMemorySelectionBinding: Binding<String> {
        Binding(
            get: { systemConfigStore.config.machine.memory ?? "" },
            set: { systemConfigStore.config.machine.memory = $0.nilIfBlank }
        )
    }

    private var machineHomeMountSelectionBinding: Binding<String> {
        Binding(
            get: { systemConfigStore.config.machine.homeMount ?? "" },
            set: { systemConfigStore.config.machine.homeMount = $0.nilIfBlank }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            configToolbar

            if let errorMessage = systemConfigStore.errorMessage {
                StatusPill(title: errorMessage, systemImage: "exclamationmark.triangle", tint: .red)
            } else if let saveMessage = systemConfigStore.saveMessage {
                StatusPill(title: saveMessage, systemImage: "checkmark.circle", tint: CDTheme.lime)
            }

            HStack(alignment: .top, spacing: 0) {
                settingsSidebar
                    .frame(width: 260)

                Divider()

                VStack(alignment: .leading, spacing: 18) {
                    SettingsSectionHeader(
                        title: selectedCategory.title(language: language),
                        subtitle: selectedCategory.subtitle(language: language),
                        systemImage: selectedCategory.systemImage
                    )

                    selectedCategoryContent
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.separator)
            }

            Text(language.t(.configSavedHint))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .task {
            await systemConfigStore.load()
        }
    }

    private var configToolbar: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: "doc.badge.gearshape", tint: CDTheme.dockerBlue, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("container config.toml")
                    .font(.headline.weight(.semibold))
                Text(systemConfigStore.configPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                systemConfigStore.resetToDefaults()
            } label: {
                Label(language.t(.defaults), systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(CDSecondaryButtonStyle())

            Button {
                Task { await systemConfigStore.reload() }
            } label: {
                Label(language.t(.reload), systemImage: "arrow.clockwise")
            }
            .buttonStyle(CDSecondaryButtonStyle())

            Button {
                Task { await systemConfigStore.save() }
            } label: {
                Label(language.t(.save), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(systemConfigStore.isSaving)
        }
        .padding(14)
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(language.t(.search), text: $settingsSearch)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(CDTheme.inputSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(CDTheme.hairline)
            }
            .padding([.horizontal, .top], 14)

            VStack(spacing: 4) {
                ForEach(filteredCategories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 20)
                                .foregroundStyle(selectedCategory == category ? CDTheme.dockerBlue : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(category.title(language: language))
                                    .font(.callout.weight(.semibold))
                                Text(category.sidebarSubtitle(language: language))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(selectedCategory == category ? CDTheme.selectionSurface : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 14)

            Spacer(minLength: 0)
        }
    }

    private var filteredCategories: [ConfigCategory] {
        let query = settingsSearch.trimmed.lowercased()
        guard !query.isEmpty else { return ConfigCategory.allCases }
        return ConfigCategory.allCases.filter {
            $0.title(language: language).lowercased().contains(query)
                || $0.sidebarSubtitle(language: language).lowercased().contains(query)
        }
    }

    @ViewBuilder
    private var selectedCategoryContent: some View {
        switch selectedCategory {
        case .general:
            generalPane
        case .resources:
            resourcesPane
        case .network:
            networkPane
        case .registry:
            registryPane
        case .kernel:
            kernelPane
        case .runtime:
            runtimePane
        }
    }

    private var generalPane: some View {
        SettingsGroup(title: language.t(.appSettings), subtitle: "ContainerDesktop") {
            SettingsFormRow(title: language.t(.language), subtitle: "UI language") {
                ThemedSegmentedPicker(
                    options: AppLanguage.allCases,
                    selection: languageBinding,
                    title: { $0.displayName }
                )
                .frame(width: 360)
            }

            SettingsFormRow(title: language.t(.theme), subtitle: "Window appearance") {
                ThemedSegmentedPicker(
                    options: AppearancePreference.allCases,
                    selection: appearanceBinding,
                    title: { $0.title(language: language) }
                )
                .frame(width: 360)
            }
        }
    }

    private var resourcesPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGroup(title: language.t(.builder), subtitle: "[build]") {
                SettingsFormRow(title: "Rosetta", subtitle: "Enable x86_64 translation for build workloads") {
                    Toggle("", isOn: $systemConfigStore.config.build.rosetta)
                        .labelsHidden()
                }
                SettingsFormRow(title: "CPUs", subtitle: "Builder VM CPU count") {
                    Stepper("\(systemConfigStore.config.build.cpus)", value: $systemConfigStore.config.build.cpus, in: 1...64)
                        .frame(width: 180, alignment: .trailing)
                }
                SettingsFormRow(title: "Memory", subtitle: "Builder VM memory limit") {
                    Picker("Memory", selection: $systemConfigStore.config.build.memory) {
                        ForEach(FormPresetOptions.choices(current: systemConfigStore.config.build.memory, suggestions: FormPresetOptions.memorySizes), id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                SettingsFormRow(title: "Image", subtitle: "Builder image reference") {
                    Picker("Image", selection: $systemConfigStore.config.build.image) {
                        ForEach(FormPresetOptions.choices(current: systemConfigStore.config.build.image, suggestions: FormPresetOptions.builderImages), id: \.self) { image in
                            Text(image).tag(image)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 420)
                }
            }

            SettingsGroup(title: language.t(.containerDefaults), subtitle: "[container]") {
                SettingsFormRow(title: "CPUs", subtitle: "Default CPU count for new containers") {
                    Stepper("\(systemConfigStore.config.container.cpus)", value: $systemConfigStore.config.container.cpus, in: 1...64)
                        .frame(width: 180, alignment: .trailing)
                }
                SettingsFormRow(title: "Memory", subtitle: "Default memory for new containers") {
                    Picker("Memory", selection: $systemConfigStore.config.container.memory) {
                        ForEach(FormPresetOptions.choices(current: systemConfigStore.config.container.memory, suggestions: FormPresetOptions.memorySizes), id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
            }

            SettingsGroup(title: language.t(.machine), subtitle: "[machine]") {
                SettingsFormRow(title: "CPUs", subtitle: "Leave blank for automatic sizing") {
                    HStack(spacing: 12) {
                        Toggle(language.resolved == .zhHans ? "自动" : "Auto", isOn: machineUsesAutoCPUsBinding)
                            .toggleStyle(.switch)
                        Stepper("\(machineCPUValueBinding.wrappedValue)", value: machineCPUValueBinding, in: 1...64)
                            .disabled(machineUsesAutoCPUsBinding.wrappedValue)
                            .frame(width: 120, alignment: .trailing)
                    }
                }
                SettingsFormRow(title: "Memory", subtitle: "Leave blank for automatic sizing") {
                    Picker("Memory", selection: machineMemorySelectionBinding) {
                        Text(language.resolved == .zhHans ? "自动" : "Auto").tag("")
                        ForEach(FormPresetOptions.choices(current: systemConfigStore.config.machine.memory ?? "", suggestions: FormPresetOptions.machineMemorySizes), id: \.self) { size in
                            Text(size).tag(size)
                        }
                    }
                    .labelsHidden()
                        .frame(width: 180)
                }
                SettingsFormRow(title: "Home mount", subtitle: "rw, ro, or none") {
                    ThemedSegmentedPicker(
                        options: ["", "rw", "ro", "none"],
                        selection: machineHomeMountSelectionBinding,
                        title: { $0.isEmpty ? (language.resolved == .zhHans ? "默认" : "Default") : $0 }
                    )
                    .frame(width: 240)
                }
            }
        }
    }

    private var networkPane: some View {
        SettingsGroup(title: language.t(.networkSettings), subtitle: "[dns] / [network]") {
            SettingsFormRow(title: "DNS domain", subtitle: "Default local domain") {
                TextField("test", text: $systemConfigStore.config.dns.domain.orEmpty())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }
            SettingsFormRow(title: "IPv4 subnet", subtitle: "Default user network subnet") {
                TextField("192.168.64.0/24", text: $systemConfigStore.config.network.subnet.orEmpty())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }
            SettingsFormRow(title: "IPv6 subnet", subtitle: "Optional IPv6 prefix") {
                TextField("fd00::/64", text: $systemConfigStore.config.network.subnetv6.orEmpty())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }
        }
    }

    private var registryPane: some View {
        SettingsGroup(title: language.t(.registries), subtitle: "[registry]") {
            SettingsFormRow(title: "Domain", subtitle: "Default image registry domain") {
                Picker("Domain", selection: $systemConfigStore.config.registry.domain) {
                    ForEach(FormPresetOptions.choices(current: systemConfigStore.config.registry.domain, suggestions: FormPresetOptions.registries), id: \.self) { domain in
                        Text(domain).tag(domain)
                    }
                }
                .labelsHidden()
                .frame(width: 320)
            }
        }
    }

    private var kernelPane: some View {
        SettingsGroup(title: language.t(.kernel), subtitle: "[kernel]") {
            SettingsFormRow(title: "Binary path", subtitle: "Linux guest kernel path") {
                TextField("opt/kata/share/kata-containers/vmlinux...", text: $systemConfigStore.config.kernel.binaryPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 460)
            }
            SettingsFormRow(title: "URL", subtitle: "Kernel archive source") {
                TextField("https://...", text: $systemConfigStore.config.kernel.url)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 460)
            }
        }
    }

    private var runtimePane: some View {
        SettingsGroup(title: language.t(.runtime), subtitle: "[vminit]") {
            SettingsFormRow(title: "VM init image", subtitle: "vminitd image reference") {
                Picker("VM init image", selection: $systemConfigStore.config.vminit.image) {
                    ForEach(FormPresetOptions.choices(current: systemConfigStore.config.vminit.image, suggestions: FormPresetOptions.vminitImages), id: \.self) { image in
                        Text(image).tag(image)
                    }
                }
                .labelsHidden()
                .frame(width: 460)
            }
        }
    }
}

private enum ConfigCategory: String, CaseIterable, Identifiable {
    case general
    case resources
    case network
    case registry
    case kernel
    case runtime

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .resources: "cpu"
        case .network: "network"
        case .registry: "key.icloud"
        case .kernel: "memorychip"
        case .runtime: "terminal"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general: language.t(.general)
        case .resources: language.t(.resources)
        case .network: language.t(.networkSettings)
        case .registry: language.t(.registries)
        case .kernel: language.t(.kernel)
        case .runtime: language.t(.runtime)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .general: language.resolved == .zhHans ? "语言、主题和应用体验。" : "Language, theme, and app experience."
        case .resources: language.resolved == .zhHans ? "构建器、容器和虚拟机默认资源。" : "Builder, container, and machine resource defaults."
        case .network: language.resolved == .zhHans ? "DNS 域和默认网络子网。" : "DNS domain and default network subnets."
        case .registry: language.resolved == .zhHans ? "默认镜像仓库配置。" : "Default image registry configuration."
        case .kernel: language.resolved == .zhHans ? "Linux guest 内核路径和下载源。" : "Linux guest kernel path and source URL."
        case .runtime: language.resolved == .zhHans ? "VM init 镜像和运行时属性。" : "VM init image and runtime properties."
        }
    }

    func sidebarSubtitle(language: AppLanguage) -> String {
        switch self {
        case .general: "ContainerDesktop"
        case .resources: "[build] [container] [machine]"
        case .network: "[dns] [network]"
        case .registry: "[registry]"
        case .kernel: "[kernel]"
        case .runtime: "[vminit]"
        }
    }
}

private struct SettingsSectionHeader: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(systemImage: systemImage, tint: CDTheme.dockerBlue, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
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
                content
            }
        }
        .background(CDTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
    }
}

private struct SettingsFormRow<Control: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 230, alignment: .leading)

            Spacer(minLength: 12)

            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)

        Divider()
            .padding(.leading, 14)
    }
}
