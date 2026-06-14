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
}
