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

struct ReadOnlyMonospaceTextView: NSViewRepresentable {
    var text: String
    var appearance: MonospaceTextAppearance
    var autoScrollToBottom = false
    var wrapsLines = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapsLines
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = appearance.backgroundColor

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
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasHorizontalScroller = !wrapsLines
        nsView.backgroundColor = appearance.backgroundColor
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
            textView.string = text
            if autoScrollToBottom {
                DispatchQueue.main.async {
                    textView.scrollToEndOfDocument(nil)
                }
            }
        }
    }

    final class Coordinator {
        weak var textView: NSTextView?
    }
}
