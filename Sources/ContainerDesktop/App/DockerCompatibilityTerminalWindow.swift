import AppKit

enum DockerCompatibilityTerminalTabKeyCommand: Equatable {
    case newTab
    case closeTab
    case nextTab
    case previousTab

    static func command(for event: NSEvent) -> DockerCompatibilityTerminalTabKeyCommand? {
        guard event.type == .keyDown else { return nil }
        guard let key = event.charactersIgnoringModifiers?.lowercased(), !key.isEmpty else {
            return nil
        }

        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if flags == .command, key == "t" {
            return .newTab
        }
        if flags == .command, key == "w" {
            return .closeTab
        }
        if flags == [.command, .shift], key == "]" {
            return .nextTab
        }
        if flags == [.command, .shift], key == "[" {
            return .previousTab
        }
        return nil
    }
}

@MainActor
final class DockerCompatibilityTerminalWindow: NSWindow {
    var onNewTab: (() -> Void)?
    var onCloseTab: (() -> Void)?
    var onSelectNextTab: (() -> Void)?
    var onSelectPreviousTab: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let command = DockerCompatibilityTerminalTabKeyCommand.command(for: event) else {
            return super.performKeyEquivalent(with: event)
        }

        switch command {
        case .newTab:
            onNewTab?()
        case .closeTab:
            onCloseTab?()
        case .nextTab:
            onSelectNextTab?()
        case .previousTab:
            onSelectPreviousTab?()
        }
        return true
    }
}
