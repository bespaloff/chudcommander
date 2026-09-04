import SwiftUI

/// How much larger or smaller the interface is drawn than its natural size.
///
/// Zoom multiplies the metrics the interface is built from - font sizes, row
/// and bar heights, icon sizes, padding - rather than transforming the view
/// that hosts it. A coordinate transform draws correctly but is invisible to
/// SwiftUI, which resolves clicks, gestures and the AppKit controls it hosts
/// against its own geometry: zoomed in, the interface would stop responding to
/// the pointer. Scaling the metrics instead lets the layout genuinely reflow,
/// so input, hover and drag keep working at every zoom level.
private struct InterfaceScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var interfaceScale: CGFloat {
        get { self[InterfaceScaleKey.self] }
        set { self[InterfaceScaleKey.self] = newValue }
    }
}

enum InterfaceScale {
    /// The zoom actually applied, reduced from the requested zoom whenever the
    /// interface at that size would not fit the window. The window keeps its
    /// size, so the zoom gives way instead of the content spilling over.
    static func effective(
        requested: CGFloat,
        viewport: CGSize,
        minimumContentSize: CGSize
    ) -> CGFloat {
        var scale = max(requested, 0.1)
        if minimumContentSize.width > 0, viewport.width > 0 {
            scale = min(scale, viewport.width / minimumContentSize.width)
        }
        if minimumContentSize.height > 0, viewport.height > 0 {
            scale = min(scale, viewport.height / minimumContentSize.height)
        }
        return max(scale, 0.1)
    }
}
