import AppKit
import Foundation

@MainActor
enum OpenWithService {
    static func defaultApplication(for url: URL) -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: url)
    }

    static func applications(for url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: url)
            .sorted { $0.deletingPathExtension().lastPathComponent.localizedStandardCompare($1.deletingPathExtension().lastPathComponent) == .orderedAscending }
    }

    static func open(_ urls: [URL], with application: URL? = nil) {
        guard !urls.isEmpty else { return }
        if let application {
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: application,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            for url in urls { NSWorkspace.shared.open(url) }
        }
    }
}
