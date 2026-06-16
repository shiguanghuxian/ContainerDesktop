import AppKit
import SwiftUI

extension NSScrollView {
    func applyContainerDesktopThinScrollBars() {
        scrollerStyle = .overlay
        autohidesScrollers = true
        verticalScroller?.controlSize = .small
        horizontalScroller?.controlSize = .small
    }
}

extension View {
    func thinScrollBars() -> some View {
        background(ThinScrollBarConfigurator())
    }
}

private struct ThinScrollBarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ThinScrollBarConfiguratorView {
        let view = ThinScrollBarConfiguratorView(frame: .zero)
        view.scheduleApplyThinScrollBars()
        return view
    }

    func updateNSView(_ nsView: ThinScrollBarConfiguratorView, context: Context) {
        nsView.scheduleApplyThinScrollBars()
    }
}

private final class ThinScrollBarConfiguratorView: NSView {
    private static let applyPassCount = 3
    private static let followUpApplyDelay: DispatchTimeInterval = .milliseconds(10)

    private var isApplyScheduled = false
    private var pendingApplyPasses = 0

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleApplyThinScrollBars()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleApplyThinScrollBars()
    }

    override func layout() {
        super.layout()
        scheduleApplyThinScrollBars()
    }

    func scheduleApplyThinScrollBars() {
        pendingApplyPasses = max(pendingApplyPasses, Self.applyPassCount)
        scheduleNextApplyPassIfNeeded()
    }

    private func scheduleNextApplyPassIfNeeded() {
        guard !isApplyScheduled else { return }
        guard pendingApplyPasses > 0 else { return }

        isApplyScheduled = true
        let delay: DispatchTimeInterval = pendingApplyPasses == Self.applyPassCount ? .milliseconds(0) : Self.followUpApplyDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.isApplyScheduled = false
            self.pendingApplyPasses -= 1
            self.applyThinScrollBarsToRelatedScrollViews()
            self.scheduleNextApplyPassIfNeeded()
        }
    }
}

private extension NSView {
    func applyThinScrollBarsToRelatedScrollViews() {
        relatedScrollViews().forEach { scrollView in
            scrollView.applyContainerDesktopThinScrollBars()
        }
    }

    func relatedScrollViews() -> [NSScrollView] {
        var scrollViews: [NSScrollView] = []
        var seen = Set<ObjectIdentifier>()

        func append(_ scrollView: NSScrollView) {
            let identifier = ObjectIdentifier(scrollView)
            guard seen.insert(identifier).inserted else { return }
            scrollViews.append(scrollView)
        }

        if let scrollView = enclosingScrollView {
            append(scrollView)
        }

        descendantScrollViews().forEach(append)

        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? NSScrollView {
                append(scrollView)
            }
            view.descendantScrollViews().forEach(append)
            ancestor = view.superview
        }

        return scrollViews
    }

    func descendantScrollViews() -> [NSScrollView] {
        var scrollViews: [NSScrollView] = []

        func collect(from view: NSView) {
            for subview in view.subviews {
                if let scrollView = subview as? NSScrollView {
                    scrollViews.append(scrollView)
                }
                collect(from: subview)
            }
        }

        collect(from: self)
        return scrollViews
    }
}
