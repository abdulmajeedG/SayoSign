import XCTest

final class SayoSignUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-sayosign.language", "en", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        sleep(3)
    }

    func shot(_ name: String) {
        let full = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        full.name = name
        full.lifetime = .keepAlways
        add(full)
    }

    func tapTab(_ index: Int, _ name: String) {
        let tabs = app.tabBars.buttons
        XCTAssertGreaterThanOrEqual(tabs.count, 4, "Expected four tabs, found \(tabs.count)")
        let button = tabs.element(boundBy: min(index, tabs.count - 1))
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        sleep(1)
        shot(name)
    }

    func testRedesignScreens() throws {
        shot("01-library-light-en")

        // Imported test fixture (Demo App) opens the signing sheet.
        let demo = app.buttons["library.row.com.sayosign.demo"]
        if demo.exists { shot("01b-library-with-demo-en") }
        if demo.waitForExistence(timeout: 4) {
            demo.tap()
            sleep(1)
            shot("02-sign-sheet-en")
            app.swipeUp()
            sleep(1)
            shot("03-sign-sheet-options-en")
            app.swipeDown()
            sleep(1)
            if app.buttons["Close"].exists { app.buttons["Close"].tap() }
            sleep(1)
        }

        tapTab(1, "04-certificates-en")
        if app.buttons["certificates.appleid"].exists {
            app.buttons["certificates.appleid"].tap()
            sleep(2)
            shot("04b-apple-id-signin-en")
            if app.buttons["appleid.close"].exists { app.buttons["appleid.close"].tap() }
            sleep(1)
        }
        if app.buttons["certificates.import"].exists {
            app.buttons["certificates.import"].tap()
            sleep(2)
            shot("05-import-certificate-sheet-en")
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
            sleep(1)
        }

        tapTab(2, "06-sources-en")
        if app.buttons["sources.add"].exists {
            app.buttons["sources.add"].tap()
            sleep(2)
            shot("07-add-source-sheet-en")
            if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
            sleep(1)
        }

        tapTab(3, "08-settings-en")

        if app.buttons["settings.pair"].exists {
            app.buttons["settings.pair"].tap()
            sleep(2)
            shot("08b-pairing-en")
            if app.buttons["pair.close"].exists { app.buttons["pair.close"].tap() }
            sleep(1)
        }

        // Clear the manifest URL to reveal the local installer setup, and preview it.
        let manifest = app.textFields.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR placeholderValue CONTAINS[c] %@", "workers.dev", "workers.dev")
        ).firstMatch
        if manifest.waitForExistence(timeout: 3) {
            manifest.tap()
            manifest.clearText()
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.6)
            let local = app.buttons["settings.localInstaller"]
            for _ in 0..<5 {
                if local.exists && local.isHittable { break }
                app.swipeUp()
                Thread.sleep(forTimeInterval: 0.3)
            }
            if local.exists && local.isHittable {
                local.tap()
                sleep(2)
                shot("08c-local-installer-setup-en")
                app.swipeUp()
                sleep(1)
                shot("08d-local-installer-steps-en")
                if app.buttons["setup.close"].exists { app.buttons["setup.close"].tap() }
                sleep(1)
            }
        }

        // Return to the top before testing appearance and language.
        for _ in 0..<4 {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.25)
        }

        if app.buttons["appearance.dark"].exists {
            app.buttons["appearance.dark"].tap()
            sleep(2)
            shot("09-settings-dark-en")
            app.swipeUp()
            sleep(1)
            shot("10-settings-dark-scrolled-en")
            app.swipeDown()
            sleep(1)
            if app.buttons["appearance.system"].exists { app.buttons["appearance.system"].tap() }
            sleep(1)
        }

        if app.buttons["settings.language"].exists {
            app.buttons["settings.language"].tap()
            sleep(2)
            shot("11-language-picker")
            let arabic = app.buttons["language.ar"]
            if arabic.exists {
                arabic.tap()
                sleep(2)
                shot("12-settings-arabic-rtl")
            }
        }

        // About & credits, including the designer card. Scroll until the row is built.
        let aboutButton = app.buttons["settings.about"]
        var foundAbout = false
        for _ in 0..<12 {
            if aboutButton.exists && aboutButton.isHittable { foundAbout = true; break }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if foundAbout {
            aboutButton.tap()
            sleep(2)
            shot("13-about-arabic")
            app.swipeUp()
            sleep(1)
            shot("14-about-credits-arabic")
            if app.buttons["about.close"].exists { app.buttons["about.close"].tap() }
            sleep(1)
        }

        tapTab(1, "15-certificates-arabic")
        tapTab(2, "16-sources-arabic")
        tapTab(0, "17-library-arabic")

        // Switch to a non-system language (French), then prove it survives a cold launch.
        tapTab(3, "18-settings-arabic-again")
        let languageButton = app.buttons["settings.language"]
        for _ in 0..<6 {
            if languageButton.exists && languageButton.isHittable { break }
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.3)
        }
        if languageButton.exists && languageButton.isHittable {
            languageButton.tap()
            sleep(2)
            if app.buttons["language.fr"].exists {
                app.buttons["language.fr"].tap()
                sleep(2)
                shot("19-settings-french")
            }
        }
        app.terminate()
        let relaunched = XCUIApplication()
        relaunched.launch()
        sleep(3)
        shot("20-relaunch-french-persistence")
        XCTAssertTrue(relaunched.tabBars.buttons["Bibliothèque"].waitForExistence(timeout: 5),
                      "The chosen French language should persist after relaunch")
    }
}


extension XCUIElement {
    func clearText() {
        guard let value = value as? String, !value.isEmpty else { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        typeText(deletes)
    }
}
