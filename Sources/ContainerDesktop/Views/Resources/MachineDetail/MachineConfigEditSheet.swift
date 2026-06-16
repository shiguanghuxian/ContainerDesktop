import SwiftUI

struct MachineConfigEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    var runtimeStore: RuntimeStore
    var machine: MachineSummary
    var inspection: MachineInspection?
    var onWillRestart: () async -> Void = {}
    var onSaved: () async -> Void = {}

    var body: some View {
        MachineConfigEditorPanel(
            runtimeStore: runtimeStore,
            machine: machine,
            inspection: inspection,
            title: language.resolved == .zhHans ? "编辑 Machine 配置" : "Edit Machine Configuration",
            restartAfterSave: true,
            dismissAfterSuccess: true,
            onCancel: { dismiss() },
            onWillRestart: onWillRestart,
            onSaved: onSaved
        )
        .padding(16)
        .frame(width: 430)
    }
}

struct MachineConfigEditorPanel: View {
    @Environment(\.appLanguage) private var language
    var runtimeStore: RuntimeStore
    var machine: MachineSummary
    var inspection: MachineInspection?
    var title: String?
    var restartAfterSave = true
    var dismissAfterSuccess = false
    var onCancel: (() -> Void)?
    var onWillRestart: () async -> Void
    var onSaved: () async -> Void

    @State private var loadedInspection: MachineInspection?
    @State private var inspectionLoadError: String?
    @State private var isLoadingInspection = false
    @State private var baseline: MachineConfigurationUpdate
    @State private var draft: MachineConfigurationUpdate
    @State private var statusText: String?
    @State private var errorText: String?

    init(
        runtimeStore: RuntimeStore,
        machine: MachineSummary,
        inspection: MachineInspection? = nil,
        title: String? = nil,
        restartAfterSave: Bool = true,
        dismissAfterSuccess: Bool = false,
        onCancel: (() -> Void)? = nil,
        onWillRestart: @escaping () async -> Void = {},
        onSaved: @escaping () async -> Void = {}
    ) {
        self.runtimeStore = runtimeStore
        self.machine = machine
        self.inspection = inspection
        self.title = title
        self.restartAfterSave = restartAfterSave
        self.dismissAfterSuccess = dismissAfterSuccess
        self.onCancel = onCancel
        self.onWillRestart = onWillRestart
        self.onSaved = onSaved
        let initial = MachineConfigurationUpdate(machine: machine, inspection: inspection)
        _baseline = State(initialValue: initial)
        _draft = State(initialValue: initial)
    }

    private var effectiveInspection: MachineInspection? {
        inspection ?? loadedInspection
    }

    private var sourceUpdate: MachineConfigurationUpdate? {
        guard let effectiveInspection else { return nil }
        return MachineConfigurationUpdate(machine: machine, inspection: effectiveInspection)
    }

    private var isSaving: Bool {
        runtimeStore.isOperationActive(RuntimeOperationKey.machineConfig(machine.id))
    }

    private var isBlockedByOtherOperation: Bool {
        runtimeStore.activeOperationKey != nil && !isSaving
    }

    private var hasChanges: Bool {
        draft.hasChanges(comparedTo: baseline)
    }

