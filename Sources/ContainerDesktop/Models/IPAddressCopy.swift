import Foundation

enum IPAddressCopy {
    static func normalized(_ value: String?) -> String? {
        guard var text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              !isUnavailable(text) else {
            return nil
        }

        if text.hasPrefix("[") {
            if let closingBracket = text.firstIndex(of: "]") {
                text = String(text[text.index(after: text.startIndex)..<closingBracket])
            } else {
                text.removeFirst()
            }
        }

        if let slash = text.firstIndex(of: "/") {
            text = String(text[..<slash])
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isUnavailable(text) else { return nil }
        return text
    }

    private static func isUnavailable(_ value: String) -> Bool {
        switch value.lowercased() {
        case "—", "-", "n/a", "none", "null":
            return true
        default:
            return false
        }
    }
}
