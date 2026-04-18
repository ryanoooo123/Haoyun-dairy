import XCTest

/// Reachability tests for the monetization gate. These do NOT attempt a sandbox purchase;
/// they only assert that the paywall entry row in Settings navigates to a sheet containing
/// both '訂閱' and '恢復購買' buttons.
final class StoreKitFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMode"]
        app.launch()
        return app
    }

    func testPaywallIsReachableFromSettings() throws {
        let app = launchedApp()

        let settingsTab = app.tabBars.buttons["設定"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let upgradeRow = app.buttons["升級 Premium"]
        XCTAssertTrue(upgradeRow.waitForExistence(timeout: 3),
                      "Settings must expose a '升級 Premium' row")
        upgradeRow.tap()

        // The paywall sheet should render with the headline.
        let headline = app.staticTexts["好孕日記 Premium"]
        XCTAssertTrue(headline.waitForExistence(timeout: 3),
                      "Paywall headline should be visible after tapping 升級 Premium")
    }

    func testRestorePurchasesButtonPresent() throws {
        let app = launchedApp()

        app.tabBars.buttons["設定"].tap()
        let upgradeRow = app.buttons["升級 Premium"]
        XCTAssertTrue(upgradeRow.waitForExistence(timeout: 5))
        upgradeRow.tap()

        let subscribeBtn = app.buttons["訂閱"]
        let restoreBtn = app.buttons["恢復購買"]
        XCTAssertTrue(subscribeBtn.waitForExistence(timeout: 3),
                      "Paywall must expose a '訂閱' button")
        XCTAssertTrue(restoreBtn.waitForExistence(timeout: 3),
                      "Paywall must expose a '恢復購買' button")
    }
}
