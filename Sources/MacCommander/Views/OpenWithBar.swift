import AppKit
import SwiftUI

struct OpenWithBar: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        HStack(spacing: 6 * scale) {
            if let item = state.primarySelection {
                FileIcon(url: item.url, size: 17 * scale)
                Text(item.name).font(.system(size: 11.5 * scale, weight: .semibold)).lineLimit(1)
                Text(item.kind).font(.system(size: 10.5 * scale)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)

                if !item.isDirectory || item.isPackage {
                    let defaultApp = OpenWithService.defaultApplication(for: item.url)
                    Button {
                        state.openSelection()
                    } label: {
                        Label(defaultApp.map { "Open in \(appName($0))" } ?? "Open", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                    .controlTooltip("Open in the default application", shortcut: "F4")

                    Menu {
                        ForEach(OpenWithService.applications(for: item.url), id: \.self) { app in
                            Button(appName(app)) { state.openSelection(with: app) }
                                .controlTooltip("Open \(item.name) in \(appName(app))")
                        }
                    } label: {
                        AlternativeAppIcon()
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .controlTooltip("Choose another application to open this item")
                }
            } else {
                Image(systemName: "rectangle.split.2x1").font(.system(size: 14 * scale)).foregroundStyle(.tint)
                Text("Select a file to see its applications").font(.system(size: 11 * scale)).foregroundStyle(.secondary)
                Spacer()
            }

            Divider().frame(height: 18 * scale)
            Button { state.searchPresented = true } label: {
                compactAction("Search", shortcut: "⌘F", symbol: "magnifyingglass")
            }
                .keyboardShortcut("f", modifiers: .command)
                .buttonStyle(.borderless)
                .controlTooltip("Find files", shortcut: "⌘F")
        }
        .controlSize(.small)
        .font(.system(size: 11 * scale))
        .padding(.horizontal, 7 * scale)
        .frame(height: 32 * scale)
        .background(.bar)
    }

    private func appName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func compactAction(_ title: String, shortcut: String, symbol: String) -> some View {
        HStack(spacing: 3 * scale) {
            Image(systemName: symbol)
            Text(title).font(.system(size: 10.5 * scale, weight: .medium))
            Text(shortcut)
                .font(.system(size: 9.5 * scale, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct AlternativeAppIcon: View {
    // Bundle.module traps when a hand-packaged app keeps SwiftPM bundles in
    // the signed Contents/Resources directory, so probe both layouts safely.
    private static let iconURL: URL? = {
        if let url = Bundle.main.url(forResource: "alternative-app", withExtension: "svg") {
            return url
        }

        let resourceBundleName = "MacCommander_MacCommander.bundle"
        let bundleLocations = [
            Bundle.main.bundleURL.appendingPathComponent(resourceBundleName),
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
        ].compactMap { $0 }

        return bundleLocations.lazy.compactMap { Bundle(url: $0) }.compactMap {
            $0.url(forResource: "alternative-app", withExtension: "svg")
        }.first
    }()

    var body: some View {
        if let url = Self.iconURL,
           let image = NSImage(contentsOf: url) {
            Image(nsImage: template(image))
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(.primary)
                .accessibilityLabel("Other applications")
        } else {
            Image(systemName: "square.stack.3d.up")
                .accessibilityLabel("Other applications")
        }
    }

    private func template(_ image: NSImage) -> NSImage {
        image.isTemplate = true
        return image
    }
}
