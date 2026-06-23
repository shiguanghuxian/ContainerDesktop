import SwiftUI

struct SettingsView: View {
    @Bindable var systemConfigStore: SystemConfigStore
    @Bindable var launchAtLoginStore: LaunchAtLoginStore

    var body: some View {
        ZStack {
            TechBackdrop().ignoresSafeArea()

            SystemConfigEditorView(
                systemConfigStore: systemConfigStore,
                launchAtLoginStore: launchAtLoginStore
            )
                .padding(20)
                .frame(minWidth: 1040, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 1040, minHeight: 720)
    }
}
