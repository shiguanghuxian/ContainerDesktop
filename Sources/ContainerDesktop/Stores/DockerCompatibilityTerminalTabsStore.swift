import Foundation
import Observation

@MainActor
@Observable
final class DockerCompatibilityTerminalTab: Identifiable {
    let id: UUID
    let fallbackTitle: String
    let store: DockerCompatibilityTerminalStore

    init(
        id: UUID = UUID(),
        title: String,
        store: DockerCompatibilityTerminalStore
    ) {
        self.id = id
        self.fallbackTitle = title
        self.store = store
    }

    var title: String {
        if let shellTarget {
            return shellTarget.tabTitle
        }

        let pathComponent = store.workingDirectory.standardizedFileURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathComponent.isEmpty {
            return pathComponent
        }
        return fallbackTitle
    }

    var workingDirectory: URL {
        store.workingDirectory
    }

    var openRequest: DockerCompatibilityTerminalOpenRequest {
        store.openRequest
    }

    var shellTarget: TerminalShellTarget? {
        store.shellTarget
    }
}

enum DockerCompatibilityTerminalTabCloseResult: Equatable {
    case noTabClosed
    case closedTab
    case replacedLastTab
}

@MainActor
@Observable
final class DockerCompatibilityTerminalTabsStore {
    var tabs: [DockerCompatibilityTerminalTab] = []
    var selectedTabID: UUID?

    @ObservationIgnored private let makeStore: (DockerCompatibilityTerminalOpenRequest) -> DockerCompatibilityTerminalStore
    @ObservationIgnored private var nextTabOrdinal = 1

    init(
        initialWorkingDirectory: URL = AppPaths.homeDirectory,
        makeStore: @escaping (URL) -> DockerCompatibilityTerminalStore = { workingDirectory in
            DockerCompatibilityTerminalStore(workingDirectory: workingDirectory)
        }
    ) {
        self.makeStore = { request in
            if request.shellTarget == nil {
                return makeStore(request.workingDirectory)
            }
            return DockerCompatibilityTerminalStore(openRequest: request)
        }
        newTab(request: DockerCompatibilityTerminalOpenRequest(workingDirectory: initialWorkingDirectory))
    }

    init(
        initialRequest: DockerCompatibilityTerminalOpenRequest,
        makeStore: @escaping (DockerCompatibilityTerminalOpenRequest) -> DockerCompatibilityTerminalStore = { request in
            DockerCompatibilityTerminalStore(openRequest: request)
        }
    ) {
        self.makeStore = makeStore
        newTab(request: initialRequest)
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
        return newTab(request: DockerCompatibilityTerminalOpenRequest(workingDirectory: resolvedWorkingDirectory))
    }

    @discardableResult
    func newTab(request: DockerCompatibilityTerminalOpenRequest) -> DockerCompatibilityTerminalTab {
        let ordinal = nextTabOrdinal
        nextTabOrdinal += 1

        let tab = DockerCompatibilityTerminalTab(
            title: Self.title(for: request, ordinal: ordinal),
            store: makeStore(request)
        )
        tabs.append(tab)
        selectedTabID = tab.id
        return tab
    }

    @discardableResult
    func closeSelectedTab() -> DockerCompatibilityTerminalTabCloseResult {
        guard let selectedTabID = selectedTabID ?? tabs.first?.id else {
            return .noTabClosed
        }
        return closeTab(id: selectedTabID)
    }

    @discardableResult
    func closeTab(id: UUID) -> DockerCompatibilityTerminalTabCloseResult {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else {
            return .noTabClosed
        }

        let tab = tabs.remove(at: index)
        let replacementWorkingDirectory = tab.workingDirectory
        tab.store.stopTerminal()

        guard !tabs.isEmpty else {
            selectedTabID = nil
            newTab(workingDirectory: replacementWorkingDirectory)
            return .replacedLastTab
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

    private static func title(for request: DockerCompatibilityTerminalOpenRequest, ordinal: Int) -> String {
        if let shellTarget = request.shellTarget {
            return shellTarget.tabTitle
        }
        let standardized = request.workingDirectory.standardizedFileURL
        let pathComponent = standardized.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pathComponent.isEmpty {
            return pathComponent
        }
        return "Terminal \(ordinal)"
    }
}
