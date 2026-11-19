import XCTest

final class AlphaLoopIOSUITests: XCTestCase {
    func testLoginAndTabs() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-autoLoginEmail", "ios@example.com",
            "-autoLoginPassword", "secret123",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["总览"].waitForExistence(timeout: 15))

        app.tabBars.buttons["策略"].tap()
        XCTAssertTrue(
            app.staticTexts["暂无策略"].waitForExistence(timeout: 15)
                || app.staticTexts["加载策略…"].exists
                || app.staticTexts["加载失败"].exists
        )

        app.tabBars.buttons["执行"].tap()
        XCTAssertTrue(app.buttons["全部撤单"].waitForExistence(timeout: 15))

        app.tabBars.buttons["风控"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["禁止新开仓"].waitForExistence(timeout: 15))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["租户"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS 'iosuser'"))
                .firstMatch.waitForExistence(timeout: 10)
        )
        app.swipeUp()
        app.swipeUp()
        for section in ["成员", "设备会话"] {
            XCTAssertTrue(
                app.staticTexts[section].waitForExistence(timeout: 10),
                "missing settings section \(section)"
            )
        }
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["审计日志"].waitForExistence(timeout: 10))
    }
}
