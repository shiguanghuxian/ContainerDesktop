import Foundation
import Testing

@Suite("Interaction enhancement structure")
struct InteractionEnhancementSourceTests {
    @Test("shared resource routes are consumed by resource pages")
    func sharedResourceRoutesAreConsumedByResourcePages() throws {
        let content = try source("Sources/ContainerDesktop/Views/ContentView.swift")
        let containers = try source("Sources/ContainerDesktop/Views/Resources/ContainersView.swift")
        let images = try source("Sources/ContainerDesktop/Views/Resources/ImagesView.swift")
        let volumes = try source("Sources/ContainerDesktop/Views/Resources/VolumesView.swift")
        let networks = try source("Sources/ContainerDesktop/Views/Resources/NetworksView.swift")
        let compose = try source("Sources/ContainerDesktop/Views/Compose/ComposeView.swift")

        #expect(content.contains("resourceRoute: $resourceRoute"))
        #expect(content.contains("case .network:"))
        #expect(content.contains("case .tagImage(let reference):"))
        #expect(content.contains("case .pushImage(let reference):"))
        #expect(containers.contains(".onAppear {\n            consumeResourceRoute()"))
        #expect(images.contains("case .imageTag(let reference):"))
        #expect(images.contains("prepareTagImage(reference: reference)"))
        #expect(images.contains("preparePushImage(reference: reference)"))
        #expect(volumes.contains("case .volume(let name, let tab)"))
        #expect(networks.contains("case .network(let name, let tab)"))
        #expect(compose.contains("detailContainerInitialTab"))
    }

    @Test("resource table rows support full row detail activation")
    func resourceTableRowsSupportFullRowDetailActivation() throws {
        let resourceParts = try source("Sources/ContainerDesktop/Views/Common/ResourcePageParts.swift")
        let containers = try source("Sources/ContainerDesktop/Views/Resources/ContainersView.swift")
        let machines = try source("Sources/ContainerDesktop/Views/Resources/MachinesView.swift")
        let images = try source("Sources/ContainerDesktop/Views/Resources/ImagesView.swift")
        let volumes = try source("Sources/ContainerDesktop/Views/Resources/VolumesView.swift")
        let networks = try source("Sources/ContainerDesktop/Views/Resources/NetworksView.swift")

        #expect(resourceParts.contains("var onActivate: (() -> Void)?"))
        #expect(resourceParts.contains("var activationHelp: String?"))
        #expect(resourceParts.contains("Button(action: onActivate)"))
        #expect(resourceParts.contains(".accessibilityLabel(Text(activationHelp ?? \"Open\"))"))

        #expect(containers.contains("onActivate: {\n                                openContainerDetail(container)"))
        #expect(machines.contains("onActivate: {\n                                openMachineDetail(machine)"))
        #expect(images.contains("onActivate: {\n                selectEntry(entry)"))
        #expect(volumes.contains("onActivate: {\n                                openVolumeDetail(volume)"))
        #expect(networks.contains("onActivate: {\n                                openNetworkDetail(network)"))
    }

    @Test("palette associations history and observability keep shared entry points")
    func paletteAssociationsHistoryAndObservabilityKeepEntryPoints() throws {
        let palette = try source("Sources/ContainerDesktop/Views/Common/GlobalSearchPanel.swift")
        let associations = try source("Sources/ContainerDesktop/Views/Common/ResourceAssociationsPanel.swift")
        let operationHistory = try source("Sources/ContainerDesktop/Views/Common/OperationHistoryPanel.swift")
        let toast = try source("Sources/ContainerDesktop/Views/Common/OperationToast.swift")
        let observability = try source("Sources/ContainerDesktop/Views/ObservabilityView.swift")

        #expect(palette.contains("groupedActions"))
        #expect(palette.contains("AppQuickActionGroup.allCases"))
        #expect(palette.contains("Return"))
        #expect(associations.contains("ResourceAssociationsPanel"))
        #expect(associations.contains("NSPasteboard.general.setString(value, forType: .string)"))
        #expect(operationHistory.contains("复制诊断报告"))
        #expect(toast.contains("复制命令"))
        #expect(toast.contains("复制失败摘要"))
        #expect(observability.contains("saveCurrentLogPreset()"))
        #expect(observability.contains("logRegexEnabled"))
        #expect(observability.contains("logErrorOnly"))
        #expect(observability.contains("exportLogs()"))
    }

    @Test("port associations use a horizontal compact section")
    func portAssociationsUseHorizontalCompactSection() throws {
        let associations = try source("Sources/ContainerDesktop/Views/Common/ResourceAssociationsPanel.swift")

        #expect(associations.contains("sections.filter { $0.id == \"ports\" }"))
        #expect(associations.contains("section.id != \"ports\" && (operationsDisplayMode == .inline || section.id != \"operations\")"))
        #expect(associations.contains("private func portAssociationSection"))
        #expect(associations.contains("ScrollView(.horizontal, showsIndicators: false)"))
        #expect(associations.contains("private func portAssociationItem"))
        #expect(associations.contains("ForEach(standardSections)"))
        #expect(associations.contains("LazyVGrid(columns: [GridItem(.adaptive(minimum: 220)"))
    }

