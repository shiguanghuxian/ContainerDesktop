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
    static let boundaryThreshold: CGFloat = 0.5
    static let movementThreshold: CGFloat = 0.01
    static let scrollDeltaThreshold: CGFloat = 0.01

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

    static func documentHeight(boundsHeight: CGFloat, frameHeight: CGFloat) -> CGFloat {
        max(boundsHeight, frameHeight)
    }

    static func didMoveVertically(from beforeOriginY: CGFloat, to afterOriginY: CGFloat) -> Bool {
        abs(afterOriginY - beforeOriginY) > movementThreshold
    }

    static func hasVerticalScrollDelta(_ verticalDelta: CGFloat) -> Bool {
        abs(verticalDelta) > scrollDeltaThreshold
    }

    static func isAtVerticalBoundary(
        visibleOriginY: CGFloat,
        visibleHeight: CGFloat,
        documentHeight: CGFloat,
        threshold: CGFloat = boundaryThreshold
    ) -> Bool {
        let maxOriginY = max(documentHeight - visibleHeight, 0)
        return visibleOriginY <= threshold || visibleOriginY >= maxOriginY - threshold
    }

    static func shouldForwardUnconsumedVerticalScroll(
        verticalDelta: CGFloat,
        visibleOriginY: CGFloat,
        visibleHeight: CGFloat,
        documentHeight: CGFloat,
        movedVertically: Bool
    ) -> Bool {
        guard hasVerticalScrollDelta(verticalDelta), !movedVertically else { return false }
        return isAtVerticalBoundary(
            visibleOriginY: visibleOriginY,
            visibleHeight: visibleHeight,
            documentHeight: documentHeight
        )
    }

}

enum CodePreviewFontSize {
    static let minimum: CGFloat = 10
    static let maximum: CGFloat = 28
    static let defaultValue: CGFloat = 12
    static let step: CGFloat = 1

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}

private final class BoundaryForwardingScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        let verticalDelta = Self.verticalDelta(from: event)
        guard MonospaceTextScrollBehavior.hasVerticalScrollDelta(verticalDelta) else {
            super.scrollWheel(with: event)
            return
        }

        let beforeOriginY = contentView.bounds.origin.y
        super.scrollWheel(with: event)
        let afterOriginY = contentView.bounds.origin.y
        let movedVertically = MonospaceTextScrollBehavior.didMoveVertically(
            from: beforeOriginY,
            to: afterOriginY
        )

        guard MonospaceTextScrollBehavior.shouldForwardUnconsumedVerticalScroll(
            verticalDelta: verticalDelta,
            visibleOriginY: afterOriginY,
            visibleHeight: contentView.bounds.height,
            documentHeight: documentHeight,
            movedVertically: movedVertically
        ) else { return }

        parentScrollView?.scrollWheel(with: event)
    }

    private static func verticalDelta(from event: NSEvent) -> CGFloat {
        if MonospaceTextScrollBehavior.hasVerticalScrollDelta(event.scrollingDeltaY) {
            return event.scrollingDeltaY
        }
        return event.deltaY
    }

    private var documentHeight: CGFloat {
        guard let documentView else { return 0 }
        return MonospaceTextScrollBehavior.documentHeight(
            boundsHeight: documentView.bounds.height,
            frameHeight: documentView.frame.height
        )
    }

    private var parentScrollView: NSScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? NSScrollView, scrollView !== self {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }
}

