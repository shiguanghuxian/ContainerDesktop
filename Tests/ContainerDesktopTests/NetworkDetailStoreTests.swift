import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Network detail store", .serialized)
@MainActor
struct NetworkDetailStoreTests {
    @Test("loads inspect text and filters visible lines")
    func loadsInspectTextAndFiltersVisibleLines() async {
        let store = NetworkDetailStore(networkName: "app-net") { name in
            """
            {
              "name": "\(name)",
              "driver": "bridge",
              "subnet": "10.10.0.0/24"
            }
            """
        }

        await store.refreshInspect()
        #expect(store.inspectText.contains("\"name\": \"app-net\""))

        store.inspectSearchText = "subnet"
        #expect(store.visibleInspectText == "  \"subnet\": \"10.10.0.0/24\"")
    }

    @Test("shows error and retries inspect load")
    func showsErrorAndRetriesInspectLoad() async {
        var attempts = 0
        let store = NetworkDetailStore(networkName: "app-net") { _ in
            attempts += 1
            if attempts == 1 {
                throw NetworkDetailStoreTestError.networkMissing
            }
            return "{\"name\":\"app-net\"}"
        }

        await store.refreshInspect()
        #expect(store.inspectError == "network missing")
        #expect(store.inspectText == "network missing")
        #expect(store.isLoadingInspect == false)

        await store.refreshInspect()
        #expect(store.inspectError == nil)
        #expect(store.inspectText == "{\"name\":\"app-net\"}")
        #expect(attempts == 2)
    }
}

private enum NetworkDetailStoreTestError: LocalizedError {
    case networkMissing

    var errorDescription: String? {
        "network missing"
    }
}
