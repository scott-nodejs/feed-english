//
//  SocialFeedAppUITests.swift
//  SocialFeedAppUITests
//
//  Created by Usman on 24.06.25.
//

import XCTest

final class SocialFeedAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testHomeKeepsOriginalLayoutWithoutNewNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["挑战这个场景"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Retry"].exists)
        XCTAssertFalse(app.buttons["账号与后端设置"].exists)
        XCTAssertFalse(app.buttons["PK 邀请"].exists)
        XCTAssertFalse(app.navigationBars["我的账号"].exists)
    }

    @MainActor
    func testLocalPreviewChallengeWithoutBackend() throws {
        let app = XCUIApplication()
        app.launch()
        let challenge = app.buttons["挑战这个场景"].firstMatch
        XCTAssertTrue(challenge.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "恢复后的首页"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        challenge.tap()
        let start = app.buttons["开始挑战"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        app.buttons.containing(.staticText, identifier: "单人练习").firstMatch.tap()
        for index in 0..<8 {
            let answer = app.buttons["查看参考回答"]
            XCTAssertTrue(answer.waitForExistence(timeout: 5))
            answer.tap()
            app.buttons[index == 7 ? "查看演示结果" : "下一句"].tap()
        }
        XCTAssertTrue(app.buttons["再来一局"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "查看详细分析").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["综合评分"].waitForExistence(timeout: 5))
        app.buttons["逐句分析"].tap()
        XCTAssertTrue(app.staticTexts["What can I get for you today?"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
