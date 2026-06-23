import Foundation
import Testing

@Suite("Container browser port navigation")
struct ContainerBrowserPortNavigationTests {
    @Test("container list and detail expose browser port actions")
    func containerListAndDetailExposeBrowserPortActions() throws {
        let containers = try source("Sources/ContainerDesktop/Views/Resources/ContainersView.swift")
        let header = try source("Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerDetailHeaderView.swift")
        let common = try source("Sources/ContainerDesktop/Views/Common/ResourcePageParts.swift")

        #expect(containers.contains("ContainerBrowserPortMenuButton("))
        #expect(containers.contains("runtimeStore.browserPortTargets(for: container)"))
        #expect(containers.contains("runtimeStore.loadBrowserPortTargets(for: container)"))
        #expect(header.contains("ContainerBrowserPortInlineMenuButton("))
        #expect(header.contains("ContainerBrowserPortTarget.portSummary(from: inspectText)"))
        #expect(common.contains("struct ContainerBrowserPortMenuButton"))
        #expect(common.contains("struct ContainerBrowserPortInlineMenuButton"))
        #expect(common.contains("NSWorkspace.shared.open(url)"))
        #expect(common.contains("NSPasteboard.general.setString(value, forType: .string)"))
        #expect(common.contains("Section"))
        #expect(common.contains("menuTargets(for: .host)"))
        #expect(common.contains("menuTargets(for: .container)"))
        #expect(common.contains("打开网站或复制端口连接信息"))
        #expect(common.contains("Port Actions"))

        let quickActions = try source("Sources/ContainerDesktop/Models/ContainerPortQuickActions.swift")
        #expect(quickActions.contains("enum ContainerPortQuickActionKind"))
        #expect(quickActions.contains("copyURL"))
        #expect(quickActions.contains("copyConnectionString"))
        #expect(quickActions.contains("copyEnvironmentSnippet"))
        #expect(quickActions.contains("copyCLICommand"))
        #expect(quickActions.contains("copyHealthCheckCommand"))
        #expect(quickActions.contains("curl -fsS"))
        #expect(quickActions.contains("nc -vz"))
        #expect(quickActions.contains("PostgreSQL"))
        #expect(quickActions.contains("RabbitMQ"))
        #expect(quickActions.contains("MinIO"))

        let actionButtons = try section(
            in: header,
            from: "private var actionButtons",
            to: "private var portSummaryLine"
        )
        #expect(!actionButtons.contains("ContainerBrowserPort"))
        #expect(!actionButtons.contains("safari"))
    }

    @Test("compose views expose browser port actions")
    func composeViewsExposeBrowserPortActions() throws {
        let compose = try source("Sources/ContainerDesktop/Views/Compose/ComposeView.swift")
        let rows = try source("Sources/ContainerDesktop/Views/Compose/ComposeProjectExpandedRows.swift")

        #expect(compose.contains("runtimeStore.browserPortTargets(for: container)"))
        #expect(compose.contains("runtimeStore.loadBrowserPortTargets(for: container)"))
        #expect(compose.contains("runtime.runningContainers.flatMap { browserPortTargets($0) }"))
        #expect(rows.contains("ContainerBrowserPortMenuButton("))
        #expect(rows.contains("onLoadBrowserPortTargets(container)"))
        #expect(rows.contains("browserPortTargetError(container)"))
    }

    @Test("resource IP values expose copy actions")
    func resourceIPValuesExposeCopyActions() throws {
        let common = try source("Sources/ContainerDesktop/Views/Common/ResourcePageParts.swift")
        let drawer = try source("Sources/ContainerDesktop/Views/Common/DetailDrawer.swift")
        let containers = try source("Sources/ContainerDesktop/Views/Resources/ContainersView.swift")
        let containerHeader = try source("Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerDetailHeaderView.swift")
        let machines = try source("Sources/ContainerDesktop/Views/Resources/MachinesView.swift")
        let machineHeader = try source("Sources/ContainerDesktop/Views/Resources/MachineDetail/MachineDetailHeaderView.swift")
        let machineOverview = try source("Sources/ContainerDesktop/Views/Resources/MachineDetail/MachineOverviewTabView.swift")
        let composeRows = try source("Sources/ContainerDesktop/Views/Compose/ComposeProjectExpandedRows.swift")

        #expect(common.contains("struct CopyableIPAddressText"))
        #expect(drawer.contains("struct CopyableIPAddressInfoRow"))
        #expect(containers.contains("CopyableIPAddressText(value: container.primaryIP)"))
        #expect(containers.contains("CopyableIPAddressInfoRow(title: \"IP\", value: container.primaryIP)"))
        #expect(containerHeader.contains("copyableIP: true"))
        #expect(machines.contains("CopyableIPAddressText(value: machine.ipAddressText)"))
        #expect(machines.contains("CopyableIPAddressInfoRow(title: \"IP\", value: machine.ipAddressText)"))
        #expect(machineHeader.contains("copyableIP: true"))
        #expect(machineOverview.contains("CopyableIPAddressInfoRow(title: \"IP\", value: machine.ipAddressText)"))
        #expect(composeRows.contains("CopyableIPAddressText("))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    private func section(in source: String, from startMarker: String, to endMarker: String) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(source[start.upperBound...].range(of: endMarker))
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
