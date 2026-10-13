import XCTest

final class ExperienceUITests: XCTestCase {
    func testDiscoveryCollectionsAndBadges() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "thewonderofyou.CSign")
        app.launchArguments = ["-hasAcceptedDisclaimer", "YES", "-CSign.playfulAnimations", "NO", "-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        let mascot = app.buttons["Chào linh vật CSign"]
        XCTAssertTrue(mascot.waitForExistence(timeout: 30))
        mascot.tap() // XCTest handles the first-launch notification prompt here.
        XCTAssertTrue(app.staticTexts["Cùng khám phá điều mới nào! ✨"].exists)
        XCTAssertTrue(app.tabBars.buttons["Trang Chủ"].exists)
        capture("01-home")

        let appCards = app.scrollViews["discovery.cards.apps"]
        reveal(appCards, in: app)
        XCTAssertTrue(appCards.waitForExistence(timeout: 60))
        let appDetails = appCards.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.details."))
        XCTAssertEqual(appDetails.count, 5, "App suggestions must contain five unique downloadable apps")
        let previous = Set(appDetails.allElementsBoundByIndex.map(\.identifier))
        let shuffle = app.buttons["discovery.shuffle.apps"]
        reveal(shuffle, in: app)
        shuffle.tap()
        XCTAssertEqual(appDetails.count, 5)
        XCTAssertNotEqual(Set(appDetails.allElementsBoundByIndex.map(\.identifier)), previous, "Shuffle must introduce another app when the repository has more than five")
        let favorite = appCards.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.favorite.")).firstMatch
        reveal(favorite, in: app)
        capture("02-random-apps")
        favorite.tap()

        let gameCards = app.scrollViews["discovery.cards.games"]
        reveal(gameCards, in: app)
        XCTAssertTrue(gameCards.waitForExistence(timeout: 60))
        let games = gameCards.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.details."))
        XCTAssertEqual(games.count, 5, "Game suggestions must contain five unique downloadable games")
        let playing = gameCards.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "discovery.playing.")).firstMatch
        reveal(playing, in: app)
        playing.tap()
        capture("03-random-games")
        let badges = app.descendants(matching: .any).matching(identifier: "experience.badges").firstMatch
        reveal(badges, in: app)
        XCTAssertTrue(badges.exists)
        badges.tap()
        let earned = app.buttons["experience.badge.favorite"]
        XCTAssertTrue(earned.waitForExistence(timeout: 10))
        earned.tap()
        XCTAssertTrue(app.buttons["Đeo cho linh vật"].waitForExistence(timeout: 10))
        app.buttons["Đeo cho linh vật"].tap()
        let equipped = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Đang đeo"), object: earned)
        XCTAssertEqual(XCTWaiter.wait(for: [equipped], timeout: 5), .completed)
        capture("04-equipped-badge")
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<10 {
            if mascot.isHittable { break }
            app.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(app.staticTexts["Đang đeo huy hiệu Sưu tầm"].exists)
        capture("05-home-equipped")
        app.tabBars.buttons["IPA Mod"].tap()
        XCTAssertTrue(app.buttons["sources.banner.buy"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["sources.banner.buy"].isHittable, "Advertising banners must appear at the top")
        XCTAssertTrue(app.buttons["sources.banner.community"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "sources.all-repositories").firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Tất cả kho lưu trữ"].exists)
        capture("06-banners-first")
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown(velocity: .slow) }
            else { app.swipeUp(velocity: .slow) }
        }
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
