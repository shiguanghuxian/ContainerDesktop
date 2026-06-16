import SwiftUI

struct MachineSettingsTabView: View {
    @Environment(\.appLanguage) private var language
    var runtimeStore: RuntimeStore
    @Bindable var store: MachineDetailStore
    var machine: MachineSummary
    var onConfigSaved: () async -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DetailSection(title: language.t(.resources)) {
                    MachineConfigEditorPanel(
                        runtimeStore: runtimeStore,
                        machine: machine,
                        inspection: store.inspection,
                        title: nil,
                        onCancel: nil,
                        onWillRestart: {
                            store.stopAll()
                        }
                    ) {
                        await store.refreshInspect()
                        await onConfigSaved()
                    }
                }
            }
            .padding(1)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .thinScrollBars()
    }
}
