import Foundation
import Testing
@testable import MacCommander

@Suite("Folder viewer preferences")
struct FolderAssociationTests {
    @Test("A configured handler remains authoritative while a restart is pending")
    func configuredHandlerIsAuthoritative() {
        let handler = FolderAssociationService.resolvedFolderHandlerBundleIdentifier(
            launchServicesBundleIdentifier: "com.apple.finder",
            configuredFolderHandlerBundleIdentifier: "org.chadcommander.ChadCommander"
        )

        #expect(handler == "org.chadcommander.ChadCommander")
    }

    @Test("The active handler is used when no change is configured")
    func activeHandlerIsFallback() {
        let handler = FolderAssociationService.resolvedFolderHandlerBundleIdentifier(
            launchServicesBundleIdentifier: "com.apple.finder",
            configuredFolderHandlerBundleIdentifier: nil
        )

        #expect(handler == "com.apple.finder")
        #expect(
            FolderAssociationService.resolvedFolderHandlerBundleIdentifier(
                launchServicesBundleIdentifier: nil,
                configuredFolderHandlerBundleIdentifier: nil
            ) == FolderAssociationService.finderBundleIdentifier
        )
    }

    @Test("Replacing a folder association preserves unrelated handlers and removes duplicates")
    func replacingFolderHandler() throws {
        let existing = [
            ["LSHandlerURLScheme": "https", "LSHandlerRoleAll": "com.example.browser"],
            ["LSHandlerContentType": "public.folder", "LSHandlerRoleAll": "com.apple.finder"],
            ["LSHandlerContentType": "public.folder", "LSHandlerRoleAll": "com.example.old"]
        ]

        let updated = FolderAssociationPreferences.replacingFolderHandler(
            in: existing,
            with: "org.chadcommander.ChadCommander"
        )
        let folderHandlers = updated.filter {
            $0["LSHandlerContentType"] as? String == "public.folder"
        }

        #expect(updated.count == 2)
        #expect(updated.first?["LSHandlerURLScheme"] as? String == "https")
        #expect(folderHandlers.count == 1)
        #expect(
            FolderAssociationPreferences.folderHandlerBundleIdentifier(in: updated)
                == "org.chadcommander.ChadCommander"
        )
    }

    @Test("Bundle identifier comparison follows Launch Services casing")
    func bundleIdentifierComparison() {
        #expect(
            FolderAssociationService.bundleIdentifiersMatch(
                "org.chadcommander.chadcommander",
                "org.chadcommander.ChadCommander"
            )
        )
    }
}
