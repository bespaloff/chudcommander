import AppKit
import Combine
import Foundation

enum NamingPromptKind: Sendable {
    case newFolder
    case rename(URL)
}

struct NamingPrompt: Identifiable, Sendable {
    let id = UUID()
    let kind: NamingPromptKind
    let title: String
    let message: String
    let initialValue: String
}

struct AppNotice: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

enum ShortcutGuidePresentation: String, Identifiable, Sendable {
    case onboarding
    case reference

    var id: String { rawValue }
}

@MainActor
final class AppState: ObservableObject {
    private static let automaticFolderSizesKey = "automaticallyCalculateFolderSizes"
    private static let didShowOnboardingKey = "didShowOnboarding.v1"
    private static let favoritesKey = "favoriteFolders.v1"
    private static let workspaceSessionKey = "workspaceSession.v1"
    private static let interfaceScaleKey = "interfaceScale.v1"
    nonisolated static let minimumInterfaceScale = 0.7
    nonisolated static let maximumInterfaceScale = 1.5
    nonisolated static let interfaceScaleStep = 0.1
    /// The smallest layout the commander interface renders without clipping.
    /// It doubles as the window's minimum content size and as the budget the
    /// zoom level is clamped against, so neither resizing nor zooming pushes
    /// content out of the window.
    nonisolated static let floorContentWidth = 640.0
    nonisolated static let minimumContentHeight = 430.0

    let leftPane: PaneModel
    let rightPane: PaneModel
    let operationCenter = OperationCenter()

    @Published var activeSide: PaneSide = .left {
        didSet {
            guard activeSide != oldValue else { return }
            persistWorkspaceSession()
        }
    }
    @Published var searchPresented = false
    @Published var namingPrompt: NamingPrompt?
    @Published var pendingTrash: [URL] = []
    @Published var notice: AppNotice?
    @Published var quickLookURL: URL?
    @Published var shortcutGuidePresentation: ShortcutGuidePresentation?
    @Published var favoritesPresentation: FavoritesPresentation?
    @Published private(set) var favoriteFolders: [FavoriteFolder] = []
    @Published private(set) var interfaceScale = 1.0
    @Published var automaticallyCalculateFolderSizes: Bool {
        didSet {
            guard automaticallyCalculateFolderSizes != oldValue else { return }
            onboardingPreferences.set(automaticallyCalculateFolderSizes, forKey: Self.automaticFolderSizesKey)
            leftPane.setAutomaticallyCalculatesFolderSizes(automaticallyCalculateFolderSizes)
            rightPane.setAutomaticallyCalculatesFolderSizes(automaticallyCalculateFolderSizes)
        }
    }
    private let onboardingPreferences: UserDefaults
    private var didCheckOnboarding = false
    private var cancellables: Set<AnyCancellable> = []

    init(onboardingPreferences: UserDefaults = .standard) {
        self.onboardingPreferences = onboardingPreferences
        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? home
        let automaticFolderSizes = onboardingPreferences.bool(forKey: Self.automaticFolderSizesKey)
        let workspaceSession = Self.decode(
            WorkspaceSessionState.self,
            forKey: Self.workspaceSessionKey,
            from: onboardingPreferences
        )
        let savedFavorites = Self.decode(
            [FavoriteFolder].self,
            forKey: Self.favoritesKey,
            from: onboardingPreferences
        ) ?? []
        let savedScale = onboardingPreferences.object(forKey: Self.interfaceScaleKey) as? Double ?? 1
        let folderSizeService = FolderSizeService()

        activeSide = workspaceSession?.activeSide ?? .left
        favoriteFolders = Self.uniqueFavorites(savedFavorites)
        interfaceScale = Self.normalizedInterfaceScale(savedScale)
        automaticallyCalculateFolderSizes = automaticFolderSizes
        shortcutGuidePresentation = nil
        favoritesPresentation = nil
        leftPane = PaneModel(
            location: home,
            restoredSession: workspaceSession?.leftPane,
            folderSizeService: folderSizeService,
            automaticallyCalculatesFolderSizes: automaticFolderSizes
        )
        rightPane = PaneModel(
            location: downloads,
            restoredSession: workspaceSession?.rightPane,
            folderSizeService: folderSizeService,
            automaticallyCalculatesFolderSizes: automaticFolderSizes
        )

        leftPane.onSessionChange = { [weak self] in self?.persistWorkspaceSession() }
        rightPane.onSessionChange = { [weak self] in self?.persistWorkspaceSession() }

        leftPane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        rightPane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        operationCenter.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        ApplicationOpenCoordinator.shared.install { [weak self] urls in
            self?.handleOpenURLs(urls)
        }
    }

