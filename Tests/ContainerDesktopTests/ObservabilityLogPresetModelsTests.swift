import Foundation
import Testing
@testable import ContainerDesktop

@Suite("Observability log presets")
struct ObservabilityLogPresetModelsTests {
    @Test("presets persist filters and are capped")
    func presetsPersistFiltersAndAreCapped() throws {
        let defaults = try #require(UserDefaults(suiteName: "containerdesktop-tests-\(UUID().uuidString)"))
        let presets = (0..<14).map { index in
            ObservabilityLogPreset(
                id: UUID(),
                name: "preset-\(index)",
                searchText: "api",
                filterText: "error",
                logSource: index.isMultiple(of: 2) ? .containerStdio : .system,
                logLines: "200",
                systemLogLast: "10m",
                composeScope: index.isMultiple(of: 3) ? .all : .project("/tmp/demo/compose.yaml"),
                onlyRunning: true,
                autoRefresh: false,
                refreshInterval: "15",
                regexEnabled: true,
                caseSensitive: false,
                errorOnly: true,
                softWrap: index.isMultiple(of: 2)
            )
        }

        ObservabilityLogPresetPersistence.save(presets, defaults: defaults)
        let loaded = ObservabilityLogPresetPersistence.load(defaults: defaults)

        #expect(loaded.count == 12)
        #expect(loaded.first?.name == "preset-0")
        #expect(loaded.first?.filterText == "error")
        #expect(loaded.first?.regexEnabled == true)
        #expect(loaded.first?.errorOnly == true)
        #expect(loaded.last?.name == "preset-11")
    }
}
