import AppKit
import QuickLookThumbnailing
import SwiftUI

struct FileIcon: View {
    let url: URL
    var size: CGFloat = 18
    var showsThumbnail = false
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: showsThumbnail ? 3 : 0))
            .accessibilityHidden(true)
            .task(id: ThumbnailTask(url: url, size: size, enabled: showsThumbnail)) {
                guard showsThumbnail else {
                    thumbnail = nil
                    return
                }
                thumbnail = await ThumbnailStore.shared.thumbnail(for: url, size: size)
            }
    }
}

private struct ThumbnailTask: Hashable {
    let url: URL
    let size: CGFloat
    let enabled: Bool
}

@MainActor
private final class ThumbnailStore {
    static let shared = ThumbnailStore()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 400
    }

    func thumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        let pixelSize = max(64, Int(size * 2))
        let key = "\(url.path)|\(pixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: pixelSize, height: pixelSize),
            scale: 1,
            representationTypes: [.thumbnail, .icon]
        )
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }

        let image = representation.nsImage
        cache.setObject(image, forKey: key)
        return image
    }
}
