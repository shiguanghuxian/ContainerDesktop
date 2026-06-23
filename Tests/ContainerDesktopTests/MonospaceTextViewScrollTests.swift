import CoreGraphics
import Testing
@testable import ContainerDesktop

@Suite("Monospace text view scroll behavior")
struct MonospaceTextViewScrollTests {
    @Test("detects visible range near document bottom")
    func detectsVisibleRangeNearDocumentBottom() {
        #expect(MonospaceTextScrollBehavior.isNearBottom(visibleMaxY: 976, documentHeight: 1_000))
        #expect(MonospaceTextScrollBehavior.isNearBottom(visibleMaxY: 1_000, documentHeight: 1_000))
        #expect(!MonospaceTextScrollBehavior.isNearBottom(visibleMaxY: 975, documentHeight: 1_000))
    }

    @Test("treats short documents as already at bottom")
    func treatsShortDocumentsAsAlreadyAtBottom() {
        #expect(MonospaceTextScrollBehavior.isNearBottom(visibleMaxY: 0, documentHeight: 20))
        #expect(MonospaceTextScrollBehavior.isNearBottom(visibleMaxY: 10, documentHeight: 20))
    }

    @Test("clamps restored origin into the document range")
    func clampsRestoredOriginIntoDocumentRange() {
        #expect(MonospaceTextScrollBehavior.clampedOriginY(-12, visibleHeight: 100, documentHeight: 500) == 0)
        #expect(MonospaceTextScrollBehavior.clampedOriginY(180, visibleHeight: 100, documentHeight: 500) == 180)
        #expect(MonospaceTextScrollBehavior.clampedOriginY(460, visibleHeight: 100, documentHeight: 500) == 400)
        #expect(MonospaceTextScrollBehavior.clampedOriginY(40, visibleHeight: 100, documentHeight: 80) == 0)
    }
}
