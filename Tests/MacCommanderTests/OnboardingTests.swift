import Foundation
import Testing
@testable import MacCommander

@Suite("First-launch onboarding")
@MainActor
struct OnboardingTests {
    @Test("The guide appears once and remains available as a reference")
    func onboardingPersistence() {
        let suiteName = "OnboardingTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        defer { preferences.removePersistentDomain(forName: suiteName) }

        let firstLaunch = AppState(onboardingPreferences: preferences)
        firstLaunch.presentOnboardingIfNeeded()
        #expect(firstLaunch.shortcutGuidePresentation == .onboarding)

        firstLaunch.dismissShortcutGuide()
        #expect(firstLaunch.shortcutGuidePresentation == nil)

        let nextLaunch = AppState(onboardingPreferences: preferences)
        nextLaunch.presentOnboardingIfNeeded()
        #expect(nextLaunch.shortcutGuidePresentation == nil)

        nextLaunch.showShortcutGuide()
        #expect(nextLaunch.shortcutGuidePresentation == .reference)
    }
}
