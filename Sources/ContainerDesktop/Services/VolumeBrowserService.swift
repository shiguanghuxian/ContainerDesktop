import Foundation

enum VolumeBrowserError: LocalizedError, Sendable {
    case invalidSource
    case invalidDestination
    case invalidName
    case destinationNotEmpty
    case destinationExists
    case pathEscapesVolume
    case notDirectory

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "卷来源路径不可用。"
        case .invalidDestination:
            return "目标卷路径不可用。"
        case .invalidName:
            return "名称不能为空，且不能包含路径分隔符。"
        case .destinationNotEmpty:
            return "目标卷不是空目录，无法克隆。"
        case .destinationExists:
            return "目标名称已存在。"
        case .pathEscapesVolume:
            return "目标路径超出卷目录。"
        case .notDirectory:
            return "目标不是目录。"
        }
    }
}

struct VolumeBrowserService: Sendable {
    private let runner: CommandRunner

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func list(sourcePath: String, relativePath: String = "") throws -> VolumeDirectorySnapshot {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        var isDirectory: ObjCBool = false
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw VolumeBrowserError.invalidSource
        }

        let currentURL = try resolvedURL(sourceURL: sourceURL, relativePath: relativePath)
        guard fileManager.fileExists(atPath: currentURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw VolumeBrowserError.notDirectory
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = try fileManager.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        )
        let entries = try urls.map { url in
            let values = try url.resourceValues(forKeys: keys)
            return VolumeFileEntry(
                name: url.lastPathComponent,
                url: url,
                isDirectory: values.isDirectory ?? false,
                size: values.fileSize.map(Int64.init),
                modifiedAt: values.contentModificationDate
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return VolumeDirectorySnapshot(
            sourceURL: sourceURL,
            currentURL: currentURL,
            relativePath: normalizedRelativePath(sourceURL: sourceURL, url: currentURL),
            entries: entries
        )
    }

    func exportVolume(sourcePath: String, outputPath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        return try await runner.run(
            executable: "tar",
            arguments: ["-C", sourceURL.path, "-cf", outputPath, "."],
            timeout: 1800
        ).combinedOutput
    }

    func importArchive(sourcePath: String, archivePath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        return try await runner.run(
            executable: "tar",
            arguments: ["-C", sourceURL.path, "-xf", archivePath],
            timeout: 1800
        ).combinedOutput
    }

    func createDirectory(sourcePath: String, relativePath: String, name: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        let parentURL = try resolvedURL(sourceURL: sourceURL, relativePath: relativePath)
        let directoryName = try validFileName(name)
        let targetURL = try childURL(sourceURL: sourceURL, parentURL: parentURL, name: directoryName)
        guard !FileManager.default.fileExists(atPath: targetURL.path) else {
            throw VolumeBrowserError.destinationExists
        }

        return try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: false)
            return "目录 \(directoryName) 已创建。"
        }.value
    }

    func renameEntry(sourcePath: String, entryPath: String, newName: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        let entryURL = try entryURL(sourceURL: sourceURL, entryPath: entryPath)
        let resolvedName = try validFileName(newName)
        let targetURL = try childURL(
            sourceURL: sourceURL,
            parentURL: entryURL.deletingLastPathComponent(),
            name: resolvedName
        )
        guard entryURL.path != targetURL.path else {
            return "名称未变化。"
        }
        guard !FileManager.default.fileExists(atPath: targetURL.path) else {
            throw VolumeBrowserError.destinationExists
        }

        return try await Task.detached(priority: .userInitiated) {
            try FileManager.default.moveItem(at: entryURL, to: targetURL)
            return "\(entryURL.lastPathComponent) 已重命名为 \(resolvedName)。"
        }.value
    }

    func deleteEntry(sourcePath: String, entryPath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        let entryURL = try entryURL(sourceURL: sourceURL, entryPath: entryPath)

        return try await Task.detached(priority: .userInitiated) {
            try FileManager.default.removeItem(at: entryURL)
            return "\(entryURL.lastPathComponent) 已删除。"
        }.value
    }

    func cloneVolume(sourcePath: String, destinationPath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        let destinationURL = URL(fileURLWithPath: destinationPath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        _ = try list(sourcePath: destinationURL.path)
        guard sourceURL.path != destinationURL.path,
              !destinationURL.path.hasPrefix(sourceURL.path + "/"),
              !sourceURL.path.hasPrefix(destinationURL.path + "/") else {
            throw VolumeBrowserError.invalidDestination
        }

        return try await Task.detached(priority: .userInitiated) {
            try Self.copyContents(from: sourceURL, to: destinationURL)
            return "卷内容已克隆到 \(destinationURL.path)。"
        }.value
    }

    func emptyVolume(sourcePath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        return try await Task.detached(priority: .userInitiated) {
            try Self.removeContents(of: sourceURL)
            return "卷内容已清空。"
        }.value
    }

    private func resolvedURL(sourceURL: URL, relativePath: String) throws -> URL {
        let clean = relativePath
            .split(separator: "/")
            .filter { $0 != "." && $0 != ".." }
            .map(String.init)
            .joined(separator: "/")
        let url = clean.isEmpty ? sourceURL : sourceURL.appending(path: clean, directoryHint: .isDirectory)
        let standardized = url.standardizedFileURL
        guard standardized.path == sourceURL.path || standardized.path.hasPrefix(sourceURL.path + "/") else {
            throw VolumeBrowserError.pathEscapesVolume
        }
        return standardized
    }

    private func validFileName(_ name: String) throws -> String {
        let clean = name.trimmed
        guard !clean.isEmpty,
              clean != ".",
              clean != "..",
              !clean.contains("/") else {
            throw VolumeBrowserError.invalidName
        }
        return clean
    }

    private func childURL(sourceURL: URL, parentURL: URL, name: String) throws -> URL {
        let targetURL = parentURL.appending(path: name).standardizedFileURL
        guard targetURL.path.hasPrefix(sourceURL.path + "/") else {
            throw VolumeBrowserError.pathEscapesVolume
        }
        return targetURL
    }

    private func entryURL(sourceURL: URL, entryPath: String) throws -> URL {
        let url = URL(fileURLWithPath: entryPath).standardizedFileURL
        guard url.path.hasPrefix(sourceURL.path + "/") else {
            throw VolumeBrowserError.pathEscapesVolume
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VolumeBrowserError.invalidDestination
        }
        return url
    }

    private func normalizedRelativePath(sourceURL: URL, url: URL) -> String {
        let source = sourceURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let current = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard current != source, current.hasPrefix(source + "/") else { return "" }
        return String(current.dropFirst(source.count + 1))
    }

    private static func copyContents(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let existingDestinationItems = try fileManager.contentsOfDirectory(
            at: destinationURL,
            includingPropertiesForKeys: nil
        )
        guard existingDestinationItems.isEmpty else {
            throw VolumeBrowserError.destinationNotEmpty
        }

        let sourceItems = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil
        )
        for item in sourceItems {
            let destination = destinationURL.appendingPathComponent(item.lastPathComponent)
            try fileManager.copyItem(at: item, to: destination)
        }
    }

    private static func removeContents(of sourceURL: URL) throws {
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil
        )
        for item in items {
            try fileManager.removeItem(at: item)
        }
    }
}
