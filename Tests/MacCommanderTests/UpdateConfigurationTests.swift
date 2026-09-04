import Foundation
import Testing

@Suite("Update configuration")
struct UpdateConfigurationTests {
    @Test("Sparkle feed uses the production HTTPS endpoint")
    func feedConfiguration() throws {
        let plist = try infoPlist()

        #expect(plist["SUFeedURL"] as? String == "https://chadcommander.org/appcast.xml")
        #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(plist["SUScheduledCheckInterval"] as? Int == 3_600)
        #expect(plist["CFBundleIdentifier"] as? String == "org.chadcommander.ChadCommander")
    }

    @Test("Sparkle update verification key is embedded")
    func signingKeyConfiguration() throws {
        let plist = try infoPlist()
        let publicKey = plist["SUPublicEDKey"] as? String

        #expect(publicKey?.isEmpty == false)
        #expect(publicKey != "REPLACE_WITH_PUBLIC_KEY_FROM_GENERATE_KEYS")
        #expect(Data(base64Encoded: publicKey ?? "")?.count == 32)
    }

    private func infoPlist() throws -> [String: Any] {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let plistURL = testsDirectory
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: plistURL)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(object as? [String: Any])
    }
}
