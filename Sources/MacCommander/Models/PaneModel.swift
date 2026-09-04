import Combine
import Foundation

@MainActor
final class PaneModel: ObservableObject {
    @Published private(set) var tabs: [PaneTab]
    @Published var activeTabID: UUID
    @Published private(set) var items: [FileItem] = []
    @Published var selection: Set<URL> = []
    @Published var cursorURL: URL?
    @Published var sort: FileSort = .name
    @Published var ascending = true
    @Published var viewMode: PaneViewMode = .list
    @Published var gridIconSize = 54.0
    @Published private(set) var visibleListColumns = FileListColumn.defaults
    @Published private(set) var filterQuery = ""
    @Published private(set) var gridColumnCount = 1
    @Published var showHidden = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var accessDenied = false
    @Published private(set) var folderSizes: [URL: FolderSizeState] = [:]
    @Published private(set) var isCalculatingFolderSizes = false
    @Published var terminalVisible = false
    let terminal = TerminalSession()
    private let folderSizeService: FolderSizeService
    private var automaticallyCalculatesFolderSizes: Bool
    private var folderSizeEnabledTabs: Set<UUID> = []
    private var folderSizeTask: Task<Void, Never>?
    private var folderSizeRequestID: UUID?

    init(
        location: URL,
        folderSizeService: FolderSizeService = FolderSizeService(),
        automaticallyCalculatesFolderSizes: Bool = false
    ) {
        let tab = PaneTab(location: location)
        tabs = [tab]
        activeTabID = tab.id
        self.folderSizeService = folderSizeService
        self.automaticallyCalculatesFolderSizes = automaticallyCalculatesFolderSizes
    }

    var activeTab: PaneTab {
        tabs[activeIndex]
    }

    var location: URL { activeTab.location }
    var canGoBack: Bool { activeTab.historyIndex > 0 }
    var canGoForward: Bool { activeTab.historyIndex < activeTab.history.count - 1 }

    var sortedItems: [FileItem] {
        FileSystemService.sorted(items, by: sort, ascending: ascending, folderSizes: folderSizes)
    }

    var filteredItems: [FileItem] {
        guard !filterQuery.isEmpty else { return sortedItems }
        return sortedItems.filter { $0.name.localizedCaseInsensitiveContains(filterQuery) }
    }

    var displayItems: [FileItem] {
        if let parent = FileItem.parent(of: location) { return [parent] + filteredItems }
        return filteredItems
    }

