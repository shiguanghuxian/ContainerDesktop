import Foundation
import Observation

@MainActor
@Observable
final class VolumeBrowserStore {
    private let service: VolumeBrowserService

    var snapshot: VolumeDirectorySnapshot?
    var isLoading = false
    var isImportExportRunning = false
    var isFileOperationRunning = false
    var statusMessage: String?
    var isError = false

    init(service: VolumeBrowserService = VolumeBrowserService()) {
        self.service = service
    }

    func load(volume: VolumeSummary, relativePath: String = "") {
        isLoading = true
        isError = false
        statusMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try service.list(sourcePath: volume.source, relativePath: relativePath)
        } catch {
            snapshot = nil
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func open(_ entry: VolumeFileEntry) {
        guard entry.isDirectory, let snapshot else { return }
        let relativePath = entry.url.path
            .replacingOccurrences(of: snapshot.sourceURL.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        do {
            self.snapshot = try service.list(sourcePath: snapshot.sourceURL.path, relativePath: relativePath)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func goUp() {
        guard let snapshot else { return }
        let path = snapshot.relativePath
            .split(separator: "/")
            .dropLast()
            .map(String.init)
            .joined(separator: "/")
        do {
            self.snapshot = try service.list(sourcePath: snapshot.sourceURL.path, relativePath: path)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func export(volume: VolumeSummary, outputPath: String) async {
        guard !isImportExportRunning else { return }
        isImportExportRunning = true
        statusMessage = nil
        isError = false
        defer { isImportExportRunning = false }

        do {
            let output = try await service.exportVolume(sourcePath: volume.source, outputPath: outputPath)
            statusMessage = output.nilIfBlank ?? "卷已导出到 \(outputPath)。"
            load(volume: volume, relativePath: snapshot?.relativePath ?? "")
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func importArchive(volume: VolumeSummary, archivePath: String) async {
        guard !isImportExportRunning else { return }
        isImportExportRunning = true
        statusMessage = nil
        isError = false
        defer { isImportExportRunning = false }

        do {
            let output = try await service.importArchive(sourcePath: volume.source, archivePath: archivePath)
            statusMessage = output.nilIfBlank ?? "归档已导入到卷 \(volume.name)。"
            load(volume: volume, relativePath: snapshot?.relativePath ?? "")
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func createDirectory(volume: VolumeSummary, name: String) async {
        guard !isFileOperationRunning else { return }
        isFileOperationRunning = true
        statusMessage = nil
        isError = false
        let relativePath = snapshot?.relativePath ?? ""
        defer { isFileOperationRunning = false }

        do {
            statusMessage = try await service.createDirectory(
                sourcePath: volume.source,
                relativePath: relativePath,
                name: name
            )
            load(volume: volume, relativePath: relativePath)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func renameEntry(volume: VolumeSummary, entry: VolumeFileEntry, newName: String) async {
        guard !isFileOperationRunning else { return }
        isFileOperationRunning = true
        statusMessage = nil
        isError = false
        let relativePath = snapshot?.relativePath ?? ""
        defer { isFileOperationRunning = false }

        do {
            statusMessage = try await service.renameEntry(
                sourcePath: volume.source,
                entryPath: entry.url.path,
                newName: newName
            )
            load(volume: volume, relativePath: relativePath)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func deleteEntry(volume: VolumeSummary, entry: VolumeFileEntry) async {
        guard !isFileOperationRunning else { return }
        isFileOperationRunning = true
        statusMessage = nil
        isError = false
        let relativePath = snapshot?.relativePath ?? ""
        defer { isFileOperationRunning = false }

        do {
            statusMessage = try await service.deleteEntry(
                sourcePath: volume.source,
                entryPath: entry.url.path
            )
            load(volume: volume, relativePath: relativePath)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }
}
