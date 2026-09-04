import AppKit
import SwiftUI

struct ShortcutGuideView: View {
    let presentation: ShortcutGuidePresentation
    let onDone: () -> Void

    private let shortcuts = [
        ShortcutGuideItem(keys: ["Tab"], action: "Switch active pane"),
        ShortcutGuideItem(keys: ["F3", "Space"], action: "Quick Look"),
        ShortcutGuideItem(keys: ["F4"], action: "Open selection"),
        ShortcutGuideItem(keys: ["F5"], action: "Copy to other pane"),
        ShortcutGuideItem(keys: ["F6"], action: "Move to other pane"),
        ShortcutGuideItem(keys: ["⇧F6"], action: "Rename"),
        ShortcutGuideItem(keys: ["F7"], action: "New folder"),
        ShortcutGuideItem(keys: ["F8"], action: "Move to Trash"),
        ShortcutGuideItem(keys: ["⌘F"], action: "Find files"),
        ShortcutGuideItem(keys: ["⌘T"], action: "New tab"),
        ShortcutGuideItem(keys: ["⌘B"], action: "Add or remove favorite"),
        ShortcutGuideItem(keys: ["⇧⌘B"], action: "Open favorite folders"),
        ShortcutGuideItem(keys: ["⌘+", "⌘−"], action: "Resize the interface"),
        ShortcutGuideItem(keys: ["⌘⌥S"], action: "Calculate folder sizes"),
        ShortcutGuideItem(keys: ["⌥F4"], action: "Toggle terminal")
    ]

    private var buttonTitle: String {
        presentation == .onboarding ? "Get Started" : "Done"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("Meet Chad Commander")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("A simple, quick file manager for your Mac.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text("Work with two folders side by side, then preview, copy, move, rename, and find files without slowing down.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .padding(.horizontal, 36)
            .padding(.top, 30)
            .padding(.bottom, 24)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Main keyboard shortcuts")
                    .font(.headline)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 24, alignment: .topLeading),
                        GridItem(.flexible(), spacing: 24, alignment: .topLeading)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(shortcuts) { shortcut in
                        ShortcutGuideRow(item: shortcut)
                    }
                }

                Label {
                    Text("On Apple keyboards, hold fn with an F-key unless function keys are set as standard keys in System Settings.")
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 22)

            Divider()

            HStack {
                Text("Open this guide anytime from Help → Keyboard Shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(buttonTitle, action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .controlTooltip("Close the keyboard shortcut guide", shortcut: "Return")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }
}

private struct ShortcutGuideItem: Identifiable {
    let keys: [String]
    let action: String

    var id: String { action }
}

private struct ShortcutGuideRow: View {
    let item: ShortcutGuideItem

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(item.keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 7)
                        .frame(minHeight: 24)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        }
                }
            }
            .frame(width: 100, alignment: .leading)

            Text(item.action)
                .font(.callout)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.keys.joined(separator: " or ")), \(item.action)")
    }
}

#Preview("Onboarding") {
    ShortcutGuideView(presentation: .onboarding, onDone: {})
}
