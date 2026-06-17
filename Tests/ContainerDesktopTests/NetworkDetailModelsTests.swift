import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Network detail models")
struct NetworkDetailModelsTests {
    @Test("network summary uses configured IPv4 and falls back to status subnet")
    func networkSummaryIPv4Fallbacks() {
        let configured = makeNetwork(configurationIPv4: "10.10.0.0/24", statusIPv4: "192.168.64.0/24")
        let fallback = makeNetwork(configurationIPv4: nil, statusIPv4: "192.168.64.0/24")

        #expect(configured.ipv4ConfigurationText == "10.10.0.0/24")
        #expect(fallback.ipv4ConfigurationText == "192.168.64.0/24")
    }

    @Test("network summary displays empty IPv6 as dash")
    func networkSummaryIPv6Fallback() {
        let network = makeNetwork(configurationIPv6: nil)

        #expect(network.ipv6ConfigurationText == "—")
    }

    @Test("network metadata rows are sorted by key")
    func networkMetadataRowsAreSorted() {
        let network = makeNetwork(
            labels: ["zeta": "last", "alpha": "first"],
            options: ["mtu": "1500", "bridge": "custom0"]
        )

        #expect(network.sortedLabels.map(\.key) == ["alpha", "zeta"])
        #expect(network.sortedOptions.map(\.key) == ["bridge", "mtu"])
        #expect(network.metadataCount == 4)
    }

    @Test("network detail tab titles are localized")
    func networkDetailTabTitlesAreLocalized() {
        #expect(NetworkDetailTab.overview.title(language: .zhHans) == "概览")
        #expect(NetworkDetailTab.metadata.title(language: .zhHans) == "元数据")
        #expect(NetworkDetailTab.overview.title(language: .en) == "Overview")
        #expect(NetworkDetailTab.metadata.title(language: .en) == "Metadata")
    }

    private func makeNetwork(
        configurationIPv4: String? = "10.10.0.0/24",
        configurationIPv6: String? = "fd00:10::/64",
        statusIPv4: String = "10.10.0.0/24",
        labels: [String: String] = [:],
        options: [String: String] = [:]
    ) -> NetworkSummary {
        NetworkSummary(
            configuration: NetworkSummary.Configuration(
                name: "app-net",
                creationDate: Date(timeIntervalSince1970: 1_781_233_546),
                mode: "nat",
                ipv4Subnet: configurationIPv4,
                ipv6Subnet: configurationIPv6,
                labels: labels,
                plugin: "bridge",
                options: options
            ),
            status: NetworkSummary.Status(ipv4Subnet: statusIPv4)
        )
    }
}
