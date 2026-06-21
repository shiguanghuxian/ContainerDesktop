import Foundation

enum VolumeBrowserError: LocalizedError, Sendable {
    case invalidSource
    case invalidDestination
    case invalidName
    case destinationNotEmpty
    case destinationExists
    case pathEscapesVolume
    case notDirectory
    case containerVolumeArchiveUnsupported

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
        case .containerVolumeArchiveUnsupported:
            return "该卷来源是 ext4 镜像文件，当前仅支持目录浏览、创建目录、重命名、删除、清空和克隆；导入/导出归档暂未支持。"
        }
    }
}

struct VolumeBrowserService: Sendable {
    private let runner: CommandRunner
    private let browserImage = "docker.io/library/alpine:3.22"

    init(runner: CommandRunner = CommandRunner()) {
        self.runner = runner
    }

    func list(volumeName: String, sourcePath: String, relativePath: String = "") async throws -> VolumeDirectorySnapshot {
        if isHostDirectory(sourcePath) {
            return try list(sourcePath: sourcePath, relativePath: relativePath)
        }
        return try await listContainerVolume(volumeName: volumeName, relativePath: relativePath)
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
                modifiedAt: values.contentModificationDate,
                isHostBacked: true
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
            entries: entries,
            isHostBacked: true
        )
    }

    func exportVolume(volumeName: String, sourcePath: String, outputPath: String) async throws -> String {
        guard isHostDirectory(sourcePath) else {
            throw VolumeBrowserError.containerVolumeArchiveUnsupported
        }
        return try await exportVolume(sourcePath: sourcePath, outputPath: outputPath)
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

    func importArchive(volumeName: String, sourcePath: String, archivePath: String) async throws -> String {
        guard isHostDirectory(sourcePath) else {
            throw VolumeBrowserError.containerVolumeArchiveUnsupported
        }
        return try await importArchive(sourcePath: sourcePath, archivePath: archivePath)
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

    func createDirectory(volumeName: String, sourcePath: String, relativePath: String, name: String) async throws -> String {
        if isHostDirectory(sourcePath) {
            return try await createDirectory(sourcePath: sourcePath, relativePath: relativePath, name: name)
        }

        let relativePath = try safeRelativePath(relativePath)
        let directoryName = try validFileName(name)
        let result = try await runSingleVolumeCommand(volumeName: volumeName, arguments: [relativePath, directoryName], script: """
        set -eu
        rel="$1"
        name="$2"
        base="/mnt"
        if [ -n "$rel" ]; then base="/mnt/$rel"; fi
        if [ ! -d "$base" ]; then
          printf '父目录不存在：%s\\n' "$base" >&2
          exit 66
        fi
        target="$base/$name"
        if [ -e "$target" ]; then
          printf '目标名称已存在：%s\\n' "$target" >&2
          exit 73
        fi
        mkdir "$target"
        printf '目录 %s 已创建。\\n' "$name"
        """)
        return result.combinedOutput
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

    func renameEntry(volumeName: String, sourcePath: String, entryPath: String, newName: String) async throws -> String {
        if isHostDirectory(sourcePath) {
            return try await renameEntry(sourcePath: sourcePath, entryPath: entryPath, newName: newName)
        }

        let entryRelativePath = try containerEntryRelativePath(volumeName: volumeName, entryPath: entryPath)
        let resolvedName = try validFileName(newName)
        let result = try await runSingleVolumeCommand(volumeName: volumeName, arguments: [entryRelativePath, resolvedName], script: """
        set -eu
        rel="$1"
        new_name="$2"
        entry="/mnt/$rel"
        if [ ! -e "$entry" ]; then
          printf '文件项不存在：%s\\n' "$entry" >&2
          exit 66
        fi
        parent="${entry%/*}"
        target="$parent/$new_name"
        if [ "$entry" = "$target" ]; then
          printf '名称未变化。\\n'
          exit 0
        fi
        if [ -e "$target" ]; then
          printf '目标名称已存在：%s\\n' "$target" >&2
          exit 73
        fi
        old_name="${entry##*/}"
        mv "$entry" "$target"
        printf '%s 已重命名为 %s。\\n' "$old_name" "$new_name"
        """)
        return result.combinedOutput
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

    func deleteEntry(volumeName: String, sourcePath: String, entryPath: String) async throws -> String {
        if isHostDirectory(sourcePath) {
            return try await deleteEntry(sourcePath: sourcePath, entryPath: entryPath)
        }

        let entryRelativePath = try containerEntryRelativePath(volumeName: volumeName, entryPath: entryPath)
        let result = try await runSingleVolumeCommand(volumeName: volumeName, arguments: [entryRelativePath], script: """
        set -eu
        rel="$1"
        entry="/mnt/$rel"
        if [ ! -e "$entry" ]; then
          printf '文件项不存在：%s\\n' "$entry" >&2
          exit 66
        fi
        name="${entry##*/}"
        rm -rf "$entry"
        printf '%s 已删除。\\n' "$name"
        """)
        return result.combinedOutput
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

    func cloneVolume(
        sourceVolumeName: String,
        sourcePath: String,
        destinationVolumeName: String,
        destinationPath: String
    ) async throws -> String {
        if isHostDirectory(sourcePath), isHostDirectory(destinationPath) {
            return try await cloneVolume(sourcePath: sourcePath, destinationPath: destinationPath)
        }

        let result = try await runTwoVolumeCommand(
            sourceVolumeName: sourceVolumeName,
            destinationVolumeName: destinationVolumeName,
            arguments: [sourceVolumeName, destinationVolumeName],
            script: """
            set -eu
            if find /dst -mindepth 1 -maxdepth 1 | read _; then
              printf '目标卷不是空目录：%s\\n' "$2" >&2
              exit 74
            fi
            cp -a /src/. /dst/
            printf '卷内容已克隆到 %s。\\n' "$2"
            """
        )
        return result.combinedOutput
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

    func emptyVolume(volumeName: String, sourcePath: String) async throws -> String {
        if isHostDirectory(sourcePath) {
            return try await emptyVolume(sourcePath: sourcePath)
        }

        let result = try await runSingleVolumeCommand(volumeName: volumeName, script: """
        set -eu
        for item in /mnt/* /mnt/.[!.]* /mnt/..?*; do
          [ -e "$item" ] || continue
          rm -rf "$item"
        done
        printf '卷内容已清空。\\n'
        """)
        return result.combinedOutput
    }

    func emptyVolume(sourcePath: String) async throws -> String {
        let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
        _ = try list(sourcePath: sourceURL.path)
        return try await Task.detached(priority: .userInitiated) {
            try Self.removeContents(of: sourceURL)
            return "卷内容已清空。"
        }.value
    }

    func writeDemoFiles(volumeName: String, sourcePath: String) async throws -> String {
        if isHostDirectory(sourcePath) {
            let sourceURL = URL(fileURLWithPath: sourcePath, isDirectory: true).standardizedFileURL
            try FileManager.default.createDirectory(
                at: sourceURL.appending(path: "config", directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: sourceURL.appending(path: "logs", directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: sourceURL.appending(path: "data", directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
            try Self.demoReadme.write(to: sourceURL.appending(path: "README.md"), atomically: true, encoding: .utf8)
            try Self.demoEnv.write(to: sourceURL.appending(path: "config/app.env"), atomically: true, encoding: .utf8)
            try Self.demoLog.write(to: sourceURL.appending(path: "logs/app.log"), atomically: true, encoding: .utf8)
            try Self.demoJSON.write(to: sourceURL.appending(path: "data/sample.json"), atomically: true, encoding: .utf8)
            return "示例文件已写入 \(volumeName)。"
        }

        let result = try await runSingleVolumeCommand(volumeName: volumeName, standardInput: Self.demoFileScript)
        return result.combinedOutput.nilIfBlank ?? "示例文件已写入 \(volumeName)。"
    }

    private func listContainerVolume(volumeName: String, relativePath: String) async throws -> VolumeDirectorySnapshot {
        let cleanRelativePath = try safeRelativePath(relativePath)
        let result = try await runSingleVolumeCommand(volumeName: volumeName, arguments: [cleanRelativePath], script: """
        set -eu
        rel="$1"
        base="/mnt"
        if [ -n "$rel" ]; then base="/mnt/$rel"; fi
        if [ ! -d "$base" ]; then
          printf '目录不存在：%s\\n' "$base" >&2
          exit 66
        fi
        for item in "$base"/* "$base"/.[!.]* "$base"/..?*; do
          [ -e "$item" ] || continue
          name="${item##*/}"
          if [ -d "$item" ]; then
            kind="d"
            size=""
          else
            kind="f"
            size="$(wc -c < "$item" | tr -d ' ')"
          fi
          modified="$(stat -c %Y "$item" 2>/dev/null || true)"
          printf '%s\\t%s\\t%s\\t%s\\n' "$kind" "$size" "$modified" "$name"
        done
        """)

        let sourceURL = virtualSourceURL(volumeName: volumeName)
        let currentURL = cleanRelativePath.isEmpty
            ? sourceURL
            : sourceURL.appending(path: cleanRelativePath, directoryHint: .isDirectory)
        let entries = result.stdout
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> VolumeFileEntry? in
                let parts = String(line).split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count == 4 else { return nil }
                let isDirectory = parts[0] == "d"
                let name = String(parts[3])
                let entryRelativePath = [cleanRelativePath, name]
                    .filter { !$0.isEmpty }
                    .joined(separator: "/")
                let url = sourceURL.appending(
                    path: entryRelativePath,
                    directoryHint: isDirectory ? .isDirectory : .notDirectory
                )
                let size = Int64(parts[1])
                let modified = TimeInterval(parts[2]).map(Date.init(timeIntervalSince1970:))
                return VolumeFileEntry(
                    name: name,
                    url: url,
                    isDirectory: isDirectory,
                    size: size,
                    modifiedAt: modified,
                    isHostBacked: false
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return VolumeDirectorySnapshot(
            sourceURL: sourceURL,
            currentURL: currentURL,
            relativePath: cleanRelativePath,
            entries: entries,
            isHostBacked: false
        )
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

    private func isHostDirectory(_ sourcePath: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: sourcePath, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func safeRelativePath(_ relativePath: String) throws -> String {
        relativePath
            .split(separator: "/")
            .filter { $0 != "." && $0 != ".." }
            .map(String.init)
            .joined(separator: "/")
    }

    private func virtualSourceURL(volumeName: String) -> URL {
        URL(fileURLWithPath: "/ContainerDesktopVolumes/\(volumeName)", isDirectory: true)
    }

    private func containerEntryRelativePath(volumeName: String, entryPath: String) throws -> String {
        let sourcePath = virtualSourceURL(volumeName: volumeName).path
        let entry = URL(fileURLWithPath: entryPath).standardizedFileURL.path
        guard entry.hasPrefix(sourcePath + "/") else {
            throw VolumeBrowserError.pathEscapesVolume
        }
        return String(entry.dropFirst(sourcePath.count + 1))
    }

    private func runSingleVolumeCommand(
        volumeName: String,
        arguments: [String] = [],
        script: String? = nil,
        standardInput: String? = nil
    ) async throws -> CommandResult {
        try await runner.run(
            executable: "container",
            arguments: ["run", "--rm", "-i", "-v", "\(volumeName):/mnt", browserImage, "sh", "-s", "--"] + arguments,
            timeout: 300,
            standardInput: standardInput ?? script
        )
    }

    private func runTwoVolumeCommand(
        sourceVolumeName: String,
        destinationVolumeName: String,
        arguments: [String] = [],
        script: String
    ) async throws -> CommandResult {
        try await runner.run(
            executable: "container",
            arguments: [
                "run", "--rm", "-i",
                "-v", "\(sourceVolumeName):/src",
                "-v", "\(destinationVolumeName):/dst",
                browserImage, "sh", "-s", "--",
            ] + arguments,
            timeout: 600,
            standardInput: script
        )
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

    private static let demoReadme = """
    # ContainerDesktop volume demo

    This file was generated for testing the Volumes page.
    """

    private static let demoEnv = """
    APP_ENV=demo
    CACHE_DRIVER=file
    """

    private static let demoLog = """
    2026-06-18T14:00:00Z demo volume initialized
    2026-06-18T14:01:00Z files ready
    """

    private static let demoJSON = """
    {
      "name": "cd-demo-files",
      "items": ["README.md", "config/app.env", "logs/app.log"]
    }
    """

    static let demoFileScript = """
    set -eu
    mkdir -p /mnt/config /mnt/logs /mnt/data
    cat > /mnt/README.md <<'EOF'
    \(demoReadme)
    EOF
    cat > /mnt/config/app.env <<'EOF'
    \(demoEnv)
    EOF
    cat > /mnt/logs/app.log <<'EOF'
    \(demoLog)
    EOF
    cat > /mnt/data/sample.json <<'EOF'
    \(demoJSON)
    EOF
    printf '示例文件已写入卷。\\n'
    """
}
