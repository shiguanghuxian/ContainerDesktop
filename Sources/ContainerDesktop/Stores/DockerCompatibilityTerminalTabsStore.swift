import Foundation
import Observation

@MainActor
@Observable
final class DockerCompatibilityTerminalTab: Identifiable {
    let id: UUID
    let title: String
    let store: DockerCompatibilityTerminalStore

    init(
        id: UUID = UUID(),
        title: String,
        store: DockerCompatibilityTerminalStore
    ) {
        self.id = id
        self.title = title
        self.store = store
    }

    var workingDirectory: URL {
        store.workingDirectory
    }
}

enum DockerCompatibilityTerminalTabCloseResult: Equatable {
    case noTabClosed
    case closedTab
    case closedLastTab
}

@MainActor
@Observable
final class DockerCompatibilityTerminalTabsStore {
    var tabs: [DockerCompatibilityTerminalTab] = []
    var selectedTabID: UUID?

    @ObservationIgnored private let makeStore: (URL) -> DockerCompatibilityTerminalStore
    @ObservationIgnored private var nextTabOrdinal = 1

    init(
        initialWorkingDirectory: URL = AppPaths.homeDirectory,
        makeStore: @escaping (URL) -> DockerCompatibilityTerminalStore = { workingDirectory in
            DockerCompatibilityTerminalStore(workingDirectory: workingDirectory)
        }
    ) {
        self.makeStore = makeStore
        newTab(workingDirectory: initialWorkingDirectory)
    }

    var selectedTab: DockerCompatibilityTerminalTab? {
        guard let selectedTabID else { return tabs.first }
        return tabs.first { $0.id == selectedTabID } ?? tabs.first
    }

    @discardableResult
    func newTab(workingDirectory: URL? = nil) -> DockerCompatibilityTerminalTab {
        let resolvedWorkingDirectory = workingDirectory
            ?? selectedTab?.workingDirectory
            ?? AppPaths.homeDirectory
        let ordinal = nextTabOrdinal
        nextTabOrdinal += 1

        let tab = DockerCompatibilityTerminalTab(
            title: Self.title(for: resolvedWorkingDirectory, ordinal: ordinal),
            store: makeStore(resolvedWorkingDirectory)
        )
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    @discardableResult
    func closeSelectedTab() -> DockerCompatibilityTerminalTabCloseResult {
        guard let selectedTabID else { return .noTabClosed }
        return closeTab(id: selectedTabID)
    }

    @discardableResult
    func closeTab(id: UUID) -> DockerCompatibilityTerminalTabCloseResult {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return .noTabClosed
        }

        let tab = tabs.remove(at: index)
        tab.store.stopTerminal()

        guard !tabs.isEmpty else {
            selectedTabID = nil
            return .closedLastTab
        }

        let hasValidSelection = selectedTabID.map { selectedID in
            tabs.contains { $0.id == selectedID }
        } ?? false
        if selectedTabID == id || !hasValidSelection {
            let nextIndex = min(index, tabs.count - 1)
            selectedTabID = tabs[nextIndex].id
        }

        return .closedTab
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    func selectNextTab() {
        selectRelativeTab(offset: 1)
    }

    func selectPreviousTab() {
        selectRelativeTab(offset: -1)
    }

    func stopAll() {
        for tab in tabs {
            tab.store.stopTerminal()
        }
    }

    private func selectRelativeTab(offset: Int) {
        guard tabs.count > 1 else { return }
        let currentIndex = selectedTabID.flatMap { id in
            tabs.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex = (currentIndex + offset + tabs.count) % tabs.count
        selectedTabID = tabs[nextIndex].id
    }

    private static func title(for workingDirectory: URL, ordinal: Int) -> String {
        let standardized = workingDirectory.standardizedFileURL
        let pathComponent = standardized.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathComponent.isEmpty {
            return pathComponent
        }
        return "Terminal \(ordinal)"
    }
}