    private var canSave: Bool {
        sourceUpdate != nil && hasChanges && !isSaving && !isBlockedByOtherOperation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            if let sourceUpdate {
                MachineConfigEditorFields(
                    machine: machine,
                    inspection: effectiveInspection,
                    baseline: sourceUpdate,
                    draft: $draft,
                    isDisabled: isSaving || isBlockedByOtherOperation,
                    onEdited: clearMessages
                )
            } else if isLoadingInspection {
                StatusBanner(
                    text: language.resolved == .zhHans ? "正在读取当前 Machine 配置..." : "Loading current Machine configuration...",
                    systemImage: "hourglass",
                    tint: CDTheme.dockerBlue
                )
            } else {
                StatusBanner(
                    text: inspectionLoadError ?? (language.resolved == .zhHans ? "无法读取当前 Machine 配置。" : "Unable to load current Machine configuration."),
                    systemImage: "exclamationmark.triangle",
                    tint: CDTheme.ember
                )
            }

            if !hasChanges, sourceUpdate != nil, statusText == nil, !isSaving {
                StatusBanner(
                    text: language.resolved == .zhHans ? "请选择要修改的配置。" : "Choose at least one setting to change.",
                    systemImage: "info.circle",
                    tint: .secondary
                )
            }

            if machine.isRunning {
                StatusBanner(
                    text: language.resolved == .zhHans ? "Machine 正在运行，保存后将自动重启使配置生效。" : "This Machine is running. Saving will restart it automatically so the settings take effect.",
                    systemImage: "bolt.trianglebadge.exclamationmark",
                    tint: CDTheme.ember
                )
            }

            if isSaving {
                StatusBanner(
                    text: runtimeStore.busyMessage ?? (language.resolved == .zhHans ? "正在保存 Machine 配置..." : "Saving Machine configuration..."),
                    systemImage: "hourglass",
                    tint: CDTheme.dockerBlue
                )
            }

            if let statusText {
                StatusBanner(text: statusText, systemImage: "checkmark.circle", tint: CDTheme.lime)
            }

            if let errorText {
                StatusBanner(text: errorText, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
            }

            HStack {
                if let onCancel {
                    Button(language.resolved == .zhHans ? "关闭" : "Close") {
                        onCancel()
                    }
                    .disabled(isSaving)
                    .help(language.resolved == .zhHans ? "关闭编辑配置窗口" : "Close configuration editor")
                }

                Spacer()

                Button {
                    save()
                } label: {
                    if isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(language.resolved == .zhHans ? "保存中" : "Saving")
                        }
                    } else {
                        Label(language.t(.save), systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .help(language.resolved == .zhHans ? "保存 Machine 配置" : "Save Machine configuration")
            }
        }
        .task(id: machine.id) {
            await loadInspectionIfNeeded()
        }
        .onChange(of: sourceUpdate) { _, nextUpdate in
            guard let nextUpdate, !hasChanges, !isSaving else { return }
            baseline = nextUpdate
            draft = nextUpdate
        }
    }

    private func clearMessages() {
        statusText = nil
        errorText = nil
    }

    private func loadInspectionIfNeeded() async {
        guard inspection == nil, loadedInspection == nil, !isLoadingInspection else { return }
        isLoadingInspection = true
        inspectionLoadError = nil
        defer { isLoadingInspection = false }

        do {
            guard let loaded = try await runtimeStore.loadMachineInspection(id: machine.id) else {
                inspectionLoadError = language.resolved == .zhHans ? "Inspect 未返回 Machine 配置。" : "Inspect did not return Machine configuration."
                return
            }
            loadedInspection = loaded
            let nextUpdate = MachineConfigurationUpdate(machine: machine, inspection: loaded)
            if !hasChanges {
                baseline = nextUpdate
                draft = nextUpdate
            }
        } catch {
            inspectionLoadError = error.localizedDescription
        }
    }

    private func save() {
        guard hasChanges else {
            errorText = language.resolved == .zhHans ? "请至少修改一个配置项。" : "Change at least one setting."
            return
        }

        let update = draft
        Task { @MainActor in
            clearMessages()
            let shouldRestart = restartAfterSave && machine.isRunning
            let succeeded = await runtimeStore.updateMachineConfig(
                id: machine.id,
                update: update,
                restartIfRunning: restartAfterSave,
                onWillRestart: shouldRestart ? onWillRestart : nil
            )
            if succeeded {
                let savedBaseline = MachineConfigurationUpdate(cpus: update.cpus, homeMount: update.homeMount)
                baseline = savedBaseline
                draft = savedBaseline
                statusText = successMessage(restarted: shouldRestart)
                await onSaved()
                if dismissAfterSuccess {
                    onCancel?()
                }
            } else {
                errorText = runtimeStore.errorMessage ?? (language.resolved == .zhHans ? "保存 Machine 配置失败。" : "Failed to save Machine configuration.")
            }
        }
    }

    private func successMessage(restarted: Bool) -> String {
        if restarted {
            return language.resolved == .zhHans ? "配置已保存并已重启 Machine。" : "Configuration saved and the Machine was restarted."
        }
        return language.resolved == .zhHans ? "配置已保存，下次启动 Machine 后生效。" : "Configuration saved. It applies the next time the Machine starts."
    }
}

private struct MachineConfigEditorFields: View {
    @Environment(\.appLanguage) private var language
    var machine: MachineSummary
    var inspection: MachineInspection?
    var baseline: MachineConfigurationUpdate
    @Binding var draft: MachineConfigurationUpdate
    var isDisabled: Bool
    var onEdited: () -> Void

    private var cpuRange: ClosedRange<Int> {
        1...max(64, baseline.cpus, draft.cpus)
    }

    private var memorySelection: Binding<String> {
        Binding(
            get: { draft.memory ?? "" },
            set: { value in
                draft.memory = value.nilIfBlank
                onEdited()
            }
        )
    }

    private var cpuSelection: Binding<Int> {
        Binding(
            get: { draft.cpus },
            set: { value in
                draft.cpus = value
                onEdited()
            }
        )
    }

    private var homeMountSelection: Binding<MachineHomeMountOption> {
        Binding(
            get: { draft.homeMount },
            set: { value in
                draft.homeMount = value
                onEdited()
            }
        )
    }

    private var memoryChoices: [String] {
        FormPresetOptions.choices(
            current: draft.memory ?? "",
            suggestions: FormPresetOptions.machineMemorySizes
        )
        .filter { !$0.isEmpty }
    }

    private var currentMemoryText: String {
        inspection?.memoryDisplay ?? machine.memoryDisplay
    }

    private var currentHomeMountText: String {
        inspection?.homeMount ?? baseline.homeMount.rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailInfoCard {
                DetailInfoRow(title: language.t(.name), value: machine.id, monospaced: true)
                DetailInfoRow(title: language.t(.status), value: machine.statusText)
                DetailInfoRow(title: "Current CPUs", value: "\(baseline.cpus)")
                DetailInfoRow(title: "Current Memory", value: currentMemoryText)
                DetailInfoRow(title: language.t(.homeMount), value: currentHomeMountText)
            }

            DetailInfoCard {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("CPUs")
                            .foregroundStyle(.secondary)
                        Stepper("\(draft.cpus)", value: cpuSelection, in: cpuRange)
                            .frame(width: 180, alignment: .trailing)
                            .disabled(isDisabled)
                    }

                    GridRow {
                        Text("Memory")
                            .foregroundStyle(.secondary)
                        Picker("Memory", selection: memorySelection) {
                            Text(language.resolved == .zhHans ? "保持当前（\(currentMemoryText)）" : "Keep current (\(currentMemoryText))")
                                .tag("")
                            ForEach(memoryChoices, id: \.self) { size in
                                Text(size).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .disabled(isDisabled)
                    }

                    GridRow {
                        Text(language.t(.homeMount))
                            .foregroundStyle(.secondary)
                        ThemedSegmentedPicker(
                            options: MachineHomeMountOption.allCases,
                            selection: homeMountSelection,
                            title: { $0.title }
                        )
                        .frame(width: 220)
                        .disabled(isDisabled)
                    }
                }
            }
        }
    }
}