struct EditableCodeTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var fontSize: CGFloat = CodePreviewFontSize.defaultValue
    var appearance: MonospaceTextAppearance = .code
    var wrapsLines = false

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = BoundaryForwardingScrollView()
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
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: CodePreviewFontSize.clamped(fontSize), weight: .regular)
        textView.textColor = appearance.textColor
        textView.backgroundColor = appearance.backgroundColor
        textView.string = text
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        scrollView.documentView = textView
        context.coordinator.attach(scrollView: scrollView, textView: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.hasHorizontalScroller = !wrapsLines
        nsView.verticalScrollElasticity = .none
        nsView.backgroundColor = appearance.backgroundColor
        nsView.applyContainerDesktopThinScrollBars()

        context.coordinator.text = $text
        context.coordinator.attach(scrollView: nsView, textView: nsView.documentView as? NSTextView)
        guard let textView = context.coordinator.textView else { return }

        textView.isEditable = isEditable
        textView.backgroundColor = appearance.backgroundColor
        textView.textColor = appearance.textColor
        textView.font = NSFont.monospacedSystemFont(ofSize: CodePreviewFontSize.clamped(fontSize), weight: .regular)
        textView.textContainer?.widthTracksTextView = wrapsLines
        textView.isHorizontallyResizable = !wrapsLines
        textView.textContainer?.containerSize = NSSize(
            width: wrapsLines ? nsView.contentSize.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            let previousOrigin = nsView.contentView.bounds.origin
            textView.string = text
            context.coordinator.ensureTextLayout()
            textView.selectedRanges = context.coordinator.validSelectedRanges(
                selectedRanges,
                textLength: (textView.string as NSString).length
            )
            context.coordinator.restoreVisibleOrigin(previousOrigin)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?

        init(text: Binding<String>) {
            self.text = text
        }

        func attach(scrollView: NSScrollView, textView: NSTextView?) {
            self.scrollView = scrollView
            self.textView = textView
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }

        func ensureTextLayout() {
            guard let textView else { return }
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }
            textView.layoutSubtreeIfNeeded()
            scrollView?.layoutSubtreeIfNeeded()
        }

        func restoreVisibleOrigin(_ origin: NSPoint) {
            guard let scrollView else { return }
            let documentHeight = scrollView.documentView.map {
                MonospaceTextScrollBehavior.documentHeight(
                    boundsHeight: $0.bounds.height,
                    frameHeight: $0.frame.height
                )
            } ?? 0
            let clipView = scrollView.contentView
            let y = MonospaceTextScrollBehavior.clampedOriginY(
                origin.y,
                visibleHeight: clipView.bounds.height,
                documentHeight: documentHeight
            )
            clipView.scroll(to: NSPoint(x: origin.x, y: y))
            scrollView.reflectScrolledClipView(clipView)
        }

        func validSelectedRanges(_ ranges: [NSValue], textLength: Int) -> [NSValue] {
            ranges.map { value in
                let range = value.rangeValue
                let location = min(range.location, textLength)
                let availableLength = max(textLength - location, 0)
                return NSValue(range: NSRange(location: location, length: min(range.length, availableLength)))
            }
        }
    }
}

struct FilePreviewCodePanel<HeaderActions: View>: View {
    @Environment(\.appLanguage) private var language
    @Binding var text: String
    @Binding var fontSize: CGFloat
    var title: String
    var subtitle: String
    var fileName: String? = nil
    var isEditable: Bool
    var isDisabled = false
    var isLoading = false
    var minEditorHeight: CGFloat = 260
    var largeEditorHeight: CGFloat = 560
    @ViewBuilder var headerActions: HeaderActions

    @State private var isShowingLargePreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ZStack {
                CodeFileEditorView(
                    text: $text,
                    fileName: fileName ?? title,
                    isEditable: isEditable && !isDisabled,
                    fontSize: fontSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(minHeight: minEditorHeight)
            .disabled(isDisabled)
        }
        .padding(12)
        .background(CDTheme.panelSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(CDTheme.separator)
        }
        .sheet(isPresented: $isShowingLargePreview) {
            largePreviewSheet
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                titleBlock
                Spacer(minLength: 8)
                controls
                headerActions
            }

            VStack(alignment: .leading, spacing: 8) {
                titleBlock
                HStack(spacing: 8) {
                    controls
                    Spacer(minLength: 0)
                    headerActions
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button {
                fontSize = CodePreviewFontSize.clamped(fontSize - CodePreviewFontSize.step)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(fontSize <= CodePreviewFontSize.minimum)
            .help(language.resolved == .zhHans ? "缩小字号" : "Decrease font size")

            Text("\(Int(fontSize.rounded()))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Button {
                fontSize = CodePreviewFontSize.clamped(fontSize + CodePreviewFontSize.step)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(fontSize >= CodePreviewFontSize.maximum)
            .help(language.resolved == .zhHans ? "放大字号" : "Increase font size")

            Button {
                fontSize = CodePreviewFontSize.defaultValue
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .disabled(fontSize == CodePreviewFontSize.defaultValue)
            .help(language.resolved == .zhHans ? "重置字号" : "Reset font size")

            Button {
                isShowingLargePreview = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help(language.resolved == .zhHans ? "放大查看" : "Open large preview")
        }
        .buttonStyle(.borderless)
        .fixedSize()
    }

    private var largePreviewSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                titleBlock
                Spacer()
                controls
                headerActions
                Button(language.resolved == .zhHans ? "关闭" : "Close") {
                    isShowingLargePreview = false
                }
                .keyboardShortcut(.cancelAction)
            }

            ZStack {
                CodeFileEditorView(
                    text: $text,
                    fileName: fileName ?? title,
                    isEditable: isEditable && !isDisabled,
                    fontSize: fontSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(CDTheme.separator)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(minWidth: 760, minHeight: largeEditorHeight)
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 640)
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
        let scrollView = BoundaryForwardingScrollView()
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
            return MonospaceTextScrollBehavior.documentHeight(
                boundsHeight: documentView.bounds.height,
                frameHeight: documentView.frame.height
            )
        }
    }
}
