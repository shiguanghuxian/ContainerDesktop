import Foundation
import Testing

@Suite("Networks view navigation")
struct NetworksViewNavigationTests {
    @Test("network row opens detail while sidebar action opens drawer")
    func networkRowOpensDetailWhileSidebarActionOpensDrawer() throws {
        let source = try networksViewSource()

        #expect(source.contains("@State private var detailName: String?"))
        #expect(source.contains("NetworkDetailPage("))
        #expect(source.contains("private func networkRowMainContent(_ network: NetworkSummary) -> some View"))
        #expect(!source.contains("private func networkRowMainButton(_ network: NetworkSummary) -> some View"))
        #expect(source.contains("private func openNetworkDetail(_ network: NetworkSummary)"))

        let rowRange = try #require(source.range(of: "ResourceTableRow(\n                            isSelected: selectedName == network.name || detailName == network.name,"))
        let rowSnippet = String(source[rowRange.lowerBound...].prefix(520))
        #expect(rowSnippet.contains("onActivate: {\n                                openNetworkDetail(network)"))
        #expect(rowSnippet.contains("Open network details"))

        let sidebarRange = try #require(source.range(of: "systemImage: \"sidebar.right\""))
        let sidebarSnippet = String(source[sidebarRange.lowerBound...].prefix(420))
        #expect(sidebarSnippet.contains("selectNetwork(network)"))
        #expect(sidebarSnippet.contains("打开网络详情抽屉"))
        #expect(!sidebarSnippet.contains("openNetworkDetail(network)"))
    }

    @Test("network drawer reuses overview and metadata detail components")
    func networkDrawerReusesDetailComponents() throws {
        let source = try networksViewSource()

        #expect(source.contains("NetworkOverviewTabView(network: selectedNetwork)"))
        #expect(source.contains("NetworkMetadataTabView(network: selectedNetwork)"))
        #expect(!source.contains("private struct NetworkDetailOverview"))
    }

    @Test("network create form exposes advanced options")
    func networkCreateFormExposesAdvancedOptions() throws {
        let source = try networksViewSource()

        #expect(source.contains("@State private var plugin = \"\""))
        #expect(source.contains("@State private var labels = \"\""))
        #expect(source.contains("@State private var options = \"\""))
        #expect(source.contains("DisclosureGroup("))
        #expect(source.contains("NetworkCreateOptions("))
        #expect(source.contains("plugin: plugin"))
        #expect(source.contains("labels: lines(from: labels)"))
        #expect(source.contains("options: lines(from: options)"))
        #expect(source.contains("runtimeStore.createNetwork(options: createOptions)"))
    }

    @Test("network detail page contains header tabs and inspect content")
    func networkDetailPageStructure() throws {
        let page = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkDetailPage.swift")
        let header = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkDetailHeaderView.swift")
        let tabBar = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkDetailTabBar.swift")
        let overview = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkOverviewTabView.swift")
        let metadata = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkMetadataTabView.swift")
        let inspect = try source("Sources/ContainerDesktop/Views/Resources/NetworkDetail/NetworkInspectTabView.swift")

        #expect(page.contains("NetworkDetailHeaderView("))
        #expect(page.contains("NetworkDetailTabBar(selection: $detailStore.selectedTab)"))
        #expect(page.contains("NetworkOverviewTabView(network: network)"))
        #expect(page.contains("NetworkMetadataTabView(network: network)"))
        #expect(page.contains("NetworkInspectTabView(store: detailStore)"))
        #expect(header.contains("SecondaryPageBackBar("))
        #expect(tabBar.contains("ForEach(NetworkDetailTab.allCases)"))
        #expect(overview.contains("地址配置"))
        #expect(metadata.contains("没有标签或插件选项。"))
        #expect(inspect.contains("ReadOnlyMonospaceTextView("))
        #expect(inspect.contains("copy(store.visibleInspectText)"))
    }

    private func networksViewSource() throws -> String {
        try source("Sources/ContainerDesktop/Views/Resources/NetworksView.swift")
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
