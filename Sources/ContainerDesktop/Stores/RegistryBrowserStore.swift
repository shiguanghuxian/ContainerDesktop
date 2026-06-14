import Foundation
import Observation

@MainActor
@Observable
final class RegistryBrowserStore {
    private let client: RegistryBrowserClient

    var searchQuery = "nginx"
    var repositories: [RegistryRepositoryResult] = []
    var selectedRepository: RegistryRepositoryResult?
    var selectedTag: RegistryImageTag?
    var tags: [RegistryImageTag] = []
    var repositoryPage = 1
    var repositoryTotalCount: Int?
    var repositoryHasNext = false
    var tagPage = 1
    var tagTotalCount: Int?
    var tagHasNext = false
    var customRegistryServer = "registry-1.docker.io"
    var customRepository = ""
    var customRegistryScheme = "https"
    var customRegistryUsername = ""
    var customRegistryPassword = ""
    var customRegistryTags: [RegistryImageTag] = []
    var selectedCustomRegistryTag: RegistryImageTag?
    var customRegistryCursorStack: [String] = []
    var customRegistryNextCursor: String?
    var isSearching = false
    var isLoadingTags = false
    var isLoadingCustomTagDetails = false
    var errorMessage: String?

    init(client: RegistryBrowserClient = RegistryBrowserClient()) {
        self.client = client
    }

    func searchDockerHub(page: Int = 1) async {
        let query = searchQuery.trimmed
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let pageResult = try await client.searchDockerHub(query: query, page: page)
            repositories = pageResult.items
            repositoryPage = page
            repositoryTotalCount = pageResult.totalCount
            repositoryHasNext = pageResult.hasNext
            if selectedRepository == nil || !repositories.contains(where: { $0.id == selectedRepository?.id }) {
                selectedRepository = repositories.first
                selectedTag = nil
                tags = []
            }
        } catch {
            repositories = []
            errorMessage = error.localizedDescription
        }
    }

    func loadTags(for repository: RegistryRepositoryResult, page: Int = 1) async {
        selectedRepository = repository
        isLoadingTags = true
        errorMessage = nil
        tags = []
        selectedTag = nil
        defer { isLoadingTags = false }

        do {
            let pageResult = try await client.dockerHubTags(repository: repository.name, page: page)
            tags = pageResult.items
            selectedTag = tags.first
            tagPage = page
            tagTotalCount = pageResult.totalCount
            tagHasNext = pageResult.hasNext
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCustomRegistryTags(last: String? = nil, movingForward: Bool = false) async {
        let server = customRegistryServer.trimmed
        let repository = customRepository.trimmed
        guard !server.isEmpty, !repository.isEmpty else { return }
        isLoadingTags = true
        errorMessage = nil
        customRegistryTags = []
        selectedCustomRegistryTag = nil
        defer { isLoadingTags = false }

        do {
            let credentials = RegistryBrowseCredentials(
                username: customRegistryUsername,
                password: customRegistryPassword
            )
            let page = try await client.registryTags(
                server: server,
                repository: repository,
                scheme: customRegistryScheme,
                credentials: credentials.isUsable ? credentials : nil,
                last: last
            )
            customRegistryTags = page.items
            selectedCustomRegistryTag = customRegistryTags.first
            customRegistryNextCursor = page.nextCursor
            if movingForward, let last {
                customRegistryCursorStack.append(last)
            } else if last == nil {
                customRegistryCursorStack = []
            }
            if let selectedCustomRegistryTag {
                await loadCustomRegistryManifest(for: selectedCustomRegistryTag.name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCustomRegistryTag(_ tag: RegistryImageTag) async {
        selectedCustomRegistryTag = tag
        await loadCustomRegistryManifest(for: tag.name)
    }

    func loadCustomRegistryManifest(for reference: String) async {
        let server = customRegistryServer.trimmed
        let repository = customRepository.trimmed
        guard !server.isEmpty, !repository.isEmpty, !reference.trimmed.isEmpty else { return }
        isLoadingCustomTagDetails = true
        errorMessage = nil
        defer { isLoadingCustomTagDetails = false }

        do {
            let credentials = RegistryBrowseCredentials(
                username: customRegistryUsername,
                password: customRegistryPassword
            )
            let details = try await client.registryManifest(
                server: server,
                repository: repository,
                reference: reference,
                scheme: customRegistryScheme,
                credentials: credentials.isUsable ? credentials : nil
            )
            guard let current = selectedCustomRegistryTag, current.name == reference else { return }
            let enriched = current.enriched(with: details)
            selectedCustomRegistryTag = enriched
            if let index = customRegistryTags.firstIndex(where: { $0.name == reference }) {
                customRegistryTags[index] = customRegistryTags[index].enriched(with: details)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNextRepositoryPage() async {
        guard repositoryHasNext else { return }
        await searchDockerHub(page: repositoryPage + 1)
    }

    func loadPreviousRepositoryPage() async {
        guard repositoryPage > 1 else { return }
        await searchDockerHub(page: repositoryPage - 1)
    }

    func loadNextTagPage() async {
        guard let selectedRepository, tagHasNext else { return }
        await loadTags(for: selectedRepository, page: tagPage + 1)
    }

    func loadPreviousTagPage() async {
        guard let selectedRepository, tagPage > 1 else { return }
        await loadTags(for: selectedRepository, page: tagPage - 1)
    }

    func loadNextCustomRegistryPage() async {
        guard let next = customRegistryNextCursor else { return }
        await loadCustomRegistryTags(last: next, movingForward: true)
    }

    func loadPreviousCustomRegistryPage() async {
        guard !customRegistryCursorStack.isEmpty else {
            await loadCustomRegistryTags()
            return
        }
        _ = customRegistryCursorStack.popLast()
        let previous = customRegistryCursorStack.last
        await loadCustomRegistryTags(last: previous)
    }
}
