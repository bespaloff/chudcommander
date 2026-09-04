import AppKit
import SwiftUI
import Testing
@testable import MacCommander

@Suite("Interface scale container")
@MainActor
struct InterfaceScaleContainerTests {
    @Test("Zooming lays the interface out in scaled points that fill the viewport")
    func scaledCoordinates() {
        let (window, view) = makeHostedView(scale: 1.5, viewport: NSSize(width: 900, height: 600))

        // The viewport keeps its size; the interface is laid out smaller and
        // magnified to fill it, so nothing spills past the window.
        #expect(view.frame.size == NSSize(width: 900, height: 600))
        #expect(view.hostingView.frame.size == NSSize(width: 600, height: 400))
        expectPoint(
            view.hostingView.convert(NSPoint(x: 450, y: 300), from: window.contentView),
            equals: NSPoint(x: 300, y: 200)
        )

        view.interfaceScale = 0.75
        view.layoutSubtreeIfNeeded()

        #expect(view.frame.size == NSSize(width: 900, height: 600))
        #expect(view.hostingView.frame.size == NSSize(width: 1_200, height: 800))
        expectPoint(
            view.hostingView.convert(NSPoint(x: 450, y: 300), from: window.contentView),
            equals: NSPoint(x: 600, y: 400)
        )
    }

    @Test("Zoom is capped so the interface never overflows the viewport")
    func scaleClampedToViewport() {
        let (_, view) = makeHostedView(
            scale: 1.5,
            viewport: NSSize(width: 800, height: 500),
            minimumContentSize: NSSize(width: 640, height: 430)
        )

        // 500 / 430 is tighter than 800 / 640, so height sets the cap and the
        // interface still gets its full minimum in both axes.
        #expect(abs(view.effectiveScale - 500.0 / 430.0) < 0.001)
        #expect(abs(view.hostingView.frame.height - 430) < 0.001)
        #expect(view.hostingView.frame.width >= 640)

        // A viewport with room to spare renders the requested zoom.
        view.frame = NSRect(x: 0, y: 0, width: 1_600, height: 1_000)
        view.layoutSubtreeIfNeeded()
        #expect(abs(view.effectiveScale - 1.5) < 0.001)

        // Zooming out is never clamped upwards.
        view.interfaceScale = 0.7
        #expect(abs(view.effectiveScale - 0.7) < 0.001)
    }

    private func makeHostedView(
        scale: CGFloat,
        viewport: NSSize,
        minimumContentSize: NSSize = .zero
    ) -> (NSWindow, InterfaceScaleHostingView<Color>) {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: viewport),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        let view = InterfaceScaleHostingView(
            rootView: Color.clear,
            scale: scale,
            minimumContentSize: minimumContentSize
        )
        view.frame = NSRect(origin: .zero, size: viewport)
        window.contentView?.addSubview(view)
        view.layoutSubtreeIfNeeded()
        return (window, view)
    }

    private func expectPoint(_ point: NSPoint, equals expected: NSPoint) {
        #expect(abs(point.x - expected.x) < 0.001)
        #expect(abs(point.y - expected.y) < 0.001)
    }
}
