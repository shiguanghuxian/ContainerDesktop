import AppKit
import SwiftTerm
import SwiftUI

struct TerminalContextMenuAction {
    var title: String
    var isEnabled = true
    var action: () -> Void
}

struct SwiftTermTerminalView: NSViewRepresentable {
    var textSnapshot: String
    var outputEvents: [TerminalOutputEvent]
    var outputSequence: Int
    var resetSequence: Int
    var isInputEnabled = true
    var style: TerminalStyleConfiguration = .containerDefault
    var language: AppLanguage = .system
    var contextMenuActions: [TerminalContextMenuAction] = []
    var onSizeChange: (Int, Int) -> Void = { _, _ in }
    var onCurrentDirectoryChange: (String?) -> Void = { _ in }
    var onInput: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInput: onInput,
            onSizeChange: onSizeChange,
            onCurrentDirectoryChange: onCurrentDirectoryChange
        )
    }

    func makeNSView(context: Context) -> FocusableTerminalView {
        let terminalView = FocusableTerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.autoresizingMask = [.width, .height]
        terminalView.caretViewTracksFocus = false
        terminalView.language = language
        terminalView.contextMenuActions = contextMenuActions
        terminalView.apply(style: style)
        terminalView.setInputEnabled(isInputEnabled)
        context.coordinator.terminalView = terminalView
        context.coordinator.isInputEnabled = isInputEnabled
        return terminalView
    }

    func updateNSView(_ terminalView: FocusableTerminalView, context: Context) {
        context.coordinator.onInput = onInput
        context.coordinator.onSizeChange = onSizeChange
        context.coordinator.onCurrentDirectoryChange = onCurrentDirectoryChange
        context.coordinator.isInputEnabled = isInputEnabled
        terminalView.language = language
        terminalView.contextMenuActions = contextMenuActions
        terminalView.apply(style: style)
        terminalView.setInputEnabled(isInputEnabled)
        context.coordinator.feed(
            terminalView,
            textSnapshot: textSnapshot,
            outputEvents: outputEvents,
            outputSequence: outputSequence,
            resetSequence: resetSequence
        )
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        var onInput: (Data) -> Void
        var onSizeChange: (Int, Int) -> Void
        var onCurrentDirectoryChange: (String?) -> Void
        var isInputEnabled = true
        weak var terminalView: TerminalView?
        private var lastOutputSequence = 0
        private var lastResetSequence: Int?
        private var didSeedSnapshot = false
        private(set) var terminalColumns = 0
        private(set) var terminalRows = 0
        private var pendingSnapshotReplay: PendingSnapshotReplay?

        init(
            onInput: @escaping (Data) -> Void,
            onSizeChange: @escaping (Int, Int) -> Void,
            onCurrentDirectoryChange: @escaping (String?) -> Void = { _ in }
        ) {
            self.onInput = onInput
            self.onSizeChange = onSizeChange
            self.onCurrentDirectoryChange = onCurrentDirectoryChange
        }

        @objc @MainActor func focusTerminal() {
            guard isInputEnabled else { return }
            guard let terminalView else { return }
            terminalView.window?.makeFirstResponder(terminalView)
        }

        @MainActor
        func feed(
            _ terminalView: TerminalView,
            textSnapshot: String,
            outputEvents: [TerminalOutputEvent],
            outputSequence: Int,
            resetSequence: Int
        ) {
            if lastResetSequence != resetSequence {
                requestResetOrReplay(
                    terminalView,
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }

            guard didSeedSnapshot else {
                requestResetOrReplay(
                    terminalView,
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }

            guard outputSequence != lastOutputSequence else { return }
            let pendingEvents = outputEvents.filter { $0.sequence > lastOutputSequence }
            guard !pendingEvents.isEmpty else {
                lastOutputSequence = outputSequence
                return
            }

            if let firstEvent = pendingEvents.first,
               firstEvent.sequence > lastOutputSequence + 1 {
                skippedOutputGapCount += 1
                lastOutputSequence = firstEvent.sequence - 1
            }

            for event in pendingEvents {
                guard event.sequence > lastOutputSequence else { continue }
                terminalView.feed(text: event.text)
                lastOutputSequence = event.sequence
            }
        }

        private(set) var resetCount = 0
        private(set) var skippedOutputGapCount = 0
        private(set) var pendingReplayCount = 0

        var isSnapshotReplayPending: Bool {
            pendingSnapshotReplay != nil
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            guard newCols > 0, newRows > 0 else { return }
            guard newCols != terminalColumns || newRows != terminalRows else { return }
            terminalColumns = newCols
            terminalRows = newRows
            onSizeChange(newCols, newRows)
            flushPendingSnapshotReplayIfPossible(source)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            onCurrentDirectoryChange(directory)
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            guard isInputEnabled else { return }
            onInput(Data(data))
        }

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            NSWorkspace.shared.open(url)
        }

        func bell(source: TerminalView) {
            NSSound.beep()
        }

        func clipboardCopy(source: TerminalView, content: Data) {}

        func clipboardRead(source: TerminalView) -> Data? {
            nil
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        private func requestResetOrReplay(
            _ terminalView: TerminalView,
            textSnapshot: String,
            outputSequence: Int,
            resetSequence: Int
        ) {
            guard !shouldDelaySnapshotReplay(textSnapshot: textSnapshot) else {
                if pendingSnapshotReplay == nil {
                    pendingReplayCount += 1
                }
                pendingSnapshotReplay = PendingSnapshotReplay(
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }
            pendingSnapshotReplay = nil
            performResetReplay(
                terminalView,
                textSnapshot: textSnapshot,
                outputSequence: outputSequence,
                resetSequence: resetSequence
            )
        }

        private func flushPendingSnapshotReplayIfPossible(_ terminalView: TerminalView) {
            guard hasValidSnapshotReplaySize else { return }
            guard let pendingSnapshotReplay else { return }
            self.pendingSnapshotReplay = nil
            performResetReplay(
                terminalView,
                textSnapshot: pendingSnapshotReplay.textSnapshot,
                outputSequence: pendingSnapshotReplay.outputSequence,
                resetSequence: pendingSnapshotReplay.resetSequence
            )
        }

        private func shouldDelaySnapshotReplay(textSnapshot: String) -> Bool {
            !textSnapshot.isEmpty && !hasValidSnapshotReplaySize
        }

        private var hasValidSnapshotReplaySize: Bool {
            terminalColumns >= Self.minimumSnapshotReplayColumns
                && terminalRows >= Self.minimumSnapshotReplayRows
        }

        private func performResetReplay(
            _ terminalView: TerminalView,
            textSnapshot: String,
            outputSequence: Int,
            resetSequence: Int
        ) {
            resetCount += 1
            MainActor.assumeIsolated {
                terminalView.feed(text: "\u{1B}[2J\u{1B}[3J\u{1B}[H")
                if !textSnapshot.isEmpty {
                    terminalView.feed(text: TerminalSnapshotReplayText.feedText(from: textSnapshot))
                }
            }
            lastOutputSequence = outputSequence
            lastResetSequence = resetSequence
            didSeedSnapshot = true
        }

        private static let minimumSnapshotReplayColumns = 20
        private static let minimumSnapshotReplayRows = 4

        private struct PendingSnapshotReplay {
            var textSnapshot: String
            var outputSequence: Int
            var resetSequence: Int
        }
    }
}

final class FocusableTerminalView: TerminalView {
    var language: AppLanguage = .system
    var contextMenuActions: [TerminalContextMenuAction] = []
    private var didRequestInitialFocus = false
    private var inputEnabled = true
    private var currentStyle: TerminalStyleConfiguration?
    private(set) var styleApplicationCount = 0

    func apply(style: TerminalStyleConfiguration) {
        guard currentStyle != style else { return }
        currentStyle = style
        styleApplicationCount += 1
        font = NSFont.monospacedSystemFont(ofSize: style.fontSize, weight: .regular)
        nativeForegroundColor = style.foreground.nsColor
        nativeBackgroundColor = style.background.nsColor
        caretColor = style.caret.nsColor
        caretTextColor = style.caretText.nsColor
        selectedTextBackgroundColor = style.selection.nsColor
        layer?.backgroundColor = style.background.nsColor.cgColor
        setNeedsDisplay(bounds)
    }

    func setInputEnabled(_ enabled: Bool) {
        inputEnabled = enabled
        if !enabled, window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard inputEnabled, !didRequestInitialFocus else { return }
        didRequestInitialFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.inputEnabled else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        focusIfInputEnabled()
        guard let menu = menu(for: event) else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if inputEnabled,
           let bytes = TerminalControlKeyMapper.controlBytes(for: event) {
            send(bytes)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.autoenablesItems = false

        for action in contextMenuActions {
            let item = NSMenuItem(title: action.title, action: #selector(performContextMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = action.isEnabled
            item.representedObject = TerminalContextMenuActionBox(action.action)
            menu.addItem(item)
        }

        if !contextMenuActions.isEmpty {
            menu.addItem(.separator())
        }

        let copyItem = NSMenuItem(title: DockerCompatibilityTerminalStrings.copy(language), action: #selector(copy(_:)), keyEquivalent: "")
        copyItem.target = self
        copyItem.isEnabled = selectionActive
        menu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: DockerCompatibilityTerminalStrings.paste(language), action: #selector(paste(_:)), keyEquivalent: "")
        pasteItem.target = self
        pasteItem.isEnabled = inputEnabled && NSPasteboard.general.string(forType: .string) != nil
        menu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(title: DockerCompatibilityTerminalStrings.selectAll(language), action: #selector(selectAll(_:)), keyEquivalent: "")
        selectAllItem.target = self
        menu.addItem(selectAllItem)

        if selectionActive {
            menu.addItem(.separator())
            let clearSelectionItem = NSMenuItem(title: DockerCompatibilityTerminalStrings.clearSelection(language), action: #selector(clearSelectionFromMenu(_:)), keyEquivalent: "")
            clearSelectionItem.target = self
            menu.addItem(clearSelectionItem)
        }

        return menu
    }

    @objc private func performContextMenuAction(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? TerminalContextMenuActionBox else { return }
        box.action()
    }

    @objc private func clearSelectionFromMenu(_ sender: Any?) {
        selectNone()
        setNeedsDisplay(bounds)
    }

    private func focusIfInputEnabled() {
        guard inputEnabled else { return }
        window?.makeFirstResponder(self)
    }
}

private final class TerminalContextMenuActionBox {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}
