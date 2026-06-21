import AppKit
import SwiftUI

struct WindowDragZoomRegion: View {
    var body: some View {
        WindowDragZoomDoubleClickCatcher()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .simultaneousGesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
    }
}

private struct WindowDragZoomDoubleClickCatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragZoomDoubleClickView {
        WindowDragZoomDoubleClickView()
    }

    func updateNSView(_ nsView: WindowDragZoomDoubleClickView, context: Context) {}
}

private final class WindowDragZoomDoubleClickView: NSView {
    private lazy var doubleClickRecognizer: NSClickGestureRecognizer = {
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        recognizer.numberOfClicksRequired = 2
        recognizer.delaysPrimaryMouseButtonEvents = false
        return recognizer
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addGestureRecognizer(doubleClickRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    @objc private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        window?.performZoom(nil)
    }
}
