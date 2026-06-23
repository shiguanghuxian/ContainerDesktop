import Foundation

struct ObservabilityLogPreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var searchText: String
    var filterText: String
    var logSource: ObservabilityLogSource
    var logLines: String
    var systemLogLast: String
    var composeScope: ObservabilityComposeScope
    var onlyRunning: Bool
    var autoRefresh: Bool
    var refreshInterval: String
    var regexEnabled: Bool
    var caseSensitive: Bool
    var errorOnly: Bool
    var softWrap: Bool

    init(
        id: UUID = UUID(),
        name: String,
        searchText: String,
        filterText: String,
        logSource: ObservabilityLogSource,
        logLines: String,
        systemLogLast: String,
        composeScope: ObservabilityComposeScope,
        onlyRunning: Bool,
        autoRefresh: Bool,
        refreshInterval: String,
        regexEnabled: Bool,
        caseSensitive: Bool,
        errorOnly: Bool,
        softWrap: Bool
    ) {
        self.id = id
        self.name = name
        self.searchText = searchText
        self.filterText = filterText
        self.logSource = logSource
        self.logLines = logLines
        self.systemLogLast = systemLogLast
        self.composeScope = composeScope
        self.onlyRunning = onlyRunning
        self.autoRefresh = autoRefresh
        self.refreshInterval = refreshInterval
        self.regexEnabled = regexEnabled
        self.caseSensitive = caseSensitive
        self.errorOnly = errorOnly
        self.softWrap = softWrap
    }
}

enum ObservabilityLogPresetPersistence {
    private static let defaultsKey = "containerdesktop.observability.logPresets"
    private static let maxPresets = 12

    static func load(defaults: UserDefaults = .containerDesktopShared) -> [ObservabilityLogPreset] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder.containerDesktop.decode([ObservabilityLogPreset].self, from: data)) ?? []
    }

    static func save(_ presets: [ObservabilityLogPreset], defaults: UserDefaults = .containerDesktopShared) {
        let limited = Array(presets.prefix(maxPresets))
        guard let data = try? JSONEncoder.containerDesktop.encode(limited) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
