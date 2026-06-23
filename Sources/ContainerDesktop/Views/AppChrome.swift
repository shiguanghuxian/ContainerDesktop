import AppKit
import SwiftUI

struct AppTopBar: View {
    @Environment(\.appLanguage) private var language
    @Binding var searchText: String
    @Binding var isSidebarCollapsed: Bool
    var onSearchSubmit: () -> Void = {}
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var composeStore: ComposeProjectStore
    @Bindable var systemConfigStore: SystemConfigStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CDTheme.dockerBlue

            WindowDragZoomRegion()

            HStack(spacing: 18) {
                brandCluster

                Spacer(minLength: 16)

                searchField
                topBarActions
            }
            .padding(.leading, 94)
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 52, idealHeight: 52, maxHeight: 52, alignment: .leading)
    }

    private var brandCluster: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(AppBranding.displayName)
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
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.76))
            TextField(language.resolved == .zhHans ? "搜索资源或输入命令" : "Search resources or commands", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .onSubmit(onSearchSubmit)
            if !searchText.trimmed.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.72))
                }
                .buttonStyle(.plain)
                .help(language.resolved == .zhHans ? "清空搜索" : "Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 34)
        .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 8))
        .tint(.white)
    }

    private var topBarActions: some View {
        HStack(spacing: 6) {
            TopBarButton(
                systemImage: isSidebarCollapsed ? "sidebar.left" : "sidebar.leading",
                help: isSidebarCollapsed
                    ? (language.resolved == .zhHans ? "展开侧边栏" : "Expand sidebar")
                    : (language.resolved == .zhHans ? "收起侧边栏" : "Collapse sidebar")
            ) {
                withAnimation(.snappy(duration: 0.18)) {
                    isSidebarCollapsed.toggle()
                }
            }

            TopBarMenuButton(
                systemImage: "terminal",
                help: DockerCompatibilityTerminalStrings.openTerminalMenu(language),
                actions: [
                    TopBarMenuAction(
                        title: DockerCompatibilityTerminalStrings.windowTitle(language),
                        systemImage: "terminal"
                    ) {
                        ContainerDesktopWindowRouter.openDockerCompatibilityTerminal()
                    },
                    TopBarMenuAction(
                        title: DockerCompatibilityTerminalStrings.compatibleSystemTerminalTitle(language),
                        systemImage: "macwindow"
                    ) {
                        ContainerDesktopWindowRouter.openDockerCompatibilitySystemTerminal()
                    }
                ]
            )

            TopBarButton(
                systemImage: "arrow.clockwise",
                isLoading: runtimeStore.isRefreshing,
                help: language.t(.refresh)
            ) {
                Task { await runtimeStore.refreshAll() }
            }

            let systemOperationKey = runtimeStore.environment.systemRunning
                ? RuntimeOperationKey.systemStop
                : RuntimeOperationKey.systemStart
            TopBarButton(
                systemImage: runtimeStore.environment.systemRunning ? "stop.circle" : "play.circle",
                isLoading: runtimeStore.isOperationActive(systemOperationKey),
                isDisabled: runtimeStore.busyMessage != nil && !runtimeStore.isOperationActive(systemOperationKey),
                help: runtimeStore.environment.systemRunning ? language.t(.stopSystem) : language.t(.startSystem)
            ) {
                Task {
                    if runtimeStore.environment.systemRunning {
                        await runtimeStore.stopSystem()
                    } else {
                        await runtimeStore.startSystem()
                    }
                }
            }

            TopBarButton(systemImage: "gearshape", help: language.t(.openSettings)) {
                ContainerDesktopWindowRouter.openSettings()
            }
        }
    }
}

private struct TopBarButton: View {
    var systemImage: String
    var isLoading = false
    var isDisabled = false
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TopBarIconLabel(systemImage: systemImage, isLoading: isLoading, isDisabled: isDisabled)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.58 : 1)
        .help(help)
    }
}

private struct TopBarMenuAction {
    var title: String
    var systemImage: String
    var action: @MainActor () -> Void

    init(title: String, systemImage: String, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}

private struct TopBarMenuButton: View {
    var systemImage: String
    var help: String
    var actions: [TopBarMenuAction]

    var body: some View {
        ZStack {
            TopBarIconLabel(systemImage: systemImage)
                .allowsHitTesting(false)

            TopBarMenuHitTarget(actions: actions)
                .frame(width: 34, height: 34)
        }
        .frame(width: 34, height: 34)
        .fixedSize()
        .help(help)
    }
}

private struct TopBarMenuHitTarget: NSViewRepresentable {
    var actions: [TopBarMenuAction]

    func makeCoordinator() -> TopBarMenuHitTargetCoordinator {
        TopBarMenuHitTargetCoordinator(actions: actions)
    }

    func makeNSView(context: Context) -> TopBarMenuHitTargetView {
        let view = TopBarMenuHitTargetView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TopBarMenuHitTargetView, context: Context) {
        context.coordinator.actions = actions
        nsView.coordinator = context.coordinator
    }
}

private final class TopBarMenuHitTargetCoordinator: NSObject {
    var actions: [TopBarMenuAction]

    init(actions: [TopBarMenuAction]) {
        self.actions = actions
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for (index, action) in actions.enumerated() {
            let item = NSMenuItem(
                title: action.title,
                action: #selector(performAction(_:)),
                keyEquivalent: ""
            )
            item.tag = index
            item.target = self
            item.image = NSImage(
                systemSymbolName: action.systemImage,
                accessibilityDescription: action.title
            )
            menu.addItem(item)
        }
        return menu
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        let action = actions[sender.tag].action
        Task { @MainActor in
            action()
        }
    }
}

private final class TopBarMenuHitTargetView: NSView {
    weak var coordinator: TopBarMenuHitTargetCoordinator?

    override var isOpaque: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else {
            super.mouseDown(with: event)
            return
        }
        let menu = coordinator.makeMenu()
        let location = convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: location, in: self)
    }
}

private struct TopBarIconLabel: View {
    var systemImage: String
    var isLoading = false
    var isDisabled = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 34, height: 34)
        .background(.white.opacity(isDisabled ? 0.06 : 0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AppStatusBar: View {
    @Environment(\.appLanguage) private var language
    @Bindable var runtimeStore: RuntimeStore
    @Bindable var operationStore: AppOperationStore

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
            Text("\(language.t(.machines)) \(runtimeStore.machines.count)")
            Text("\(language.t(.images)) \(runtimeStore.images.count)")
            Text("\(language.t(.volumes)) \(runtimeStore.volumes.count)")
            Text("\(language.t(.networks)) \(runtimeStore.networks.count)")

            if operationStore.activeCount > 0 {
                StatusPill(
                    title: language.resolved == .zhHans ? "\(operationStore.activeCount) 个任务运行中" : "\(operationStore.activeCount) tasks running",
                    systemImage: "hourglass",
                    tint: CDTheme.dockerBlue
                )
            }

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
        .background(CDTheme.statusBarSurface)
    }
}