    var activePane: PaneModel { activeSide == .left ? leftPane : rightPane }
    var inactivePane: PaneModel { activeSide == .left ? rightPane : leftPane }
    var activeSelection: [FileItem] { activePane.selectedItems }
    var primarySelection: FileItem? { activeSelection.first }
    var isActiveFolderFavorite: Bool { favorite(for: activePane.location) != nil }
    /// Both panes side by side, each wide enough to show its own columns.
    var minimumContentWidth: Double {
        max(leftPane.minimumListWidth + rightPane.minimumListWidth + 1, Self.floorContentWidth)
    }
    var interfaceScalePercentage: Int { Int((interfaceScale * 100).rounded()) }
    var canIncreaseInterfaceScale: Bool { interfaceScale < Self.maximumInterfaceScale }
    var canDecreaseInterfaceScale: Bool { interfaceScale > Self.minimumInterfaceScale }

    func start() {
        leftPane.reload()
        rightPane.reload()
    }

    func presentOnboardingIfNeeded() {
        guard !didCheckOnboarding else { return }
        didCheckOnboarding = true
        guard !onboardingPreferences.bool(forKey: Self.didShowOnboardingKey) else { return }
        shortcutGuidePresentation = .onboarding
    }

    func showShortcutGuide() {
        shortcutGuidePresentation = .reference
    }

    func showFavorites() {
        favoritesPresentation = .browser
    }

