import SwiftUI

struct MachineDetailPage: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    var machineID: String
    @Binding var isPresented: Bool

    @State private var detailStore: MachineDetailStore
    @State private var isConfirmingDelete = false
    @State private var isEditingConfig = false

    init(runtimeStore: RuntimeStore, machineID: String, isPresented: Binding<Bool>) {
        self.runtimeStore = runtimeStore
        self.machineID = machineID
        _isPresented = isPresented
        _detailStore = State(initialValue: MachineDetailStore(machineID: machineID))
    }

    private var resolvedMachine: MachineSummary? {
        runtimeStore.machines.first(where: { $0.id == machineID })
    }

    var body: some View {
        Group {
            if let machine = resolvedMachine {
                SecondaryDetailPageContainer {
                    VStack(spacing: 12) {
                        MachineDetailHeaderView(
                            machine: machine,
                            inspection: detailStore.inspection,
                            isConfigSaving: runtimeStore.isOperationActive(RuntimeOperationKey.machineConfig(machine.id)),
                            onBack: { closeDetail() },
                            onStartStop: { startStop(machine) },
                            onSetDefault: { setDefault(machine) },
                            onEditConfig: { isEditingConfig = true },
                            onDelete: { isConfirmingDelete = true }
                        )

                        MachineDetailTabBar(selection: $detailStore.selectedTab)

                        tabContent(machine: machine)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .task(id: machine.id) {
                    await detailStore.bootstrap()
                }
                .onChange(of: detailStore.selectedTab) { _, tab in
                    guard tab == .files else { return }
                    Task { await detailStore.loadFilesIfNeeded() }
                }
                .onDisappear {
                    detailStore.stopAll()
                }
                .sheet(isPresented: $isEditingConfig) {
                    MachineConfigEditSheet(
                        runtimeStore: runtimeStore,
                        machine: machine,
                        inspection: detailStore.inspection,
                        onWillRestart: {
                            detailStore.stopAll()
                        }
                    ) {
                        await detailStore.refreshInspect()
                    }
                }
                .alert("删除 Machine？", isPresented: $isConfirmingDelete) {
                    Button(language.t(.delete), role: .destructive) {
                        delete(machine)
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("将删除 Machine \(machine.id)，包括它的持久化存储。")
                }
            } else {
                ContentUnavailableView(
                    language.resolved == .zhHans ? "Machine 不可用" : "Machine unavailable",
                    systemImage: "desktopcomputer"
                )
                .task { closeDetail() }
            }
        }
    }

    @ViewBuilder
    private func tabContent(machine: MachineSummary) -> some View {
        switch detailStore.selectedTab {
        case .overview:
            MachineOverviewTabView(machine: machine, inspection: detailStore.inspection)
        case .logs:
            MachineLogsTabView(store: detailStore)
        case .inspect:
            MachineInspectTabView(store: detailStore)
        case .files:
            MachineFilesTabView(store: detailStore)
        case .exec:
            MachineExecTabView(store: detailStore, machine: machine) {
                await runtimeStore.refreshAll()
                await detailStore.refreshInspect()
            }
        case .run:
            MachineRunTabView(store: detailStore, machine: machine) {
                await runtimeStore.refreshAll()
                await detailStore.refreshInspect()
            }
        case .settings:
            MachineSettingsTabView(runtimeStore: runtimeStore, store: detailStore, machine: machine) {
                await runtimeStore.refreshAll()
            }
        }
    }

    private func startStop(_ machine: MachineSummary) {
        Task {
            if machine.isRunning {
                detailStore.stopTerminal()
                await runtimeStore.stopMachine(machine.id)
            } else {
                await runtimeStore.bootMachine(machine.id)
            }
            await detailStore.refreshInspect()
            await detailStore.loadLogs()
        }
    }

    private func setDefault(_ machine: MachineSummary) {
        Task {
            await runtimeStore.setDefaultMachine(machine.id)
            await detailStore.refreshInspect()
        }
    }

    private func delete(_ machine: MachineSummary) {
        Task {
            detailStore.stopAll()
            await runtimeStore.deleteMachine(machine.id)
            closeDetail()
        }
    }

    private func closeDetail() {
        detailStore.stopAll()
        isPresented = false
    }
}
