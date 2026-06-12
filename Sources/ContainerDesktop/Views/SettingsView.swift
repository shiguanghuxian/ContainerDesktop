import SwiftUI

struct SettingsView: View {
    @Bindable var systemConfigStore: SystemConfigStore

    var body: some View {
        ScrollView {
            SystemConfigEditorView(systemConfigStore: systemConfigStore)
                .padding(20)
                .frame(minWidth: 1040, alignment: .topLeading)
        }
        .frame(minWidth: 1040, minHeight: 720)
        .background(.thickMaterial)
    }
}
