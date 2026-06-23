import Foundation

enum TerminalReplayOperation: Equatable, Sendable {
    case append(String)
    case replaceActiveLine(String)
}

struct TerminalReplayFrame: Equatable, Sendable {
    var feedText: String
    var operations: [TerminalReplayOperation]
    var replaceableSuffixCharacterCount: Int

    var snapshotText: String {
        operations.reduce(into: "") { result, operation in
            switch operation {
            case .append(let text), .replaceActiveLine(let text):
                result.append(text)
            }
        }
    }

    var isPureReplaceable: Bool {
        guard replaceableSuffixCharacterCount > 0,
              replaceableSuffixCharacterCount == snapshotText.count,
              operations.count == 1
        else {
            return false
        }
        if case .replaceActiveLine = operations[0] {
            return true
        }
        return false
    }

    init(
        feedText: String,
        snapshotText: String,
        replaceableSuffixCharacterCount: Int
    ) {
        self.feedText = feedText
        operations = snapshotText.isEmpty ? [] : [.append(snapshotText)]
        self.replaceableSuffixCharacterCount = replaceableSuffixCharacterCount
    }

    init(
        feedText: String,
        operations: [TerminalReplayOperation],
        replaceableSuffixCharacterCount: Int
    ) {
        self.feedText = feedText
        self.operations = operations
        self.replaceableSuffixCharacterCount = replaceableSuffixCharacterCount
    }
}

enum TerminalOverwriteReplayCompactor {
    static func compact(_ text: String) -> TerminalReplayFrame {
        guard requiresSnapshotCompaction(text) else {
            return TerminalReplayFrame(
                feedText: text,
                snapshotText: text,
                replaceableSuffixCharacterCount: 0
            )
        }

        var snapshotText = ""
        var replaceableSuffixCharacterCount = 0
        var operations: [TerminalReplayOperation] = []

        for segment in segmentsSplitAfterLineFeed(text) {
            let compacted = compactSegment(segment)
            if compacted.shouldApplyOperation {
                operations.append(compacted.operation)
            }
            snapshotText.append(compacted.text)
            replaceableSuffixCharacterCount = compacted.isReplaceable ? compacted.text.count : 0
        }

        return TerminalReplayFrame(
            feedText: text,
            operations: operations,
            replaceableSuffixCharacterCount: replaceableSuffixCharacterCount
        )
    }

    private static func compactSegment(_ segment: String) -> CompactedSegment {
        guard requiresSnapshotCompaction(segment) else {
            return CompactedSegment(text: segment, isReplaceable: false, operation: .append(segment))
        }

        let endedWithNewline = hasLineFeedSuffix(segment)
        var bodyScalars = Array(segment.unicodeScalars)
        if endedWithNewline {
            bodyScalars.removeLast()
            if bodyScalars.last?.value == 13 {
                bodyScalars.removeLast()
            }
        } else if bodyScalars.last?.value == 13 {
            bodyScalars.removeLast()
        }

        let parsed = visibleLineSnapshot(from: bodyScalars)

        if endedWithNewline {
            let text = parsed.text + "\n"
            if parsed.didReplaceActiveLine {
                return CompactedSegment(text: text, isReplaceable: false, operation: .replaceActiveLine(text))
            }
            return CompactedSegment(text: text, isReplaceable: false, operation: .append(text))
        }

        if hasCarriageReturnSuffix(segment) || parsed.didReplaceActiveLine {
            return CompactedSegment(text: parsed.text, isReplaceable: true, operation: .replaceActiveLine(parsed.text))
        }

        return CompactedSegment(text: parsed.text, isReplaceable: false, operation: .append(parsed.text))
    }

