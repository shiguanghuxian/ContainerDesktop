import AppKit
import SwiftUI

enum MonospaceTextAppearance {
    case console
    case code

    var backgroundColor: NSColor {
        switch self {
        case .console:
            NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.042, alpha: 1)
        case .code:
            CDTheme.nativeCodeBackgroundColor()
        }
    }

    var textColor: NSColor {
        switch self {
        case .console:
            NSColor(calibratedRed: 0.82, green: 0.94, blue: 0.88, alpha: 1)
        case .code:
            NSColor.labelColor
        }
    }
}

enum MonospaceTextScrollBehavior {
    static let bottomThreshold: CGFloat = 24

    static func isNearBottom(
        visibleMaxY: CGFloat,
        documentHeight: CGFloat,
        threshold: CGFloat = bottomThreshold
    ) -> Bool {
        visibleMaxY >= max(documentHeight - max(threshold, 0), 0)
    }

    static func clampedOriginY(
        _ originY: CGFloat,
        visibleHeight: CGFloat,
        documentHeight: CGFloat
    ) -> CGFloat {
        min(max(originY, 0), max(documentHeight - visibleHeight, 0))
    }

}

struct ReadOnlyMonospaceTextView: NSViewRepresentable {
    var text: String
    var appearance: MonospaceTextAppearance
    var autoScrollToBottom = false
    var scrollToBottomRequestID = 0
    var isScrolledToBottom: Binding<Bool>?
    var wrapsLines = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapsLines
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = appearance.backgroundColor
        scrollView.applyContainerDesktopThinScrollBars()

        let textView = NSTextView()
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapsLines
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: wrapsLines ? scrollView.contentSize.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = wrapsLines
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = appearance.textColor
        textView.backgroundColor = appearance.backgroundColor
        textView.string = text
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        scrollView.documentView = textView
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        context.coordinator.isScrolledToBottom = isScrolledToBottom
        context.coordinator.lastScrollToBottomRequestID = scrollToBottomRequestID
        if autoScrollToBottom {
            context.coordinator.scheduleScrollToBottom()
        } else {
            context.coordinator.scheduleScrollStateRefresh()
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasHorizontalScroller = !wrapsLines
        nsView.verticalScrollElasticity = .none
        nsView.backgroundColor = appearance.backgroundColor
        nsView.applyContainerDesktopThinScrollBars()
        context.coordinator.attach(scrollView: nsView, textView: nsView.documentView as? NSTextView)
        context.coordinator.isScrolledToBottom = isScrolledToBottom
        guard let textView = context.coordinator.textView else { return }

        textView.backgroundColor = appearance.backgroundColor
        textView.textColor = appearance.textColor
        textView.textContainer?.widthTracksTextView = wrapsLines
        textView.isHorizontallyResizable = !wrapsLines
        textView.textContainer?.containerSize = NSSize(
            width: wrapsLines ? nsView.contentSize.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        if textView.string != text {
            let previousOrigin = nsView.contentView.bounds.origin
            let wasNearBottom = context.coordinator.isNearBottom()
            textView.string = text
            context.coordinator.ensureTextLayout()
            if autoScrollToBottom, wasNearBottom {
                context.coordinator.scheduleScrollToBottom()
            } else {
                context.coordinator.restoreVisibleOrigin(previousOrigin)
            }
        }

        if context.coordinator.lastScrollToBottomRequestID != scrollToBottomRequestID {
            context.coordinator.lastScrollToBottomRequestID = scrollToBottomRequestID
            context.coordinator.scheduleScrollToBottom()
        } else {
            context.coordinator.scheduleScrollStateRefresh()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var isScrolledToBottom: Binding<Bool>?
        var lastScrollToBottomRequestID = 0

        private weak var observedClipView: NSClipView?

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(scrollView: NSScrollView, textView: NSTextView?) {
            self.scrollView = scrollView
            self.textView = textView

            let clipView = scrollView.contentView
            guard observedClipView !== clipView else { return }
            if let observedClipView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: observedClipView
                )
            }

            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(clipViewBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }

        func isNearBottom() -> Bool {
            guard let scrollView else { return true }
            let visibleRect = scrollView.contentView.bounds
            return MonospaceTextScrollBehavior.isNearBottom(
                visibleMaxY: visibleRect.maxY,
                documentHeight: documentHeight
            )
        }

        func restoreVisibleOrigin(_ origin: NSPoint) {
            guard let scrollView else { return }
            let clipView = scrollView.contentView
            let y = MonospaceTextScrollBehavior.clampedOriginY(
                origin.y,
                visibleHeight: clipView.bounds.height,
                documentHeight: documentHeight
            )
            clipView.scroll(to: NSPoint(x: origin.x, y: y))
            scrollView.reflectScrolledClipView(clipView)
            scheduleScrollStateRefresh()
        }

        func scheduleScrollToBottom() {
            DispatchQueue.main.async { [weak self] in
                self?.scrollToBottom()
            }
        }

        func scheduleScrollStateRefresh() {
            DispatchQueue.main.async { [weak self] in
                self?.publishScrollState()
            }
        }

        func ensureTextLayout() {
            guard let textView else { return }
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }
            textView.layoutSubtreeIfNeeded()
            scrollView?.layoutSubtreeIfNeeded()
        }

        private func scrollToBottom() {
            textView?.scrollToEndOfDocument(nil)
            publishScrollState()
        }

        @objc private func clipViewBoundsDidChange(_ notification: Notification) {
            publishScrollState()
        }

        private func publishScrollState() {
            let value = isNearBottom()
            guard isScrolledToBottom?.wrappedValue != value else { return }
            isScrolledToBottom?.wrappedValue = value
        }

        private var documentHeight: CGFloat {
            guard let documentView = scrollView?.documentView else { return 0 }
            return max(documentView.bounds.height, documentView.frame.height)
        }
    }
}
