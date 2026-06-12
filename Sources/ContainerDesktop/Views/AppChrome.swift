import AppKit
import SwiftUI

struct AppTopBar: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.openWindow) private var openWindow
    @Binding var searchText: String
    @Binding var isSidebarCollapsed: Bool
    var onSearchSubmit: () -> Void = {}
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore

    var body: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 1) {
                    Text("ContainerDesktop")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(language.t(.appSubtitle))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                }

                StatusPill(
                    title: runtimeStore.environment.systemRunning ? language.t(.engineRunning) : language.t(.engineStopped),
                    systemImage: runtimeStore.environment.systemRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember
                )
                .padding(.leading, 6)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.76))
                TextField(language.t(.search), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .onSubmit(onSearchSubmit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 300)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 6) {
                TopBarButton(systemImage: isSidebarCollapsed ? "sidebar.left" : "sidebar.leading") {
                    withAnimation(.snappy(duration: 0.18)) {
                        isSidebarCollapsed.toggle()
                    }
                }

                TopBarButton(systemImage: "arrow.clockwise") {
                    Task { await runtimeStore.refreshAll() }
                }

                TopBarButton(systemImage: runtimeStore.environment.systemRunning ? "stop.circle" : "play.circle") {
                    Task {
                        if runtimeStore.environment.systemRunning {
                            await runtimeStore.stopSystem()
                        } else {
                            await runtimeStore.startSystem()
                        }
                    }
                }

                TopBarButton(systemImage: "gearshape") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Text("C")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .padding(.leading, 94)
        .padding(.trailing, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(CDTheme.dockerBlue)
        .contentShape(Rectangle())
        .simultaneousGesture(WindowDragGesture())
        .allowsWindowActivationEvents(true)
    }
}

private struct TopBarButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct AppStatusBar: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember)
            Text(runtimeStore.environment.systemRunning ? language.t(.engineRunning) : language.t(.engineStopped))
                .font(.caption.weight(.semibold))
                .foregroundStyle(runtimeStore.environment.systemRunning ? CDTheme.lime : CDTheme.ember)

            Divider()
                .frame(height: 16)

            Text("\(language.t(.containers)) \(runtimeStore.containers.count)")
            Text("\(language.t(.images)) \(runtimeStore.images.count)")
            Text("\(language.t(.volumes)) \(runtimeStore.volumes.count)")
            Text("\(language.t(.networks)) \(runtimeStore.networks.count)")

            Spacer()

            if let lastUpdated = runtimeStore.lastUpdated {
                Text(lastUpdated.formatted(date: .omitted, time: .shortened))
            }

            Text("v0.1.0")
                .foregroundStyle(CDTheme.dockerBlue)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(.bar)
    }
}
