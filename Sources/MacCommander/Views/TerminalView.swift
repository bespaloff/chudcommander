import AppKit
import SwiftUI
@preconcurrency import SwiftTerm

struct TerminalView: View {
    @ObservedObject var session: TerminalSession
    let close: () -> Void
    @Environment(\.interfaceScale) private var scale

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal", systemImage: "terminal")
                    .font(.system(size: 10.5 * scale, weight: .semibold))
                if session.title != "Terminal" {
                    Text(session.title)
                        .font(.system(size: 9.5 * scale))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Clear") { session.clear() }
                    .buttonStyle(.borderless).font(.system(size: 10 * scale))
                    .controlTooltip("Clear the terminal")
                Button { close() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .controlTooltip("Close the terminal", shortcut: "⌥F4")
            }
            .padding(.horizontal, 6 * scale).frame(height: 20 * scale)
            .background(Color(nsColor: .controlBackgroundColor))

            TerminalSurface(session: session)
        }
        .frame(minHeight: CGFloat(PaneModel.minimumTerminalHeight) * scale)
        .task(id: scale) { session.setFontSize(TerminalSession.baseFontSize * scale) }
    }
}

private struct TerminalSurface: NSViewRepresentable {
    let session: TerminalSession

    final class Coordinator {
        var requestedInitialFocus = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        session.terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        guard !context.coordinator.requestedInitialFocus else { return }
        context.coordinator.requestedInitialFocus = true
        DispatchQueue.main.async { [weak session] in
            session?.focus()
        }
    }
}
