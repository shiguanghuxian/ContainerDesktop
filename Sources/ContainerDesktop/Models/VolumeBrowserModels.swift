import Foundation

struct VolumeFileEntry: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    var name: String
    var url: URL
    var isDirectory: Bool
    var size: Int64?
    var modifiedAt: Date?
    var isHostBacked = true

    var systemImage: String {
        isDirectory ? "folder" : "doc"
    }

    var sizeDisplay: String {
        guard !isDirectory, let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var modifiedText: String {
        guard let modifiedAt else { return "—" }
        return modifiedAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct VolumeDirectorySnapshot: Hashable, Sendable {
    var sourceURL: URL
    var currentURL: URL
    var relativePath: String
    var entries: [VolumeFileEntry]
    var isHostBacked = true

    var displayPath: String {
        relativePath.isEmpty ? "/" : "/\(relativePath)"
    }
}