    var selectedItems: [FileItem] {
        let selected = selection
        return items.filter { selected.contains($0.url) }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + ($1.isDirectory ? 0 : $1.size) }
    }

    private var activeIndex: Int {
        tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
    }

    func reload(selecting urlToSelect: URL? = nil) {
        cancelFolderSizeCalculation()
        let tab = activeTab
        if let virtualItems = tab.virtualItems {
            let refreshed = virtualItems.compactMap { FileItem.load(url: $0.url) }
            var updatedTab = tab
            updatedTab.virtualItems = refreshed
            tabs[activeIndex] = updatedTab
            items = refreshed
            retainFolderSizes(for: refreshed)
            isLoading = false
            restoreCursor(selecting: urlToSelect)
            calculateFolderSizesIfNeeded()
            return
        }

        let location = tab.location
        let includeHidden = showHidden
        isLoading = true
        errorMessage = nil
        accessDenied = false
        Task {
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try FileSystemService.contents(of: location, showHidden: includeHidden)
                }.value
                guard location == self.location else { return }
                self.items = loaded
                self.retainFolderSizes(for: loaded)
                self.isLoading = false
                self.restoreCursor(selecting: urlToSelect)
                self.calculateFolderSizesIfNeeded()
            } catch {
                guard location == self.location else { return }
                self.items = []
                self.selection = []
                self.cursorURL = nil
                self.errorMessage = error.localizedDescription
                self.accessDenied = Self.isPermissionDenied(error)
                self.isLoading = false
            }
        }
    }

    func calculateFolderSizesForTab(forceRefresh: Bool = false, rememberForTab: Bool = true) {
        if rememberForTab { folderSizeEnabledTabs.insert(activeTabID) }
        let folders = items.filter(\.isDirectory).map { $0.url.standardizedFileURL }
        guard !folders.isEmpty else { return }

        cancelFolderSizeCalculation()
        let requestID = UUID()
        let tabID = activeTabID
        folderSizeRequestID = requestID
        isCalculatingFolderSizes = true

        var states = folderSizes
        for url in folders where states[url] == nil {
            states[url] = .calculating
        }
        folderSizes = states

        let service = folderSizeService
        folderSizeTask = Task { [weak self] in
            guard let self else { return }

            let cached = forceRefresh ? [:] : await service.cachedSizes(for: folders)
            guard !Task.isCancelled else { return }

            var results = cached.reduce(into: [URL: FolderSizeState]()) { result, entry in
                result[entry.key] = .ready(entry.value)
            }
            let missing = folders.filter { cached[$0] == nil }

            for start in stride(from: 0, to: missing.count, by: 2) {
                guard !Task.isCancelled else { return }
                let end = min(start + 2, missing.count)
                let batch = Array(missing[start..<end])
                let batchResults = await withTaskGroup(of: (URL, Int64?).self) { group in
                    for url in batch {
                        group.addTask {
                            (url, await service.size(of: url, forceRefresh: forceRefresh))
                        }
                    }
                    var values: [(URL, Int64?)] = []
                    for await value in group { values.append(value) }
                    return values
                }
                for (url, bytes) in batchResults {
                    results[url] = bytes.map(FolderSizeState.ready) ?? .unavailable
                }
            }

            guard !Task.isCancelled, self.folderSizeRequestID == requestID, self.activeTabID == tabID else { return }
            var updated = self.folderSizes
            for (url, state) in results { updated[url] = state }
            self.folderSizes = updated
            self.isCalculatingFolderSizes = false
            self.folderSizeRequestID = nil
            self.folderSizeTask = nil
        }
    }

    func setAutomaticallyCalculatesFolderSizes(_ enabled: Bool) {
        automaticallyCalculatesFolderSizes = enabled
        if enabled {
            calculateFolderSizesForTab(rememberForTab: false)
        } else if !folderSizeEnabledTabs.contains(activeTabID) {
            cancelFolderSizeCalculation()
            folderSizes = [:]
        }
    }

    func folderSizeText(for item: FileItem) -> String {
        guard item.isDirectory else { return item.formattedSize }
        return switch folderSizes[item.url.standardizedFileURL] {
        case .calculating: "…"
        case .ready(let bytes): ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .unavailable: "—"
        case nil: ""
        }
    }

    private func calculateFolderSizesIfNeeded() {
        if automaticallyCalculatesFolderSizes || folderSizeEnabledTabs.contains(activeTabID) {
            calculateFolderSizesForTab(rememberForTab: false)
        }
    }

    private func retainFolderSizes(for items: [FileItem]) {
        let visibleFolders = Set(items.lazy.filter(\.isDirectory).map { $0.url.standardizedFileURL })
        folderSizes = folderSizes.filter { visibleFolders.contains($0.key) }
    }

    private func cancelFolderSizeCalculation() {
        folderSizeTask?.cancel()
        folderSizeTask = nil
        folderSizeRequestID = nil
        isCalculatingFolderSizes = false
        folderSizes = folderSizes.filter { $0.value != .calculating }
    }

    func navigate(to url: URL, recordHistory: Bool = true, selecting: URL? = nil) {
        let target = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "The folder no longer exists or cannot be opened."
            return
        }

        var tab = activeTab
        if recordHistory {
            tab.history = Array(tab.history.prefix(tab.historyIndex + 1))
            if tab.history.last != target { tab.history.append(target) }
            tab.historyIndex = tab.history.count - 1
        }
        tab.location = target
        tab.titleOverride = nil
        tab.virtualItems = nil
        tabs[activeIndex] = tab
        clearFilter()
        selection = []
        cursorURL = nil
        reload(selecting: selecting)
        if terminalVisible { terminal.changeDirectory(to: target) }
    }

    func goBack() {
        guard canGoBack else { return }
        var tab = activeTab
        tab.historyIndex -= 1
        tab.location = tab.history[tab.historyIndex]
        tab.virtualItems = nil
        tab.titleOverride = nil
        tabs[activeIndex] = tab
        clearFilter()
        selection = []
        cursorURL = nil
        reload()
        if terminalVisible { terminal.changeDirectory(to: tab.location) }
    }

    func goForward() {
        guard canGoForward else { return }
        var tab = activeTab
        tab.historyIndex += 1
        tab.location = tab.history[tab.historyIndex]
        tab.virtualItems = nil
        tab.titleOverride = nil
        tabs[activeIndex] = tab
        clearFilter()
        selection = []
        cursorURL = nil
        reload()
        if terminalVisible { terminal.changeDirectory(to: tab.location) }
    }

    func goUp() {
        guard location.path != "/" else { return }
        let child = location
        navigate(to: location.deletingLastPathComponent(), selecting: child)
    }

    func addTab(location: URL? = nil) {
        let tab = PaneTab(location: location ?? self.location)
        tabs.append(tab)
        activeTabID = tab.id
        clearFilter()
        selection = []
        cursorURL = nil
        reload()
    }

    func showSearchResults(_ results: [SearchMatch], query: String, root: URL) {
        let title = query.isEmpty ? "Search results" : "Search: \(query)"
        let tab = PaneTab(location: root, titleOverride: title, virtualItems: results.map(\.item))
        tabs.append(tab)
        activeTabID = tab.id
        clearFilter()
        selection = []
        cursorURL = nil
        reload()
    }

    func selectTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        clearFilter()
        selection = []
        cursorURL = nil
        reload()
        if terminalVisible { terminal.changeDirectory(to: location) }
    }

    func closeTab(_ id: UUID) {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = id == activeTabID
        folderSizeEnabledTabs.remove(id)
        tabs.remove(at: index)
        if wasActive {
            activeTabID = tabs[min(index, tabs.count - 1)].id
            clearFilter()
            selection = []
            cursorURL = nil
            reload()
            if terminalVisible { terminal.changeDirectory(to: location) }
        }
    }

    func toggleTerminal() {
        terminalVisible.toggle()
        if terminalVisible {
            terminal.start(in: location)
            terminal.onDirectoryChange = { [weak self] url in
                guard let self, url != self.location else { return }
                self.navigate(to: url)
            }
        }
    }

    func ensureCursor() {
        let visible = displayItems
        guard !visible.isEmpty else {
            cursorURL = nil
            selection = []
            return
        }
        let target = cursorURL.flatMap { current in visible.contains(where: { $0.url == current }) ? current : nil } ?? visible[0].url
        cursorURL = target
        if selection.isEmpty { selection = [target] }
    }

    func setCursor(to url: URL) {
        cursorURL = url
    }

    func setFilterQuery(_ query: String) {
        guard query != filterQuery else { return }
        filterQuery = query
        reconcileSelectionWithFilter()
    }

    func appendToFilter(_ text: String) {
        setFilterQuery(filterQuery + text)
    }

    func deleteLastFilterCharacter() {
        guard !filterQuery.isEmpty else { return }
        setFilterQuery(String(filterQuery.dropLast()))
    }

    func clearFilter() {
        setFilterQuery("")
    }

    func setListColumn(_ column: FileListColumn, isVisible: Bool) {
        if isVisible {
            visibleListColumns.insert(column)
        } else {
            visibleListColumns.remove(column)
            if sort == column.sort {
                sort = .name
                ascending = true
            }
        }
    }

    func updateGridColumnCount(_ count: Int) {
        gridColumnCount = max(1, count)
    }

    func moveCursor(_ movement: CursorMovement) {
        let visible = displayItems
        guard !visible.isEmpty else { return }
        let current = cursorURL.flatMap { url in visible.firstIndex(where: { $0.url == url }) } ?? 0
        let targetIndex: Int
        switch movement {
        case .previous, .left: targetIndex = max(0, current - 1)
        case .next, .right: targetIndex = min(visible.count - 1, current + 1)
        case .up:
            targetIndex = max(0, current - (viewMode == .grid ? gridColumnCount : 1))
        case .down:
            targetIndex = min(visible.count - 1, current + (viewMode == .grid ? gridColumnCount : 1))
        case .first: targetIndex = 0
        case .last: targetIndex = visible.count - 1
        case .pageUp: targetIndex = max(0, current - 18)
        case .pageDown: targetIndex = min(visible.count - 1, current + 18)
        }
        let target = visible[targetIndex].url
        cursorURL = target
        selection = [target]
    }

    func itemAtCursor() -> FileItem? {
        guard let cursorURL else { return displayItems.first }
        return displayItems.first(where: { $0.url == cursorURL })
    }

    private func restoreCursor(selecting requested: URL?) {
        let visible = displayItems
        let preferred = requested ?? cursorURL ?? selection.first
        let target = preferred.flatMap { url in visible.contains(where: { $0.url == url }) ? url : nil } ?? visible.first?.url
        cursorURL = target
        selection = target.map { [$0] } ?? []
    }

    private func reconcileSelectionWithFilter() {
        let visibleURLs = Set(displayItems.map(\.url))
        selection.formIntersection(visibleURLs)

        if let cursorURL, visibleURLs.contains(cursorURL) {
            if selection.isEmpty { selection = [cursorURL] }
            return
        }

        let target = filteredItems.first?.url ?? displayItems.first?.url
        cursorURL = target
        selection = target.map { [$0] } ?? []
    }

    static func isPermissionDenied(_ error: Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain {
            return error.code == CocoaError.fileReadNoPermission.rawValue
                || error.code == CocoaError.fileWriteNoPermission.rawValue
        }
        if error.domain == NSPOSIXErrorDomain {
            return error.code == Int(POSIXErrorCode.EACCES.rawValue)
                || error.code == Int(POSIXErrorCode.EPERM.rawValue)
        }
        return false
    }
}