    @Test("container associations expose recent operations from a header popover")
    func containerAssociationsExposeRecentOperationsFromHeaderPopover() throws {
        let associations = try source("Sources/ContainerDesktop/Views/Common/ResourceAssociationsPanel.swift")
        let containerDetail = try source("Sources/ContainerDesktop/Views/Resources/ContainerDetailPage.swift")

        #expect(associations.contains("enum ResourceAssociationOperationsDisplayMode"))
        #expect(associations.contains("case inline"))
        #expect(associations.contains("case popover"))
        #expect(associations.contains("headerAccessory:"))
        #expect(associations.contains("private var operationSection: ResourceAssociationSection?"))
        #expect(associations.contains("private func operationsPopoverButton"))
        #expect(associations.contains(".popover(isPresented: $showOperationsPopover"))
        #expect(associations.contains("private func operationsPopover"))
        #expect(containerDetail.contains("operationsDisplayMode: .popover"))
    }

    @Test("sidebar author info uses compact hover popover")
    func sidebarAuthorInfoUsesCompactHoverPopover() throws {
        let sidebar = try source("Sources/ContainerDesktop/Views/SidebarView.swift")
        let authorInfo = try source("Sources/ContainerDesktop/Views/SidebarAuthorInfoView.swift")

        #expect(sidebar.contains("SidebarAuthorInfoView()"))
        #expect(sidebar.contains(".padding(.horizontal, 12)"))
        #expect(sidebar.contains(".padding(.top, 12)"))
        #expect(sidebar.contains(".padding(.bottom, 34)"))
        #expect(sidebar.contains(".overlay(alignment: .bottom)"))
        #expect(sidebar.contains(".padding(.bottom, 6)"))
        #expect(!sidebar.contains("Spacer(minLength: 0)\n\n            SidebarAuthorInfoView()"))
        #expect(!sidebar.contains(".padding(12)\n        .frame(width: 260)"))
        #expect(!sidebar.contains("private var authorInfoCard"))
        #expect(authorInfo.contains("struct SidebarAuthorInfoView: View"))
        #expect(authorInfo.contains("HStack(spacing: 6)"))
        #expect(authorInfo.contains(".padding(.horizontal, 6)"))
        #expect(authorInfo.contains(".frame(height: 24)"))
        #expect(authorInfo.contains("RoundedRectangle(cornerRadius: 6)"))
        #expect(authorInfo.contains("CDTheme.separator.opacity(0.52)"))
        #expect(authorInfo.contains(".onHover"))
        #expect(authorInfo.contains(".popover(isPresented: $isPopoverPresented"))
        #expect(authorInfo.contains("scheduleDismiss()"))
        #expect(authorInfo.contains("zuoxiupeng@live.com"))
        #expect(authorInfo.contains("github.com/shiguanghuxian"))
    }

    @Test("top bar terminal menu exposes docker and compatible system terminal choices")
    func topBarTerminalMenuExposesDockerAndCompatibleSystemTerminalChoices() throws {
        let chrome = try source("Sources/ContainerDesktop/Views/AppChrome.swift")
        let router = try source("Sources/ContainerDesktop/App/ContainerDesktopMainWindow.swift")
        let app = try source("Sources/ContainerDesktop/App/ContainerDesktopApp.swift")

        #expect(chrome.contains("TopBarMenuButton("))
        #expect(chrome.contains("private struct TopBarIconLabel"))
        #expect(chrome.contains("TopBarIconLabel(systemImage: systemImage, isLoading: isLoading, isDisabled: isDisabled)"))
        #expect(chrome.contains("private struct TopBarMenuAction"))
        #expect(chrome.contains("TopBarIconLabel(systemImage: systemImage)\n                .allowsHitTesting(false)"))
        #expect(chrome.contains("TopBarMenuHitTarget(actions: actions)"))
        #expect(chrome.contains("private struct TopBarMenuHitTarget: NSViewRepresentable"))
        #expect(chrome.contains("private final class TopBarMenuHitTargetView: NSView"))
        #expect(chrome.contains("override func acceptsFirstMouse(for event: NSEvent?) -> Bool"))
        #expect(chrome.contains("let menu = NSMenu()"))
        #expect(chrome.contains("menu.popUp(positioning: nil"))
        #expect(chrome.contains("DockerCompatibilityTerminalStrings.openTerminalMenu(language)"))
        #expect(chrome.contains("DockerCompatibilityTerminalStrings.windowTitle(language)"))
        #expect(chrome.contains("DockerCompatibilityTerminalStrings.compatibleSystemTerminalTitle(language)"))
        #expect(chrome.contains("ContainerDesktopWindowRouter.openDockerCompatibilityTerminal()"))
        #expect(chrome.contains("ContainerDesktopWindowRouter.openDockerCompatibilitySystemTerminal()"))
        #expect(!chrome.contains("Menu {\n            content()"))
        #expect(!chrome.contains("Color.clear\n                    .frame(width: 34, height: 34)"))
        #expect(chrome.contains(".frame(width: 34, height: 34)"))
        #expect(!chrome.contains(".menuIndicator(.hidden)"))

        #expect(router.contains("openDockerCompatibilitySystemTerminalAction"))
        #expect(router.contains("openDockerCompatibilitySystemTerminal: @escaping () -> Void"))
        #expect(router.contains("static func openDockerCompatibilitySystemTerminal()"))
        #expect(app.contains("openDockerCompatibilitySystemTerminal: { [weak self] in"))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
