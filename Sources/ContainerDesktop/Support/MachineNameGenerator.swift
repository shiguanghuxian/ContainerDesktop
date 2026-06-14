import Foundation

enum MachineNameGenerator {
    private static let maxLength = 48

    static func automaticName(for imageReference: String, existingIDs: [String] = []) -> String {
        uniqueName(from: sanitized(candidateName(from: imageReference)), existingIDs: existingIDs)
    }

    private static func candidateName(from imageReference: String) -> String {
        let trimmed = imageReference.trimmed
        guard !trimmed.isEmpty else { return "machine" }

        let lastComponent = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        if let atIndex = lastComponent.firstIndex(of: "@") {
            let name = String(lastComponent[..<atIndex])
            let digest = String(lastComponent[lastComponent.index(after: atIndex)...])
                .split(separator: ":")
                .last
                .map { String($0.prefix(12)) } ?? "digest"
            return "\(name)-\(digest)"
        }

        if let colonIndex = lastComponent.lastIndex(of: ":") {
            let name = String(lastComponent[..<colonIndex])
            let tag = String(lastComponent[lastComponent.index(after: colonIndex)...])
            return "\(name)-\(tag)"
        }

        return "\(lastComponent)-latest"
    }

    private static func sanitized(_ value: String) -> String {
        let lowered = value.lowercased()
        var result = ""
        var lastWasHyphen = false

        for scalar in lowered.unicodeScalars {
            let isDigit = scalar.value >= 48 && scalar.value <= 57
            let isLowercaseASCII = scalar.value >= 97 && scalar.value <= 122
            let isAllowed = isDigit || isLowercaseASCII
            if isAllowed {
                result.unicodeScalars.append(scalar)
                lastWasHyphen = false
            } else if !lastWasHyphen {
                result.append("-")
                lastWasHyphen = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fallback = trimmed.isEmpty ? "machine" : trimmed
        return truncate(fallback)
    }

    private static func uniqueName(from base: String, existingIDs: [String]) -> String {
        let existing = Set(existingIDs)
        if !existing.contains(base) {
            return base
        }

        for index in 2...999 {
            let suffix = "-\(index)"
            let prefix = truncate(base, maxLength: maxLength - suffix.count)
            let candidate = "\(prefix)\(suffix)"
            if !existing.contains(candidate) {
                return candidate
            }
        }

        return "\(truncate(base, maxLength: maxLength - 5))-\(Int(Date().timeIntervalSince1970) % 10000)"
    }

    private static func truncate(_ value: String, maxLength: Int = maxLength) -> String {
        guard value.count > maxLength else { return value }
        return String(value.prefix(maxLength)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
