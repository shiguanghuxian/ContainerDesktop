import AppKit
import SwiftUI
import Testing
@testable import ContainerDesktop

@Suite("Thin scroll bar style")
struct ThinScrollBarStyleTests {
    @MainActor
    @Test("configures NSScrollView for thin overlay scrollers")
    func configuresNSScrollViewForThinOverlayScrollers() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.scrollerStyle = .legacy
        scrollView.autohidesScrollers = false

        scrollView.applyContainerDesktopThinScrollBars()

        #expect(scrollView.scrollerStyle == .overlay)
        #expect(scrollView.autohidesScrollers)
        #expect(scrollView.verticalScroller?.controlSize == .small)
        #expect(scrollView.horizontalScroller?.controlSize == .small)
    }

    @MainActor
    @Test("configures sibling SwiftUI scroll views")
    func configuresSiblingSwiftUIScrollViews() async throws {
        let hostingView = NSHostingView(rootView: HStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<40, id: \.self) { index in
                        Text("Left \(index)")
                    }
                }
            }
            .frame(width: 180, height: 120)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<40, id: \.self) { index in
                        Text("Right \(index)")
                    }
                }
            }
            .frame(width: 180, height: 120)
        }
        .thinScrollBars())
        hostingView.frame = NSRect(x: 0, y: 0, width: 372, height: 120)

        let container = NSView(frame: hostingView.frame)
        container.addSubview(hostingView)
        defer { hostingView.removeFromSuperview() }

        container.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()

        try await Task.sleep(nanoseconds: 100_000_000)

        let scrollViews = hostingView.descendantScrollViewsForTesting()
        #expect(scrollViews.count >= 2)

        for scrollView in scrollViews {
            #expect(scrollView.scrollerStyle == .overlay)
            #expect(scrollView.autohidesScrollers)
            #expect(scrollView.verticalScroller?.controlSize == .small)
        }
    }
}

private extension NSView {
    func descendantScrollViewsForTesting() -> [NSScrollView] {
        subviews.flatMap { subview -> [NSScrollView] in
            var scrollViews = subview.descendantScrollViewsForTesting()
            if let scrollView = subview as? NSScrollView {
                scrollViews.insert(scrollView, at: 0)
            }
            return scrollViews
        }
    }
}