    private static func containsCarriageReturn(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value == 13 }
    }

    private static func containsLineRedrawCSI(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count >= 3 else { return false }
        var index = 0
        while index + 2 < scalars.count {
            guard scalars[index].value == 27, scalars[index + 1].value == 91 else {
                index += 1
                continue
            }
            var finalIndex = index + 2
            while finalIndex < scalars.count {
                let value = scalars[finalIndex].value
                if value >= 0x40, value <= 0x7E {
                    return value == 0x47 || value == 0x4B
                }
                finalIndex += 1
            }
            return false
        }
        return false
    }

    private static func requiresSnapshotCompaction(_ text: String) -> Bool {
        containsCarriageReturn(text) || containsLineRedrawCSI(text)
    }

    private static func hasLineFeedSuffix(_ text: String) -> Bool {
        text.unicodeScalars.last?.value == 10
    }

    private static func hasCarriageReturnSuffix(_ text: String) -> Bool {
        text.unicodeScalars.last?.value == 13
    }

    private static func segmentsSplitAfterLineFeed(_ text: String) -> [String] {
        var segments: [String] = []
        var currentScalars: [UnicodeScalar] = []
        for scalar in text.unicodeScalars {
            currentScalars.append(scalar)
            if scalar.value == 10 {
                segments.append(String(String.UnicodeScalarView(currentScalars)))
                currentScalars.removeAll(keepingCapacity: true)
            }
        }
        if !currentScalars.isEmpty {
            segments.append(String(String.UnicodeScalarView(currentScalars)))
        }
        return segments
    }

    private static func visibleLineSnapshot(from scalars: [UnicodeScalar]) -> (text: String, didReplaceActiveLine: Bool) {
        var visibleScalars: [UnicodeScalar] = []
        var didReplaceActiveLine = false
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]
            if scalar.value == 13 {
                visibleScalars.removeAll(keepingCapacity: true)
                didReplaceActiveLine = true
                index += 1
                continue
            }

            if scalar.value == 27,
               index + 1 < scalars.count,
               scalars[index + 1].value == 91,
               let sequence = csiSequence(in: scalars, startingAt: index) {
                switch sequence.finalValue {
                case 0x47 where isHomeColumnCSIParameter(sequence.parameters):
                    visibleScalars.removeAll(keepingCapacity: true)
                    didReplaceActiveLine = true
                    index = sequence.endIndex
                    continue
                case 0x4B:
                    if shouldClearVisibleLineForEraseLine(sequence.parameters, visibleScalars: visibleScalars) {
                        visibleScalars.removeAll(keepingCapacity: true)
                    }
                    didReplaceActiveLine = true
                    index = sequence.endIndex
                    continue
                default:
                    visibleScalars.append(contentsOf: scalars[index..<sequence.endIndex])
                    index = sequence.endIndex
                    continue
                }
            }

            visibleScalars.append(scalar)
            index += 1
        }

        return (
            String(String.UnicodeScalarView(visibleScalars)),
            didReplaceActiveLine
        )
    }

    private static func csiSequence(in scalars: [UnicodeScalar], startingAt startIndex: Int) -> CSISequence? {
        var index = startIndex + 2
        while index < scalars.count {
            let value = scalars[index].value
            if value >= 0x40, value <= 0x7E {
                let parameters = String(String.UnicodeScalarView(scalars[(startIndex + 2)..<index]))
                return CSISequence(
                    parameters: parameters,
                    finalValue: value,
                    endIndex: index + 1
                )
            }
            index += 1
        }
        return nil
    }

    private static func isHomeColumnCSIParameter(_ parameters: String) -> Bool {
        let firstParameter = parameters.split(separator: ";", omittingEmptySubsequences: false).first
        guard let firstParameter, !firstParameter.isEmpty else { return true }
        return Int(firstParameter).map { $0 <= 1 } ?? false
    }

    private static func shouldClearVisibleLineForEraseLine(_ parameters: String, visibleScalars: [UnicodeScalar]) -> Bool {
        let mode = Int(parameters.split(separator: ";", omittingEmptySubsequences: false).first ?? "") ?? 0
        return visibleScalars.isEmpty || mode != 0
    }

    private struct CompactedSegment {
        var text: String
        var isReplaceable: Bool
        var operation: TerminalReplayOperation

        var shouldApplyOperation: Bool {
            !text.isEmpty || {
                if case .replaceActiveLine = operation {
                    return true
                }
                return false
            }()
        }
    }

    private struct CSISequence {
        var parameters: String
        var finalValue: UInt32
        var endIndex: Int
    }
}
