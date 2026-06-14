import SwiftUI

struct MachineSettingsTabView: View {
    @Environment(\.appLanguage) private var language
    @Bindable var store: MachineDetailStore
    var machine: MachineSummary
    var onConfigSaved: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: language.t(.resources)) {
                    DetailInfoCard {
                        DetailInfoRow(title: "Current CPUs", value: "\(store.inspection?.cpus ?? machine.cpus)")
                        DetailInfoRow(title: "Current Memory", value: store.inspection?.memoryDisplay ?? machine.memoryDisplay)
                        DetailInfoRow(title: language.t(.homeMount), value: store.inspection?.homeMount ?? store.homeMount.rawValue)

                        Divider()

                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                            GridRow {
                                Text("CPUs")
                                    .foregroundStyle(.secondary)
                                Stepper("\(store.configCPUs)", value: $store.configCPUs, in: 1...64)
                                    .frame(width: 160, alignment: .trailing)
                            }

                            GridRow {
                                Text("Memory")
                                    .foregroundStyle(.secondary)
                                Picker("Memory", selection: $store.configMemory) {
                                    Text(language.resolved == .zhHans ? "保持当前" : "Keep current").tag("")
                                    ForEach(FormPresetOptions.machineMemorySizes, id: \.self) { size in
                                        Text(size).tag(size)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                            }

                            GridRow {
                                Text(language.t(.homeMount))
                                    .foregroundStyle(.secondary)
                                ThemedSegmentedPicker(
                                    options: MachineHomeMountOption.allCases,
                                    selection: $store.homeMount,
                                    title: { $0.title }
                                )
                                .frame(width: 220)
                            }
                        }

                        HStack {
                            Text(language.resolved == .zhHans ? "配置变更在下次停启后生效。" : "Changes apply on the next stop and boot.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(language.t(.save)) {
                                Task {
                                    await store.saveConfig()
                                    await onConfigSaved()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if let status = store.configStatusText {
                    StatusBanner(text: status, systemImage: "checkmark.circle", tint: CDTheme.lime)
                }

                if let error = store.configError {
                    StatusBanner(text: error, systemImage: "exclamationmark.triangle", tint: CDTheme.ember)
                }
            }
            .padding(1)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
