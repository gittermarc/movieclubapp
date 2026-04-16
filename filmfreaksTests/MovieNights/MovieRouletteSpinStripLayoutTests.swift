import CoreGraphics
import Testing
@testable import filmfreaks

struct MovieRouletteSpinStripLayoutTests {

    @Test func compactLayoutUsesInnerViewportForCentering() {
        let size = CGSize(width: 360, height: 260)

        let layout = MovieRouletteSpinStripLayout.metrics(for: size)

        #expect(layout.horizontalInset == 16)
        #expect(layout.viewportWidth == 328)
        #expect(abs(layout.cardWidth - 100.8) < 0.001)
        #expect(abs(layout.centeredOffset - 101.6) < 0.001)
    }

    @Test func wideLayoutKeepsFadeInsideViewportBounds() {
        let size = CGSize(width: 820, height: 260)

        let layout = MovieRouletteSpinStripLayout.metrics(for: size)

        #expect(layout.horizontalInset == 22)
        #expect(layout.viewportWidth == 776)
        #expect(layout.leadingFadeStop > 0)
        #expect(layout.trailingFadeStart < 1)
        #expect(layout.trailingFadeStart > layout.leadingFadeStop)
    }
}
