import Foundation
import Testing

@Suite("Dashboard observability navigation")
struct DashboardObservabilityNavigationTests {
    @Test("dashboard exposes resource snapshot entry")
    func dashboardExposesResourceSnapshotEntry() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/DashboardView.swift")

        #expect(source.contains("var onOpenResourceSnapshot: () -> Void"))
        #expect(source.contains("onOpenResourceSnapshot()"))
        #expect(source.contains("Label(language.resolved == .zhHans ? \"资源快照\" : \"Stats Snapshot\", systemImage: \"sidebar.right\")"))
        #expect(source.contains("Open stats snapshot in Observability"))
    }

    @Test("content view routes dashboard snapshot request to observability")
    func contentViewRoutesDashboardSnapshotRequestToObservability() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/ContentView.swift")

        #expect(source.contains("@State private var observabilityResourceSnapshotRequestCounter = 0"))
        #expect(source.contains("@State private var observabilityResourceSnapshotRequestID: Int?"))
        #expect(source.contains("onOpenResourceSnapshot: openObservabilityResourceSnapshot"))
        #expect(source.contains("resourceSnapshotRequestID: $observabilityResourceSnapshotRequestID"))
        #expect(source.contains("observabilityResourceSnapshotRequestCounter += 1"))
        #expect(source.contains("observabilityResourceSnapshotRequestID = observabilityResourceSnapshotRequestCounter"))
        #expect(source.contains("selectSection(.observability)"))
    }

    @Test("observability consumes snapshot route request and opens drawer")
    func observabilityConsumesSnapshotRouteRequestAndOpensDrawer() throws {
        let source = try readSource("Sources/ContainerDesktop/Views/ObservabilityView.swift")

        #expect(source.contains("@Binding var resourceSnapshotRequestID: Int?"))
        #expect(source.contains(".onAppear"))
        #expect(source.contains(".onChange(of: resourceSnapshotRequestID)"))
        #expect(source.contains("consumeResourceSnapshotRouteRequest()"))
        #expect(source.contains("resourceSnapshotRequestID = nil"))
        #expect(source.contains("presentResourceDrawer()"))
        #expect(source.contains("showResourceDrawer = true"))
        #expect(source.contains("if resourceSampleScopeKey != scopedContainerKey || visibleResourceSamples.isEmpty"))
    }

    private func readSource(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
