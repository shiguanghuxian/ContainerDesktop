import Foundation

enum TerminalSessionState: Hashable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

struct TerminalOutputEvent: Identifiable, Equatable, Sendable {
    var id: Int { sequence }
    let sequence: Int
    let text: String
    let isReplaceable: Bool

    init(sequence: Int, text: String, isReplaceable: Bool = false) {
        self.sequence = sequence
        self.text = text
        self.isReplaceable = isReplaceable
    }
}
