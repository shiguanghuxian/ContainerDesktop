import Foundation
import Observation

@MainActor
@Observable
final class ComposeProjectStore {
    private let client: ComposeCLIClient
    private let persistenceURL: URL

    var projects: [ComposeProject] = []
    var isLoading = false
    var busyProjectID: ComposeProject.ID?
    var errorMessage: String?
    var lastOutput = "尚未运行 Compose 命令。"
    var hasLoaded = false

    init(
        client: ComposeCLIClient = ComposeCLIClient(),
        persistenceURL: URL = AppPaths.composeProjectsURL
    ) {
        self.client = client
        self.persistenceURL = persistenceURL
    }

    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        do {
            guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
                projects = []
                return
            }
            let data = try Data(contentsOf: persistenceURL)
            let records = try JSONDecoder.containerDesktop.decode([ComposeProjectRecord].self, from: data)
            projects = records.compactMap { record in
                let url = URL(fileURLWithPath: record.path)
                return try? ComposeParser.parse(fileURL: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadProjects() async {
        isLoading = true
        defer { isLoading = false }
        projects = projects.compactMap { try? ComposeParser.parse(fileURL: $0.path) }
        persist()
    }

    func addProject(fileURL: URL) async {
        do {
            let project = try ComposeParser.parse(fileURL: fileURL)
            projects.removeAll { $0.id == project.id }
            projects.insert(project, at: 0)
            persist()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeProject(_ project: ComposeProject) {
        projects.removeAll { $0.id == project.id }
        persist()
    }

    func build(_ project: ComposeProject, services: [String] = [], noCache: Bool = false) async {
        await perform(project: project, label: "Build") {
            try await client.build(composePath: project.path, services: services, noCache: noCache)
        }
    }

    func up(_ project: ComposeProject, services: [String] = []) async {
        await perform(project: project, label: "Up") {
            try await client.up(composePath: project.path, services: services)
        }
    }

    func down(_ project: ComposeProject, services: [String] = []) async {
        await perform(project: project, label: "Down") {
            try await client.down(composePath: project.path, services: services)
        }
    }

    private func perform(project: ComposeProject, label: String, operation: () async throws -> CommandResult) async {
        busyProjectID = project.id
        errorMessage = nil
        lastOutput = "\(label) \(project.name)..."
        defer { busyProjectID = nil }

        do {
            let result = try await operation()
            lastOutput = [result.stdout, result.stderr]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: "\n")
            if lastOutput.isEmpty {
                lastOutput = "\(label) 完成。"
            }
        } catch {
            errorMessage = error.localizedDescription
            lastOutput = error.localizedDescription
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let records = projects.map {
                ComposeProjectRecord(
                    path: $0.path.path,
                    name: $0.name,
                    services: $0.services.count,
                    lastOpened: Date()
                )
            }
            let data = try JSONEncoder.containerDesktop.encode(records)
            try data.write(to: persistenceURL, options: [.atomic])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
