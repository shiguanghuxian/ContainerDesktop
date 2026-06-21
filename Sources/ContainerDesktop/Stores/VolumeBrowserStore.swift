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

    @discardableResult
    func load(volume: VolumeSummary, relativePath: String = "", resetStatus: Bool = true) async -> Bool {
        isLoading = true
        if resetStatus {
            isError = false
            statusMessage = nil
        }
        defer { isLoading = false }

        do {
            snapshot = try await service.list(
                volumeName: volume.name,
                sourcePath: volume.source,
                relativePath: relativePath
            )
            return true
        } catch {
            snapshot = nil
            statusMessage = error.localizedDescription
            isError = true
            return false
        }
    }

    func open(_ entry: VolumeFileEntry, volume: VolumeSummary) async {
        guard entry.isDirectory, let snapshot else { return }
        let relativePath = entry.url.path
            .replacingOccurrences(of: snapshot.sourceURL.path, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        do {
            self.snapshot = try await service.list(
                volumeName: volume.name,
                sourcePath: volume.source,
                relativePath: relativePath
            )
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func goUp(volume: VolumeSummary) async {
        guard let snapshot else { return }
        let path = snapshot.relativePath
            .split(separator: "/")
            .dropLast()
            .map(String.init)
            .joined(separator: "/")
        do {
            self.snapshot = try await service.list(
                volumeName: volume.name,
                sourcePath: volume.source,
                relativePath: path
            )
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
            let output = try await service.exportVolume(
                volumeName: volume.name,
                sourcePath: volume.source,
                outputPath: outputPath
            )
            statusMessage = output.nilIfBlank ?? "卷已导出到 \(outputPath)。"
            await load(volume: volume, relativePath: snapshot?.relativePath ?? "")
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
            let output = try await service.importArchive(
                volumeName: volume.name,
                sourcePath: volume.source,
                archivePath: archivePath
            )
            statusMessage = output.nilIfBlank ?? "归档已导入到卷 \(volume.name)。"
            await load(volume: volume, relativePath: snapshot?.relativePath ?? "")
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
            let output = try await service.createDirectory(
                volumeName: volume.name,
                sourcePath: volume.source,
                relativePath: relativePath,
                name: name
            )
            statusMessage = output
            do {
                isLoading = true
                defer { isLoading = false }
                snapshot = try await service.list(
                    volumeName: volume.name,
                    sourcePath: volume.source,
                    relativePath: relativePath
                )
            } catch {
                statusMessage = "\(output)\n创建成功，但刷新目录失败：\(error.localizedDescription)"
                isError = true
            }
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
                volumeName: volume.name,
                sourcePath: volume.source,
                entryPath: entry.url.path,
                newName: newName
            )
            await load(volume: volume, relativePath: relativePath)
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
                volumeName: volume.name,
                sourcePath: volume.source,
                entryPath: entry.url.path
            )
            await load(volume: volume, relativePath: relativePath)
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }
}
