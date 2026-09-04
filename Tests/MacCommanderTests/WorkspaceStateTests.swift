import Foundation
import Testing
@testable import MacCommander

@Suite("Persistent workspace state")
@MainActor
struct WorkspaceStateTests {
    @Test("Both panes restore their tabs and latest active folders")
    func restoresPaneTabs() throws {
        let (preferences, suiteName) = temporaryPreferences()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let leftFirst = root.appendingPathComponent("Left First")
        let leftSecond = root.appendingPathComponent("Left Second")
        let right = root.appendingPathComponent("Right")
        for folder in [leftFirst, leftSecond, right] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        defer {
            try? FileManager.default.removeItem(at: root)
            preferences.removePersistentDomain(forName: suiteName)
        }

        let original = AppState(onboardingPreferences: preferences)
        original.leftPane.navigate(to: leftFirst)
        original.leftPane.addTab(location: leftSecond)
        original.rightPane.navigate(to: right)
        original.activeSide = .right

        let restored = AppState(onboardingPreferences: preferences)

        #expect(restored.leftPane.tabs.map(\.location) == [
            leftFirst.standardizedFileURL,
            leftSecond.standardizedFileURL
        ])
        #expect(restored.leftPane.location == leftSecond.standardizedFileURL)
        #expect(restored.rightPane.location == right.standardizedFileURL)
        #expect(restored.activeSide == .right)
    }

    @Test("Favorites persist and match both names and paths")
    func favoritesPersistAndFilter() throws {
        let (preferences, suiteName) = temporaryPreferences()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("Client Artwork")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            preferences.removePersistentDomain(forName: suiteName)
        }

        let original = AppState(onboardingPreferences: preferences)
        original.leftPane.navigate(to: folder)
        original.toggleFavoriteForActiveFolder()

        let restored = AppState(onboardingPreferences: preferences)
        let favorite = try #require(restored.favoriteFolders.first)

        #expect(favorite.name == "Client Artwork")
        #expect(favorite.matches("artwork"))
        #expect(favorite.matches(root.lastPathComponent))
        #expect(favorite.matches("client \(root.lastPathComponent)"))
        #expect(!favorite.matches("unrelated"))

        restored.removeFavorite(favorite)
        #expect(AppState(onboardingPreferences: preferences).favoriteFolders.isEmpty)
    }

    @Test("Interface zoom is clamped and restored")
    func interfaceZoomPersists() {
        let (preferences, suiteName) = temporaryPreferences()
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let original = AppState(onboardingPreferences: preferences)
        for _ in 0..<20 { original.increaseInterfaceScale() }
        #expect(original.interfaceScale == AppState.maximumInterfaceScale)

        let restored = AppState(onboardingPreferences: preferences)
        #expect(restored.interfaceScale == AppState.maximumInterfaceScale)

        for _ in 0..<20 { restored.decreaseInterfaceScale() }
        #expect(restored.interfaceScale == AppState.minimumInterfaceScale)

        restored.resetInterfaceScale()
        #expect(restored.interfaceScale == 1)
    }

    private func temporaryPreferences() -> (preferences: UserDefaults, suiteName: String) {
        let suiteName = "WorkspaceStateTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