    func toggleFavoriteForActiveFolder() {
        let folder = FavoriteFolder(url: activePane.location)
        if let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) {
            favoriteFolders.remove(at: index)
        } else {
            favoriteFolders.insert(folder, at: 0)
        }
        persistFavorites()
    }

    func removeFavorite(_ favorite: FavoriteFolder) {
        favoriteFolders.removeAll { $0.id == favorite.id }
        persistFavorites()
    }

    func openFavorite(_ favorite: FavoriteFolder) {
        activePane.navigate(to: favorite.url)
    }

    func increaseInterfaceScale() {
        setInterfaceScale(interfaceScale + Self.interfaceScaleStep)
    }

    func decreaseInterfaceScale() {
        setInterfaceScale(interfaceScale - Self.interfaceScaleStep)
    }

    func resetInterfaceScale() {
        setInterfaceScale(1)
    }

    func dismissShortcutGuide() {
        markOnboardingAsShown()
        shortcutGuidePresentation = nil
    }

    func shortcutGuideDidDismiss() {
        markOnboardingAsShown()
    }

    func setActive(_ side: PaneSide) { activeSide = side }

    func handleOpenURLs(_ urls: [URL]) {
        let destinations = urls.compactMap(openDestination(for:))
        guard let first = destinations.first else { return }

        activePane.navigate(to: first.folder, selecting: first.selection)
        if destinations.count > 1 {
            let second = destinations[1]
            inactivePane.navigate(to: second.folder, selecting: second.selection)
        }
    }

    func switchPane() {
        activeSide = activeSide.opposite
        activePane.ensureCursor()
    }

    func activate(_ item: FileItem, in side: PaneSide) {
        setActive(side)
        if item.isParentEntry {
            pane(side).goUp()
        } else if item.isDirectory && !item.isPackage {
            pane(side).navigate(to: item.url)
        } else {
            OpenWithService.open([item.url])
        }
    }

    func activateCursor() {
        activePane.ensureCursor()
        guard let item = activePane.itemAtCursor() else { return }
        activate(item, in: activeSide)
    }

    func openSelection(with application: URL? = nil) {
        let urls = activeSelection.map(\.url)
        guard !urls.isEmpty else { return }
        OpenWithService.open(urls, with: application)
    }

    func quickLookSelection() {
        quickLookURL = primarySelection?.url
    }

    func copySelection() {
        transferSelection(kind: .copy)
    }

    func moveSelection() {
        transferSelection(kind: .move)
    }

    private func transferSelection(kind: FileOperationKind) {
        var sources = activeSelection.map(\.url)
        guard !sources.isEmpty else {
            notice = AppNotice(title: "Nothing selected", message: "Select one or more files in the active pane first.")
            return
        }
        let destination = inactivePane.location
        if kind == .move {
            sources.removeAll { $0.deletingLastPathComponent().standardizedFileURL == destination.standardizedFileURL }
            guard !sources.isEmpty else {
                notice = AppNotice(title: "Already there", message: "The selected items are already in the other pane’s folder.")
                return
            }
        }
        guard FileManager.default.isWritableFile(atPath: destination.path) else {
            notice = AppNotice(title: "Destination is read-only", message: destination.path)
            return
        }
        operationCenter.perform(kind, sources: sources, destination: destination) { [weak self] in
            self?.leftPane.reload()
            self?.rightPane.reload()
            if let failure = self?.operationCenter.recentFailure {
                self?.notice = AppNotice(title: "\(kind.rawValue) did not finish", message: failure)
            }
        }
    }

    func requestNewFolder() {
        namingPrompt = NamingPrompt(kind: .newFolder, title: "New Folder", message: "Create in \(activePane.location.path)", initialValue: "untitled folder")
    }

    func requestRename() {
        guard let item = primarySelection else {
            notice = AppNotice(title: "Nothing selected", message: "Select one file or folder to rename.")
            return
        }
        namingPrompt = NamingPrompt(kind: .rename(item.url), title: "Rename", message: item.url.deletingLastPathComponent().path, initialValue: item.name)
    }

    func submitName(_ value: String, for prompt: NamingPrompt) {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else {
            notice = AppNotice(title: "Invalid name", message: "Names cannot be empty or contain a slash.")
            return
        }

        do {
            switch prompt.kind {
            case .newFolder:
                let url = activePane.location.appendingPathComponent(name, isDirectory: true)
                guard !FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileWriteFileExists) }
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
                activePane.reload(selecting: url)
            case .rename(let source):
                let destination = source.deletingLastPathComponent().appendingPathComponent(name)
                guard !FileManager.default.fileExists(atPath: destination.path) else { throw CocoaError(.fileWriteFileExists) }
                try FileManager.default.moveItem(at: source, to: destination)
                leftPane.reload(selecting: destination)
                rightPane.reload(selecting: destination)
            }
        } catch {
            notice = AppNotice(title: "Could not save the name", message: error.localizedDescription)
        }
        namingPrompt = nil
    }

    func requestTrash() {
        pendingTrash = activeSelection.map(\.url)
        if pendingTrash.isEmpty {
            notice = AppNotice(title: "Nothing selected", message: "Select files or folders to move to the Trash.")
        }
    }

    func confirmTrash() {
        let sources = pendingTrash
        pendingTrash = []
        operationCenter.perform(.trash, sources: sources) { [weak self] in
            self?.leftPane.reload()
            self?.rightPane.reload()
            if let failure = self?.operationCenter.recentFailure {
                self?.notice = AppNotice(title: "Could not move to Trash", message: failure)
            }
        }
    }

    func toggleTerminal() { activePane.toggleTerminal() }

    func acceptDropped(_ urls: [URL], on side: PaneSide) -> Bool {
        let destination = pane(side).location
        let valid = urls.filter { $0.deletingLastPathComponent() != destination }
        guard !valid.isEmpty else { return false }
        operationCenter.perform(.copy, sources: valid, destination: destination) { [weak self] in
            self?.pane(side).reload()
        }
        return true
    }

    func pane(_ side: PaneSide) -> PaneModel { side == .left ? leftPane : rightPane }

    private func favorite(for url: URL) -> FavoriteFolder? {
        let path = url.standardizedFileURL.path
        return favoriteFolders.first { $0.path == path }
    }

    private func setInterfaceScale(_ scale: Double) {
        let normalized = Self.normalizedInterfaceScale(scale)
        guard normalized != interfaceScale else { return }
        interfaceScale = normalized
        onboardingPreferences.set(normalized, forKey: Self.interfaceScaleKey)
    }

    private func persistFavorites() {
        encode(favoriteFolders, forKey: Self.favoritesKey)
    }

    private func persistWorkspaceSession() {
        guard leftPane.onSessionChange != nil, rightPane.onSessionChange != nil else { return }
        let session = WorkspaceSessionState(
            leftPane: leftPane.sessionState,
            rightPane: rightPane.sessionState,
            activeSide: activeSide
        )
        encode(session, forKey: Self.workspaceSessionKey)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        onboardingPreferences.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        forKey key: String,
        from preferences: UserDefaults
    ) -> T? {
        guard let data = preferences.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func uniqueFavorites(_ favorites: [FavoriteFolder]) -> [FavoriteFolder] {
        var paths = Set<String>()
        return favorites.filter { paths.insert($0.path).inserted }
    }

    private static func normalizedInterfaceScale(_ scale: Double) -> Double {
        let stepped = (scale / interfaceScaleStep).rounded() * interfaceScaleStep
        return min(max(stepped, minimumInterfaceScale), maximumInterfaceScale)
    }

    private func markOnboardingAsShown() {
        onboardingPreferences.set(true, forKey: Self.didShowOnboardingKey)
    }

    private func openDestination(for url: URL) -> (folder: URL, selection: URL?)? {
        let standardized = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else {
            return nil
        }

        let isPackage = (try? standardized.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        if isDirectory.boolValue && !isPackage {
            return (standardized, nil)
        }
        return (standardized.deletingLastPathComponent(), standardized)
    }
}
