import AppKit
import SwiftTerm
import SwiftUI

struct SwiftTermTerminalView: NSViewRepresentable {
    var textSnapshot: String
    var outputEvents: [TerminalOutputEvent]
    var outputSequence: Int
    var resetSequence: Int
    var isInputEnabled = true
    var onInput: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput)
    }

    func makeNSView(context: Context) -> FocusableTerminalView {
        let terminalView = FocusableTerminalView(frame: .zero)
        terminalView.terminalDelegate = context.coordinator
        terminalView.autoresizingMask = [.width, .height]
        terminalView.caretViewTracksFocus = false
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminalView.nativeForegroundColor = NSColor(calibratedRed: 0.82, green: 0.94, blue: 0.88, alpha: 1)
        terminalView.nativeBackgroundColor = NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.055, alpha: 1)
        terminalView.caretColor = .white
        terminalView.caretTextColor = terminalView.nativeBackgroundColor
        terminalView.setInputEnabled(isInputEnabled)
        context.coordinator.terminalView = terminalView
        context.coordinator.isInputEnabled = isInputEnabled
        let clickRecognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.focusTerminal))
        terminalView.addGestureRecognizer(clickRecognizer)
        return terminalView
    }

    func updateNSView(_ terminalView: FocusableTerminalView, context: Context) {
        context.coordinator.onInput = onInput
        context.coordinator.isInputEnabled = isInputEnabled
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
        var isInputEnabled = true
        weak var terminalView: TerminalView?
        private var lastOutputSequence = 0
        private var lastResetSequence: Int?
        private var didSeedSnapshot = false
        private(set) var terminalColumns = 0
        private(set) var terminalRows = 0

        init(onInput: @escaping (Data) -> Void) {
            self.onInput = onInput
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
                reset(
                    terminalView,
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }

            guard didSeedSnapshot else {
                reset(
                    terminalView,
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }

            guard outputSequence != lastOutputSequence else { return }
            let pendingEvents = outputEvents.filter { $0.sequence > lastOutputSequence }
            guard let firstEvent = pendingEvents.first,
                  firstEvent.sequence == lastOutputSequence + 1 else {
                reset(
                    terminalView,
                    textSnapshot: textSnapshot,
                    outputSequence: outputSequence,
                    resetSequence: resetSequence
                )
                return
            }

            for event in pendingEvents {
                terminalView.feed(text: event.text)
            }
            lastOutputSequence = pendingEvents.last?.sequence ?? lastOutputSequence
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            terminalColumns = newCols
            terminalRows = newRows
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

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

        @MainActor
        private func reset(
            _ terminalView: TerminalView,
            textSnapshot: String,
            outputSequence: Int,
            resetSequence: Int
        ) {
            terminalView.feed(text: "\u{1B}[2J\u{1B}[3J\u{1B}[H")
            if !textSnapshot.isEmpty {
                terminalView.feed(text: textSnapshot)
            }
            lastOutputSequence = outputSequence
            lastResetSequence = resetSequence
            didSeedSnapshot = true
        }
    }
}

final class FocusableTerminalView: TerminalView {
    private var didRequestInitialFocus = false
    private var inputEnabled = true

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
}
