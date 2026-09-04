import AppKit
import QuickLook
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @State private var keyboardMonitor: KeyboardEventMonitor?

    var body: some View {
        InterfaceScaleContainer(
            scale: CGFloat(state.interfaceScale),
            minimumContentSize: CGSize(
                width: state.minimumContentWidth,
                height: AppState.minimumContentHeight
            )
        ) {
            commanderInterface
                .environmentObject(state)
        }
        .frame(
            minWidth: CGFloat(state.minimumContentWidth),
            minHeight: CGFloat(AppState.minimumContentHeight)
        )
        .sheet(item: $state.shortcutGuidePresentation, onDismiss: state.shortcutGuideDidDismiss) { presentation in
            ShortcutGuideView(presentation: presentation, onDone: state.dismissShortcutGuide)
        }
        .sheet(item: $state.favoritesPresentation) { _ in
            FavoritesOverlayView()
                .environmentObject(state)
        }
        .sheet(isPresented: $state.searchPresented) { SearchSheet().environmentObject(state) }
        .sheet(item: $state.namingPrompt) { prompt in
            NamingSheet(prompt: prompt) { state.submitName($0, for: prompt) }
        }
        .alert(item: $state.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Move \(state.pendingTrash.count) item\(state.pendingTrash.count == 1 ? "" : "s") to the Trash?",
            isPresented: Binding(get: { !state.pendingTrash.isEmpty }, set: { if !$0 { state.pendingTrash = [] } }),
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) { state.confirmTrash() }
                .controlTooltip("Confirm moving the selected items to the Trash")
            Button("Cancel", role: .cancel) { state.pendingTrash = [] }
                .controlTooltip("Cancel without moving anything", shortcut: "Esc")
        }
        .quickLookPreview($state.quickLookURL)
        .task {
            state.start()
            await Task.yield()
            state.presentOnboardingIfNeeded()
            if let window = NSApp.keyWindow {
                window.endEditing(for: nil)
                window.makeFirstResponder(window.contentView)
            }
            let monitor = KeyboardEventMonitor(state: state)
            monitor.install()
            keyboardMonitor = monitor
        }
        .onDisappear { keyboardMonitor?.uninstall() }
    }

    private var commanderInterface: some View {
        VStack(spacing: 0) {
            OpenWithBar()
            Divider()
            HSplitView {
                PaneView(model: state.leftPane, side: .left)
                    .frame(minWidth: CGFloat(state.leftPane.minimumListWidth))
                PaneView(model: state.rightPane, side: .right)
                    .frame(minWidth: CGFloat(state.rightPane.minimumListWidth))
            }
            FunctionKeyBar()
        }
        .controlSize(.small)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .topTrailing) {
            if let operation = state.operationCenter.activeOperations.last {
                HStack(spacing: 8) {
                    ProgressView(value: Double(operation.completed), total: Double(max(operation.total, 1))).frame(width: 70)
                    Text("\(operation.kind.rawValue): \(operation.currentName)").font(.caption).lineLimit(1)
                }
                .padding(9).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9)).padding(10)
            }
        }
    }
}
