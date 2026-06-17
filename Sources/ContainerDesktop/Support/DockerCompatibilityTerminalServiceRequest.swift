import AppKit
import Foundation

enum DockerCompatibilityTerminalServiceRequest {
    static let messageName = "openDockerCompatibilityTerminal"
    static let legacyFilenamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    static func workingDirectory(from pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        let urlObjects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        for object in urlObjects {
            if let url = object as? URL,
               let directory = workingDirectory(fromFileURL: url) {
                return directory
            }
            if let url = object as? NSURL,
               let directory = workingDirectory(fromFileURL: url as URL) {
                return directory
            }
        }

        if let fileURLString = pasteboard.string(forType: .fileURL),
           let url = URL(string: fileURLString),
           let directory = workingDirectory(fromFileURL: url) {
            return directory
        }

        if let paths = pasteboard.propertyList(forType: legacyFilenamesPasteboardType) as? [String] {
            for path in paths {
                if let directory = workingDirectory(fromPath: path) {
                    return directory
                }
            }
        }

        return nil
    }

    static func workingDirectory(fromPath path: String) -> URL? {
        workingDirectory(fromFileURL: URL(fileURLWithPath: path))
    }

    static func workingDirectory(fromFileURL url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        let standardizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory) else {
            return nil
        }
        if isDirectory.boolValue {
            return standardizedURL
        }
        return standardizedURL.deletingLastPathComponent()
    }
}
