import AppKit
import SwiftUI

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

struct DockerCompatibilityTerminalChromePalette: Equatable {
    var style: DockerCompatibilityTerminalStyle

    private var configuration: TerminalStyleConfiguration {
        style.configuration
    }

    var isLight: Bool {
        let background = configuration.background
        let luminance = 0.2126 * background.red + 0.7152 * background.green + 0.0722 * background.blue
        return luminance > 0.58
    }

    var preferredColorScheme: ColorScheme {
        isLight ? .light : .dark
    }

    var windowAppearanceName: NSAppearance.Name {
        isLight ? .aqua : .darkAqua
    }

    var windowBackgroundColor: NSColor {
        configuration.background.nsColor
    }

    var background: Color {
        configuration.background.color
    }

    var foreground: Color {
        configuration.foreground.color
    }

    var subduedForeground: Color {
        foreground.opacity(isLight ? 0.62 : 0.68)
    }

    var mutedForeground: Color {
        foreground.opacity(isLight ? 0.42 : 0.46)
    }

    var separator: Color {
        foreground.opacity(isLight ? 0.16 : 0.12)
    }

    var inactiveTabBackground: Color {
        foreground.opacity(isLight ? 0.045 : 0.06)
    }

    var selectedTabBackground: Color {
        configuration.selection.color.opacity(isLight ? 0.82 : 0.62)
    }

    var selectedTabBorder: Color {
        configuration.caret.color.opacity(isLight ? 0.26 : 0.30)
    }

    var controlBackground: Color {
        foreground.opacity(isLight ? 0.08 : 0.10)
    }
}

@MainActor
enum DockerCompatibilityTerminalWindowChrome {
    static let trafficLightReservedWidth: CGFloat = 78
    static let topChromeDoubleClickHeight: CGFloat = 44
    static let trailingChromeControlReservedWidth: CGFloat = 52

    static func palette(for style: DockerCompatibilityTerminalStyle) -> DockerCompatibilityTerminalChromePalette {
        DockerCompatibilityTerminalChromePalette(style: style)
    }

    static func apply(to window: NSWindow?, title: String, style: DockerCompatibilityTerminalStyle) {
        guard let window else { return }
        let palette = palette(for: style)
        window.title = title
        window.setAccessibilityTitle(title)
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unifiedCompact
        window.toolbar = nil
        window.backgroundColor = palette.windowBackgroundColor
        window.appearance = NSAppearance(named: palette.windowAppearanceName)
    }
}

@MainActor
final class DockerCompatibilityTerminalWindow: NSWindow {
    var onNewTab: (() -> Void)?
    var onCloseTab: (() -> Void)?
    var onSelectNextTab: (() -> Void)?
    var onSelectPreviousTab: (() -> Void)?
    var onSendInterrupt: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,
           event.clickCount == 2,
           shouldPerformTopChromeDoubleClickZoom(at: event.locationInWindow) {
            performZoom(nil)
            return
        }

        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if TerminalControlKeyMapper.isInterrupt(event),
           !firstResponderIsTerminalView() {
            guard let onSendInterrupt else {
                return super.performKeyEquivalent(with: event)
            }
            onSendInterrupt()
            return true
        }

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

    func shouldPerformTopChromeDoubleClickZoom(at locationInWindow: NSPoint) -> Bool {
        Self.shouldPerformTopChromeDoubleClickZoom(
            at: locationInWindow,
            in: effectiveWindowSizeForChromeHitTesting
        )
    }

    static func shouldPerformTopChromeDoubleClickZoom(
        at locationInWindow: NSPoint,
        in windowSize: NSSize
    ) -> Bool {
        guard windowSize.width > DockerCompatibilityTerminalWindowChrome.trafficLightReservedWidth
                + DockerCompatibilityTerminalWindowChrome.trailingChromeControlReservedWidth,
              windowSize.height > DockerCompatibilityTerminalWindowChrome.topChromeDoubleClickHeight,
              locationInWindow.x >= 0,
              locationInWindow.y >= 0,
              locationInWindow.x <= windowSize.width,
              locationInWindow.y <= windowSize.height
        else {
            return false
        }

        let isInTopChrome = locationInWindow.y >= windowSize.height
            - DockerCompatibilityTerminalWindowChrome.topChromeDoubleClickHeight
        let isInTrafficLightArea = locationInWindow.x <= DockerCompatibilityTerminalWindowChrome.trafficLightReservedWidth
        let isInTrailingControlArea = locationInWindow.x >= windowSize.width
            - DockerCompatibilityTerminalWindowChrome.trailingChromeControlReservedWidth

        return isInTopChrome && !isInTrafficLightArea && !isInTrailingControlArea
    }

    private var effectiveWindowSizeForChromeHitTesting: NSSize {
        let contentSize = contentView?.bounds.size ?? .zero
        return NSSize(
            width: max(frame.size.width, contentSize.width),
            height: max(frame.size.height, contentSize.height)
        )
    }

    private func firstResponderIsTerminalView() -> Bool {
        var responder = firstResponder
        while let current = responder {
            if current is FocusableTerminalView {
                return true
            }
            responder = current.nextResponder
        }
        return false
    }
}
