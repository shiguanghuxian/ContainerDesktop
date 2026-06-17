import Foundation
import Observation

@MainActor
@Observable
final class NetworkDetailStore {
    typealias InspectLoader = @MainActor (String) async throws -> String

    let networkName: String
    private let inspectLoader: InspectLoader

    var selectedTab: NetworkDetailTab = .overview
    var inspectText = ""
    var inspectSearchText = ""
    var inspectError: String?
    var isLoadingInspect = false

    init(
        networkName: String,
        inspectLoader: @escaping InspectLoader = { name in
            try await ContainerCLIClient().inspectNetwork(name).prettyString
        }
    ) {
        self.networkName = networkName
        self.inspectLoader = inspectLoader
    }

    var visibleInspectText: String {
        let query = inspectSearchText.trimmed
        guard !query.isEmpty else { return inspectText }
        return inspectText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .joined(separator: "\n")
    }

    func bootstrap() async {
        guard inspectText.isEmpty else { return }
        await refreshInspect()
    }

    func refreshInspect() async {
        inspectError = nil
        isLoadingInspect = true
        if inspectText.isEmpty {
            inspectText = "Loading network inspect..."
        }
        defer { isLoadingInspect = false }

        do {
            inspectText = try await inspectLoader(networkName)
        } catch {
            inspectError = error.localizedDescription
            inspectText = error.localizedDescription
        }
    }
}
