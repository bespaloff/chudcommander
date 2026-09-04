import AppKit
import SwiftUI

struct InterfaceScaleContainer<Content: View>: NSViewRepresentable {
    let scale: CGFloat
    let minimumContentSize: CGSize
    private let content: Content

    init(
        scale: CGFloat,
        minimumContentSize: CGSize = .zero,
        @ViewBuilder content: () -> Content
    ) {
        self.scale = max(scale, 0.1)
        self.minimumContentSize = minimumContentSize
        self.content = content()
    }

    func makeNSView(context: Context) -> InterfaceScaleHostingView<Content> {
        InterfaceScaleHostingView(
            rootView: content,
            scale: scale,
            minimumContentSize: minimumContentSize
        )
    }

    func updateNSView(_ view: InterfaceScaleHostingView<Content>, context: Context) {
        view.rootView = content
        view.minimumContentSize = minimumContentSize
        view.interfaceScale = scale
    }
}

/// Magnifies the interface without resizing the window: the container scales
/// its own coordinate system, and the interface is laid out in that scaled
/// space so it fills the viewport exactly at every zoom level.
///
/// The scale has to live on this view rather than on the hosting view.
/// `NSHostingView` lays SwiftUI out against its *frame*, so scaling only its
/// bounds would leave the interface laid out at the unscaled width and then
/// magnify it past the window's edges.
@MainActor
final class InterfaceScaleHostingView<Content: View>: NSView {
    private(set) var hostingView: NSHostingView<Content>

    var interfaceScale: CGFloat {
        didSet {
            guard interfaceScale != oldValue else { return }
            updateGeometry()
        }
    }

    /// The smallest layout the hosted interface can render without clipping.
    /// Zooming never grows the window, so the rendered scale is reduced
    /// whenever the viewport is too small to hold this size at the requested
    /// zoom level.
    var minimumContentSize: CGSize {
        didSet {
            guard minimumContentSize != oldValue else { return }
            updateGeometry()
        }
    }

    init(rootView: Content, scale: CGFloat, minimumContentSize: CGSize = .zero) {
        hostingView = NSHostingView(rootView: rootView)
        interfaceScale = max(scale, 0.1)
        self.minimumContentSize = minimumContentSize
        super.init(frame: .zero)

        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = []
        addSubview(hostingView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var rootView: Content {
        get { hostingView.rootView }
        set { hostingView.rootView = newValue }
    }

    /// The zoom actually rendered, reduced from the requested zoom whenever the
    /// interface would otherwise be laid out smaller than it can draw — which
    /// is what pushes content past the window's edges.
    var effectiveScale: CGFloat {
        var scale = interfaceScale
        if minimumContentSize.width > 0, frame.width > 0 {
            scale = min(scale, frame.width / minimumContentSize.width)
        }
        if minimumContentSize.height > 0, frame.height > 0 {
            scale = min(scale, frame.height / minimumContentSize.height)
        }
        return max(scale, 0.1)
    }

    /// The size, in scaled points, that the interface is laid out at.
    var contentSize: NSSize {
        let scale = effectiveScale
        return NSSize(width: frame.width / scale, height: frame.height / scale)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateGeometry()
    }

    override func layout() {
        super.layout()
        updateGeometry()
    }

    private func updateGeometry() {
        let size = contentSize
        // Scaling this view's coordinate system magnifies everything it draws
        // and maps mouse locations back into the interface for free.
        if bounds.size != size {
            setBoundsSize(size)
        }
        let contentFrame = NSRect(origin: .zero, size: size)
        if hostingView.frame != contentFrame {
            hostingView.frame = contentFrame
        }
        hostingView.needsLayout = true
        hostingView.needsDisplay = true
        hostingView.layoutSubtreeIfNeeded()
    }
}
