import SwiftUI

struct MachineOverviewTabView: View {
    @Environment(\.appLanguage) private var language
    var machine: MachineSummary
    var inspection: MachineInspection?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: language.t(.machine)) {
                    DetailInfoCard {
                        DetailInfoRow(title: language.t(.status), value: machine.statusText)
                        DetailInfoRow(title: language.t(.defaultMachine), value: machine.isDefault ? "Yes" : "No")
                        DetailInfoRow(title: "IP", value: machine.ipAddressText, monospaced: true)
                        DetailInfoRow(title: language.t(.created), value: inspection?.createdText ?? machine.createdText)
                        DetailInfoRow(title: "Started", value: inspection?.startedText ?? "—")
                        if let containerId = inspection?.containerId {
                            DetailInfoRow(title: "Container ID", value: containerId, monospaced: true)
                        }
                    }
                }

                DetailSection(title: language.resolved == .zhHans ? "镜像与用户" : "Image and User") {
                    DetailInfoCard {
                        DetailInfoRow(title: language.t(.image), value: inspection?.image.referenceText ?? "—")
                        DetailInfoRow(title: "Platform", value: inspection?.platformText ?? "—")
                        DetailInfoRow(title: language.resolved == .zhHans ? "用户" : "User", value: inspection?.userSetup.username ?? "—")
                        DetailInfoRow(title: "Home", value: inspection?.userSetup.home ?? "—", monospaced: true)
                    }
                }

                DetailSection(title: language.t(.resources)) {
                    DetailInfoCard {
                        DetailInfoRow(title: "CPUs", value: "\(inspection?.cpus ?? machine.cpus)")
                        DetailInfoRow(title: "Memory", value: inspection?.memoryDisplay ?? machine.memoryDisplay)
                        DetailInfoRow(title: "Disk", value: inspection?.diskSizeDisplay ?? machine.diskSizeDisplay)
                        DetailInfoRow(title: language.t(.homeMount), value: inspection?.homeMount ?? "—")
                    }
                }
            }
            .padding(1)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
