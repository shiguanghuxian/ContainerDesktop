import Foundation

enum TerminalSnapshotReplayText {
    static func feedText(from snapshotText: String) -> String {
        guard snapshotText.unicodeScalars.contains(where: { $0.value == 10 }) else {
            return snapshotText
        }

        let carriageReturn = "\r".unicodeScalars.first!
        var replayScalars = String.UnicodeScalarView()
        replayScalars.reserveCapacity(snapshotText.unicodeScalars.count)
        var previousWasCarriageReturn = false

        for scalar in snapshotText.unicodeScalars {
            if scalar.value == 10, !previousWasCarriageReturn {
                replayScalars.append(carriageReturn)
            }
            replayScalars.append(scalar)
            previousWasCarriageReturn = scalar.value == 13
        }

        return String(replayScalars)
    }
}
