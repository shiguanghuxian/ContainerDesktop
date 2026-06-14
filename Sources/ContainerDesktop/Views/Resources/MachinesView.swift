import SwiftUI

struct MachinesView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @State private var searchText = ""
    @State private var onlyRunning = false
    @State private var showCreatePopover = false
    @State private var newMachineName = ""
    @State private var newMachineImage = "alpine:3.22"
    @State private var useCustomMachineImage = false
    @State private var customMachineImage = ""
    @State private var useAutoMachineName = true
    @State private var useAutoMachineCPUs = true
    @State private var newMachineCPUs = 4
    @State private var newMachineMemory = ""
    @State private var newMachineHomeMount = MachineHomeMountOption.rw
    @State private var newMachineSetDefault = false
    @State private var newMachineNoBoot = false
    @State private var detailID: String?
    @State private var drawerID: String?
    @State private var drawerMode: DetailDrawerMode = .overview
    @State private var pendingDelete: MachineSummary?
    @State private var createMachineFormError: String?
    @State private var isSubmittingCreateMachine = false

    private var filteredMachines: [MachineSummary] {
        let query = searchText.trimmed.lowercased()
        let base = onlyRunning ? runtimeStore.machines.filter(\.isRunning) : runtimeStore.machines
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.id.lowercased().contains(query)
                || $0.status.lowercased().contains(query)
                || $0.ipAddressText.lowercased().contains(query)
        }
    }

    private var detailMachine: MachineSummary? {
        guard let detailID else { return nil }
        return runtimeStore.machines.first { $0.id == detailID }
    }

    private var drawerMachine: MachineSummary? {
        guard let drawerID else { return nil }
        return runtimeStore.machines.first { $0.id == drawerID }
    }

    private var imageChoices: [String] {
        FormPresetOptions.choices(
            current: newMachineImage,
            suggestions: FormPresetOptions.machineImages
        )
    }

    private var currentMachineImage: String {
        useCustomMachineImage ? customMachineImage : newMachineImage
    }

    private var isCreateMachineBusy: Bool {
        isSubmittingCreateMachine || runtimeStore.isOperationActive(RuntimeOperationKey.machineCreate)
    }

    private var automaticMachineName: String {
        MachineNameGenerator.automaticName(
            for: currentMachineImage,
            existingIDs: runtimeStore.machines.map(\.id)
        )
    }

    var body: some View {
        Group {
            if let machine = detailMachine {
                MachineDetailPage(
                    runtimeStore: runtimeStore,
                    machineID: detailID ?? machine.id,
                    isPresented: Binding(
                        get: { detailID != nil },
                        set: { if !$0 { detailID = nil } }
                    )
                )
            } else {
                DrawerPageLayout(isDrawerPresented: drawerMachine != nil, onDismiss: {
                    drawerID = nil
                }) {
                    pageContent
                } drawer: {
                    if let drawerMachine {
                        DetailDrawer(
                            mode: $drawerMode,
                            title: drawerMachine.id,
                            subtitle: drawerMachine.statusText,
                            systemImage: "desktopcomputer",
                            rawText: machineRawSummary(drawerMachine),
                            onClose: { drawerID = nil }
                        ) {
                            MachineDrawerOverview(machine: drawerMachine)
                        }
                    }
                }
            }
        }
        .alert("删除 Machine？", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            if let machine = pendingDelete {
                Button(language.t(.delete), role: .destructive) {
                    pendingDelete = nil
                    Task { await runtimeStore.deleteMachine(machine.id) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 Machine \(pendingDelete?.id ?? "所选 Machine")，包括它的持久化存储。")
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: language.t(.machines),
                subtitle: language.t(.machinesSubtitle),
                systemImage: "desktopcomputer"
            ) {
                HStack(spacing: 8) {
                    Button {
                        createMachineFormError = nil
                        showCreatePopover = true
                    } label: {
                        if runtimeStore.isOperationActive(RuntimeOperationKey.machineCreate) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(language.resolved == .zhHans ? "创建中" : "Creating")
                            }
                        } else {
                            Label(language.t(.createMachine), systemImage: "plus.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeStore.activeOperationKey != nil)
                    .sheet(isPresented: $showCreatePopover) {
                        createMachineForm
                    }

                    Button {
                        Task { await runtimeStore.refreshAll() }
                    } label: {
                        Label(language.t(.refresh), systemImage: "arrow.clockwise")
                    }
                }
            }

            ResourceToolbar(searchText: $searchText, placeholder: language.t(.search)) {
                Toggle(language.t(.onlyRunning), isOn: $onlyRunning)
                    .toggleStyle(.switch)
                Text(language.itemCount(filteredMachines.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if filteredMachines.isEmpty {
                ResourceTable {
                    machineHeader
                } rows: {
                    EmptyStateView(
                        title: language.t(.noMachines),
                        message: language.resolved == .zhHans ? "从 OCI 镜像创建一个持久 Linux 环境。" : "Create a persistent Linux environment from an OCI image.",
                        systemImage: "desktopcomputer"
                    )
                    .padding(18)
                }
            } else {
                ResourceTable {
                    machineHeader
                } rows: {
                    ForEach(filteredMachines) { machine in
                        ResourceTableRow(isSelected: detailID == machine.id || drawerID == machine.id) {
                            Button {
                                openMachineDetail(machine)
                            } label: {
                                HStack(spacing: 12) {
                                    ResourceStatusDot(tint: machine.isRunning ? CDTheme.lime : .secondary)

                                    Text(machine.id)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                                    Text(machine.ipAddressText)
                                        .font(.callout.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .frame(width: 116, alignment: .leading)

                                    Text("\(machine.cpus)")
                                        .font(.callout.monospacedDigit())
                                        .frame(width: 48, alignment: .trailing)

                                    Text(machine.memoryDisplay)
                                        .font(.callout.monospacedDigit())
                                        .frame(width: 88, alignment: .trailing)

                                    Text(machine.diskSizeDisplay)
                                        .font(.callout.monospacedDigit())
                                        .frame(width: 86, alignment: .trailing)

                                    Text(machine.statusText)
                                        .lineLimit(1)
                                        .frame(width: 76, alignment: .leading)

                                    Image(systemName: machine.isDefault ? "star.fill" : "star")
                                        .foregroundStyle(machine.isDefault ? .yellow : .secondary)
                                        .frame(width: 42)
                                        .help(language.t(.defaultMachine))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: 8) {
                                let startStopKey = machine.isRunning
                                    ? RuntimeOperationKey.machineStop(machine.id)
                                    : RuntimeOperationKey.machineBoot(machine.id)
                                RowActionButton(
                                    systemImage: machine.isRunning ? "stop.fill" : "play.fill",
                                    isLoading: runtimeStore.isOperationActive(startStopKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(startStopKey)
                                ) {
                                    if machine.isRunning {
                                        Task { await runtimeStore.stopMachine(machine.id) }
                                    } else {
                                        Task { await runtimeStore.bootMachine(machine.id) }
                                    }
                                }
                                RowActionButton(systemImage: "terminal", tint: machine.isRunning ? CDTheme.dockerBlue : .secondary) {
                                    openMachineTerminal(machine)
                                }
                                let defaultKey = RuntimeOperationKey.machineSetDefault(machine.id)
                                RowActionButton(
                                    systemImage: machine.isDefault ? "star.fill" : "star",
                                    isLoading: runtimeStore.isOperationActive(defaultKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(defaultKey)
                                ) {
                                    Task { await runtimeStore.setDefaultMachine(machine.id) }
                                }
                                RowActionButton(systemImage: "sidebar.right") {
                                    openMachineDrawer(machine)
                                }
                                let deleteKey = RuntimeOperationKey.machineDelete(machine.id)
                                DestructiveRowActionButton(
                                    isLoading: runtimeStore.isOperationActive(deleteKey),
                                    isDisabled: runtimeStore.activeOperationKey != nil && !runtimeStore.isOperationActive(deleteKey)
                                ) {
                                    pendingDelete = machine
                                }
                            }
                            .frame(width: 176, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func openMachineDetail(_ machine: MachineSummary) {
        detailID = machine.id
    }

    private func openMachineDrawer(_ machine: MachineSummary) {
        drawerID = machine.id
        drawerMode = .overview
    }

    private func openMachineTerminal(_ machine: MachineSummary) {
        guard machine.isRunning else {
            runtimeStore.errorMessage = language.resolved == .zhHans ? "Machine 未运行，无法进入终端。" : "The machine is not running."
            return
        }
        do {
            try SystemTerminalLauncher.openMachineShell(id: machine.id)
        } catch {
            runtimeStore.errorMessage = error.localizedDescription
        }
    }

    private func machineRawSummary(_ machine: MachineSummary) -> String {
        guard let data = try? JSONEncoder.containerDesktop.encode(machine),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private var machineHeader: some View {
        HStack(spacing: 12) {
            ResourceTableHeaderLabel(title: "", width: 20)
            ResourceTableHeaderLabel(title: language.t(.name))
            ResourceTableHeaderLabel(title: "IP", width: 116)
            ResourceTableHeaderLabel(title: "CPU", width: 48, alignment: .trailing)
            ResourceTableHeaderLabel(title: "Memory", width: 88, alignment: .trailing)
            ResourceTableHeaderLabel(title: "Disk", width: 86, alignment: .trailing)
            ResourceTableHeaderLabel(title: language.t(.status), width: 76)
            ResourceTableHeaderLabel(title: language.t(.defaultMachine), width: 42, alignment: .center)
            ResourceTableHeaderLabel(title: language.t(.actions), width: 176, alignment: .trailing)
        }
    }

    private var createMachineForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t(.createMachine))
                .font(.headline)

            Toggle(language.resolved == .zhHans ? "自动命名" : "Automatic name", isOn: $useAutoMachineName)
                .toggleStyle(.switch)
                .disabled(isCreateMachineBusy)

            if useAutoMachineName {
                Label(automaticMachineName, systemImage: "tag")
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 340, alignment: .leading)
            } else {
                TextField(language.t(.name), text: $newMachineName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 340)
                    .disabled(isCreateMachineBusy)
            }

            Picker(language.t(.image), selection: $newMachineImage) {
                ForEach(imageChoices, id: \.self) { reference in
                    Text(reference).tag(reference)
                }
            }
            .frame(width: 340)
            .disabled(useCustomMachineImage || isCreateMachineBusy)

            Toggle(language.resolved == .zhHans ? "使用自定义镜像引用" : "Use custom image reference", isOn: $useCustomMachineImage)
                .toggleStyle(.switch)
                .disabled(isCreateMachineBusy)
                .onChange(of: useCustomMachineImage) { _, enabled in
                    if enabled, customMachineImage.trimmed.isEmpty {
                        customMachineImage = newMachineImage
                    }
                    createMachineFormError = nil
                }

            TextField("local/ubuntu-machine:latest", text: $customMachineImage)
                .textFieldStyle(.roundedBorder)
                .frame(width: 340)
                .disabled(!useCustomMachineImage || isCreateMachineBusy)

            StatusBanner(
                text: language.resolved == .zhHans
                    ? "下拉只提供推荐 Machine 镜像。自定义镜像需要包含可执行的 /sbin/init，普通容器镜像会被创建前校验拦截。"
                    : "The picker only lists recommended machine images. Custom images must include an executable /sbin/init and are validated before create.",
                systemImage: "info.circle",
                tint: CDTheme.dockerBlue
            )
            .frame(width: 340)

            if isCreateMachineBusy {
                StatusBanner(
                    text: language.resolved == .zhHans ? "正在校验镜像并创建 Machine..." : "Validating image and creating machine...",
                    systemImage: "hourglass",
                    tint: CDTheme.dockerBlue
                )
                .frame(width: 340)
            }

            if let createMachineFormError {
                StatusBanner(text: createMachineFormError, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                    .frame(width: 340)
            }

            Toggle(language.resolved == .zhHans ? "自动 CPU" : "Automatic CPUs", isOn: $useAutoMachineCPUs)
                .toggleStyle(.switch)
                .disabled(isCreateMachineBusy)

            Stepper("CPUs \(newMachineCPUs)", value: $newMachineCPUs, in: 1...64)
                .disabled(useAutoMachineCPUs || isCreateMachineBusy)
                .frame(width: 340)

            Picker("Memory", selection: $newMachineMemory) {
                Text(language.resolved == .zhHans ? "自动" : "Automatic").tag("")
                ForEach(FormPresetOptions.machineMemorySizes, id: \.self) { size in
                    Text(size).tag(size)
                }
            }
            .labelsHidden()
            .frame(width: 340)
            .disabled(isCreateMachineBusy)

            ThemedSegmentedPicker(
                options: MachineHomeMountOption.allCases,
                selection: $newMachineHomeMount,
                title: { $0.title }
            )
            .frame(width: 340)
            .disabled(isCreateMachineBusy)

            Toggle(language.t(.defaultMachine), isOn: $newMachineSetDefault)
                .disabled(isCreateMachineBusy)
            Toggle(language.resolved == .zhHans ? "创建后不启动" : "Do not boot after create", isOn: $newMachineNoBoot)
                .disabled(isCreateMachineBusy)

            HStack {
                Spacer()
                Button("取消") {
                    createMachineFormError = nil
                    showCreatePopover = false
                }
                .disabled(isCreateMachineBusy)
                Button(language.t(.create)) {
                    self.submitCreateMachine()
                }
                .buttonStyle(.borderedProminent)
                .disabled(runtimeStore.activeOperationKey != nil || isSubmittingCreateMachine)
            }
            .frame(width: 340)
        }
        .padding(16)
    }

    private func submitCreateMachine() {
        let image = currentMachineImage.trimmed
        guard !image.isEmpty else {
            createMachineFormError = language.resolved == .zhHans ? "镜像不能为空。" : "Image cannot be empty."
            return
        }

        createMachineFormError = nil
        isSubmittingCreateMachine = true
        let name = useAutoMachineName ? automaticMachineName : newMachineName
        let cpus = useAutoMachineCPUs ? nil : String(newMachineCPUs)
        let memory = newMachineMemory
        let homeMount = newMachineHomeMount.rawValue
        let setDefault = newMachineSetDefault
        let noBoot = newMachineNoBoot

        Task { @MainActor in
            let succeeded = await runtimeStore.createMachine(
                name: name,
                image: image,
                cpus: cpus,
                memory: memory,
                homeMount: homeMount,
                setDefault: setDefault,
                noBoot: noBoot
            )
            isSubmittingCreateMachine = false
            if succeeded {
                resetCreateMachineForm()
                showCreatePopover = false
            } else {
                createMachineFormError = runtimeStore.errorMessage
                    ?? (language.resolved == .zhHans ? "创建 Machine 失败。" : "Failed to create machine.")
            }
        }
    }

    private func resetCreateMachineForm() {
        newMachineName = ""
        newMachineImage = "alpine:3.22"
        useCustomMachineImage = false
        customMachineImage = ""
        useAutoMachineName = true
        useAutoMachineCPUs = true
        newMachineCPUs = 4
        newMachineMemory = ""
        newMachineSetDefault = false
        newMachineNoBoot = false
        createMachineFormError = nil
    }
}

private struct MachineDrawerOverview: View {
    @Environment(\.appLanguage) private var language
    var machine: MachineSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DetailSection(title: language.resolved == .zhHans ? "Machine" : "Machine") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.status), value: machine.statusText)
                    DetailInfoRow(title: "IP", value: machine.ipAddressText, monospaced: true)
                    DetailInfoRow(title: "CPU", value: "\(machine.cpus)")
                    DetailInfoRow(title: "Memory", value: machine.memoryDisplay)
                    DetailInfoRow(title: "Disk", value: machine.diskSizeDisplay)
                    DetailInfoRow(title: language.t(.defaultMachine), value: machine.isDefault ? yesText : noText)
                }
            }

            DetailSection(title: language.resolved == .zhHans ? "基础信息" : "Basics") {
                DetailInfoCard {
                    DetailInfoRow(title: language.t(.name), value: machine.id, monospaced: true)
                    DetailInfoRow(title: language.t(.created), value: machine.createdText)
                }
            }
        }
    }

    private var yesText: String {
        language.resolved == .zhHans ? "是" : "Yes"
    }

    private var noText: String {
        language.resolved == .zhHans ? "否" : "No"
    }
}
