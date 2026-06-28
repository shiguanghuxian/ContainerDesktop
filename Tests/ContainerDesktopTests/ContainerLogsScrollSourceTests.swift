import Foundation
import Testing

@Suite("Container logs scroll source")
struct ContainerLogsScrollSourceTests {
    @Test("logs tab uses conditional follow and explicit scroll to bottom")
    func logsTabUsesConditionalFollowAndExplicitScrollToBottom() throws {
        let logsTab = try source("Sources/ContainerDesktop/Views/Resources/ContainerDetail/ContainerLogsTabView.swift")
        let textView = try source("Sources/ContainerDesktop/Views/Resources/ContainerDetail/MonospaceTextViews.swift")

        #expect(!logsTab.contains("autoScrollToBottom: true"))
        #expect(logsTab.contains("shouldAutoFollowLogs"))
        #expect(logsTab.contains("store.followLogs && !store.isLogsPaused"))
        #expect(logsTab.contains("store.logsSearchText.trimmed.isEmpty"))
        #expect(logsTab.contains("scrollToBottomRequestID"))
        #expect(logsTab.contains("isScrolledToBottom: $isLogViewAtBottom"))
        #expect(!logsTab.contains("prefersParentVerticalScroll"))
        #expect(logsTab.contains(".frame(height: 480)"))
        #expect(!logsTab.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(!logsTab.contains(".layoutPriority(1)"))
        #expect(logsTab.contains("arrow.down.to.line"))
        #expect(logsTab.contains("滚动到底部"))

        #expect(textView.contains("struct ReadOnlyMonospaceTextView"))
        #expect(!textView.contains("prefersParentVerticalScroll"))
        #expect(!textView.contains("ParentPreferringMonospaceScrollView"))
        #expect(textView.contains("private final class BoundaryForwardingScrollView: NSScrollView"))
        #expect(textView.contains("let scrollView = BoundaryForwardingScrollView()"))
        #expect(textView.contains("scrollView.verticalScrollElasticity = .none"))
        #expect(textView.contains("nsView.verticalScrollElasticity = .none"))
        #expect(textView.contains("shouldForwardUnconsumedVerticalScroll"))
        #expect(textView.contains("parentScrollView?.scrollWheel(with: event)"))
        #expect(textView.contains("scrollToBottomRequestID"))
        #expect(textView.contains("isNearBottom()"))
        #expect(textView.contains("restoreVisibleOrigin"))
        #expect(textView.contains("NSView.boundsDidChangeNotification"))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
