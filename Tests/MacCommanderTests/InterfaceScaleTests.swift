import Foundation
import Testing
@testable import MacCommander

@Suite("Interface scale")
struct InterfaceScaleTests {
    @Test("Zoom gives way when the window cannot fit the interface at that size")
    func scaleClampedToViewport() {
        let minimum = CGSize(width: 640, height: 430)

        // 500 / 430 is tighter than 800 / 640, so height sets the cap.
        #expect(
            abs(InterfaceScale.effective(
                requested: 1.5,
                viewport: CGSize(width: 800, height: 500),
                minimumContentSize: minimum
            ) - 500.0 / 430.0) < 0.001
        )

        // A window with room to spare applies the requested zoom.
        #expect(
            abs(InterfaceScale.effective(
                requested: 1.5,
                viewport: CGSize(width: 1_600, height: 1_000),
                minimumContentSize: minimum
            ) - 1.5) < 0.001
        )

        // Zooming out is never clamped upwards.
        #expect(
            abs(InterfaceScale.effective(
                requested: 0.7,
                viewport: CGSize(width: 800, height: 500),
                minimumContentSize: minimum
            ) - 0.7) < 0.001
        )

        // A viewport that has not been measured yet leaves the zoom alone.
        #expect(
            InterfaceScale.effective(
                requested: 1.2,
                viewport: .zero,
                minimumContentSize: minimum
            ) == 1.2
        )
    }
}
