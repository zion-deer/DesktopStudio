import Foundation
import XCTest
@testable import DesktopStudio

final class UpdateReleaseTests: XCTestCase {
    func testTagMatchesASemanticMarketingVersion() {
        XCTAssertEqual(ReleaseRules.marketingVersion(fromTag: "v0.2.0"), "0.2.0")
        XCTAssertNil(ReleaseRules.marketingVersion(fromTag: "0.2.0"))
        XCTAssertNil(ReleaseRules.marketingVersion(fromTag: "v0.2"))
        XCTAssertNil(ReleaseRules.marketingVersion(fromTag: "v01.2.0"))
        XCTAssertFalse(ReleaseRules.isSemanticVersion("1.0.0-beta"))
    }

    func testBuildNumberMustIncrease() {
        XCTAssertTrue(ReleaseRules.isBuildNumber("2"))
        XCTAssertFalse(ReleaseRules.isBuildNumber("02"))
        XCTAssertFalse(ReleaseRules.isBuildNumber("1a"))
        XCTAssertTrue(ReleaseRules.buildIsNewer("2", than: ["1"]))
        XCTAssertFalse(ReleaseRules.buildIsNewer("1", than: ["1"]))
        XCTAssertFalse(ReleaseRules.buildIsNewer("1", than: ["2"]))
        XCTAssertTrue(ReleaseRules.buildIsNewer("1", than: []))
    }

    func testFeedURLRejectsPlaceholdersAndMutableLinks() {
        XCTAssertNotNil(ReleaseRules.feedConfigurationError(urlString: ""))
        XCTAssertNotNil(ReleaseRules.feedConfigurationError(urlString: "$(DESKTOP_STUDIO_UPDATE_FEED_URL)"))
        XCTAssertNotNil(ReleaseRules.feedConfigurationError(urlString: "http://updates.desktopstudio.app/appcast.xml"))
        XCTAssertNotNil(ReleaseRules.feedConfigurationError(urlString: "https://example.com/appcast.xml"))
        XCTAssertNotNil(ReleaseRules.feedConfigurationError(urlString: "https://updates.desktopstudio.app/latest.xml"))
        XCTAssertNil(ReleaseRules.feedConfigurationError(urlString: "https://updates.desktopstudio.app/appcast.xml"))
    }

    func testPublicKeyMustBe32Bytes() {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        XCTAssertNil(ReleaseRules.publicKeyError(key))
        XCTAssertNotNil(ReleaseRules.publicKeyError(""))
        XCTAssertNotNil(ReleaseRules.publicKeyError(Data(repeating: 7, count: 16).base64EncodedString()))
    }

    func testEnclosureMustBeAVersionedSignedZip() {
        let signature = Data(repeating: 3, count: 64).base64EncodedString()
        let url = "https://github.com/desktop-studio/DesktopStudio/releases/download/v0.2.0/DesktopStudio-0.2.0.zip"
        XCTAssertNil(ReleaseRules.enclosureError(urlString: url, shortVersion: "0.2.0", edSignature: signature, length: 100))
        XCTAssertNotNil(ReleaseRules.enclosureError(
            urlString: "https://github.com/desktop-studio/DesktopStudio/releases/latest/download/DesktopStudio-0.2.0.zip",
            shortVersion: "0.2.0",
            edSignature: signature,
            length: 100
        ))
        XCTAssertNotNil(ReleaseRules.enclosureError(urlString: url, shortVersion: "0.2.0", edSignature: "", length: 100))
        XCTAssertNotNil(ReleaseRules.enclosureError(urlString: url, shortVersion: "0.2.0", edSignature: signature, length: 0))
    }

    func testThemesAreOutsideTheAppBundle() {
        let app = URL(fileURLWithPath: "/Applications/Desktop Studio.app", isDirectory: true)
        let themes = URL(fileURLWithPath: "/Users/person/Library/Application Support/Desktop Studio/Themes", isDirectory: true)
        XCTAssertTrue(ReleaseRules.themesStayOutsideTheApp(appBundle: app, themesDirectory: themes))
        let inside = app.appendingPathComponent("Contents/Resources/Themes", isDirectory: true)
        XCTAssertFalse(ReleaseRules.themesStayOutsideTheApp(appBundle: app, themesDirectory: inside))
    }

    func testUnconfiguredBundleDoesNotPretendUpdatesAreAvailable() {
        let publication = UpdatePublication(feedURL: "", publicKey: "")
        XCTAssertFalse(publication.isConfigured)
        XCTAssertTrue(publication.unavailableReason.contains("not changed") || publication.unavailableReason.contains("not set"))
    }

    func testNetworkAndSignatureFailuresLeaveTheInstalledCopy() {
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertTrue(UpdateFailureCopy.failed(offline).contains("not changed"))
        let signature = NSError(domain: "SUSparkleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "EdDSA signature is not valid"])
        XCTAssertTrue(UpdateFailureCopy.failed(signature).contains("Nothing was installed"))
        let missing = NSError(domain: "SUSparkleErrorDomain", code: 2, userInfo: [NSLocalizedDescriptionKey: "The appcast was not found"])
        XCTAssertTrue(UpdateFailureCopy.failed(missing).contains("not replaced"))
    }
}
