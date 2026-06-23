import Foundation

enum TerminalCurrentDirectoryResolver {
    static func localDirectoryURL(from terminalDirectory: String?) -> URL? {
        guard let rawValue = terminalDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty,
              let url = URL(string: rawValue),
              url.isFileURL
        else {
            return nil
        }

        let decodedPath = url.path.removingPercentEncoding ?? url.path
        guard !decodedPath.isEmpty, decodedPath.hasPrefix("/") else {
            return nil
        }
        return URL(fileURLWithPath: decodedPath, isDirectory: true).standardizedFileURL
    }
}
