import Foundation
import Observation

@MainActor
@Observable
final class VolumeDetailStore {
    typealias InspectLoader = @MainActor (String) async throws -> String

    let volumeName: String
    private let inspectLoader: InspectLoader

    var selectedTab: VolumeDetailTab
    var inspectText = ""
    var inspectSearchText = ""
    var inspectError: String?
    var isLoadingInspect = false

    init(
        volumeName: String,
        initialTab: VolumeDetailTab = .overview,
        inspectLoader: @escaping InspectLoader = { name in
            try await ContainerCLIClient().inspectVolume(name).prettyString
        }
    ) {
        self.volumeName = volumeName
        self.selectedTab = initialTab
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
            inspectText = "Loading volume inspect..."
        }
        defer { isLoadingInspect = false }

        do {
            inspectText = try await inspectLoader(volumeName)
        } catch {
            inspectError = error.localizedDescription
            inspectText = error.localizedDescription
        }
    }
}
