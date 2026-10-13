import XCTest

final class ExperienceUITests: XCTestCase {
    func testDiscoveryCollectionsAndBadges() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "thewonderofyou.CSign")
        app.launchArguments = ["-hasAcceptedDisclaimer", "YES", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        XCTAssertTrue(app.buttons["Chào linh vật CSign"].waitForExistence(timeout: 30))
        capture("01-home")
        app.buttons["Chào linh vật CSign"].tap()
        XCTAssertTrue(app.staticTexts["Cùng khám phá điều mới nào! ✨"].exists)
        let favorite = app.buttons["discovery.favorite.com.locket.Locket"]
        reveal(favorite, in: app)
        XCTAssertTrue(favorite.waitForExistence(timeout: 30), "Curated apps must resolve from the real repository")
        capture("02-apps")
        favorite.tap()
        let playing = app.buttons["discovery.playing.nt.nb.ios"]
        reveal(playing, in: app)
        XCTAssertTrue(playing.exists)
        playing.tap()
        capture("03-games")
        let badges = app.descendants(matching: .any).matching(identifier: "experience.badges").firstMatch
        reveal(badges, in: app)
        XCTAssertTrue(badges.exists)
        capture("04-playing-and-badges")
        badges.tap()
        let earned = app.buttons["experience.badge.favorite"]
        XCTAssertTrue(earned.waitForExistence(timeout: 10))
        capture("05-badge-cabinet")
        earned.tap()
        XCTAssertTrue(app.buttons["Đeo cho linh vật"].waitForExistence(timeout: 10))
        app.buttons["Đeo cho linh vật"].tap()
        let equipped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Đang đeo"), object: earned)
        XCTAssertEqual(XCTWaiter.wait(for: [equipped], timeout: 5), .completed)
        capture("06-equipped-badge")
        app.tabBars.buttons["IPA Mod"].tap()
        let archives = app.descendants(matching: .any).matching(identifier: "sources.all-repositories").firstMatch
        XCTAssertTrue(archives.waitForExistence(timeout: 15))
        XCTAssertTrue(archives.isHittable, "Repositories must be visible first without scrolling past recommendations or advertising")
        capture("07-sources-first")
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<9 {
            if element.exists && element.isHittable { return }
            app.swipeUp(velocity: .slow)
        }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
