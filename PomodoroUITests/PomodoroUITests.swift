import XCTest

/// Drives the real app through its menu bar item. The app is launched with
/// `--ui-testing`, which gives it fresh, silent settings in a separate suite.
final class PomodoroUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        openPopover()
    }

    override func tearDownWithError() throws {
        if app.state != .notRunning {
            app.terminate()
        }
    }

    // MARK: Helpers

    private var statusItem: XCUIElement { app.statusItems.firstMatch }

    private func openPopover() {
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "menu bar item missing")
        statusItem.click()
        XCTAssertTrue(remainingTime.waitForExistence(timeout: 5), "popover did not open")
    }

    private var phaseTitle: XCUIElement { app.staticTexts["phaseTitle"] }
    private var remainingTime: XCUIElement { app.staticTexts["remainingTime"] }

    private func text(_ element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }

    /// The Settings row. SwiftUI reports the whole row (arrow, label, and the empty space to
    /// its right) as a single disclosure triangle carrying the label's identifier.
    private var settingsToggle: XCUIElement { app.disclosureTriangles["settingsToggle"] }

    /// A point on the word "Settings": past the arrow, inside the label text.
    private var settingsText: XCUICoordinate {
        settingsToggle.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 60, dy: 0))
    }

    /// A point in the empty part of the row, well right of the label text.
    private var settingsRowSpace: XCUICoordinate {
        settingsToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
    }

    private func openSettings() {
        let field = app.textFields["workMinutesField"]
        if field.exists { return }
        XCTAssertTrue(settingsToggle.waitForExistence(timeout: 2), "Settings label missing")
        settingsRowSpace.click()
        XCTAssertTrue(field.waitForExistence(timeout: 3), "settings did not expand")
    }

    private func field(_ id: String) -> XCUIElement { app.textFields["\(id)Field"] }
    private func stepper(_ id: String) -> XCUIElement { app.steppers["\(id)Stepper"] }

    private func fieldValue(_ id: String) -> Int? {
        Int(text(field(id)).filter(\.isNumber))
    }

    private func checkbox(_ title: String) -> XCUIElement { app.checkBoxes[title] }

    private func isOn(_ element: XCUIElement) -> Bool {
        if let number = element.value as? NSNumber { return number.boolValue }
        if let string = element.value as? String { return string == "1" }
        return false
    }

    private func assertAppAlive(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "app is no longer running", file: file, line: line)
        XCTAssertTrue(remainingTime.exists, "popover went away", file: file, line: line)
    }

    private func waitFor(_ element: XCUIElement, toRead expected: String, timeout: TimeInterval = 3,
                         file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if text(element) == expected { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(text(element), expected, file: file, line: line)
    }

    // MARK: Menu bar panel

    func testPanelShowsAFreshFocusSession() {
        XCTAssertEqual(text(phaseTitle), "Focus")
        XCTAssertEqual(text(remainingTime), "25:00")
        XCTAssertTrue(app.buttons["Start"].exists)
        XCTAssertTrue(app.buttons["Reset"].exists)
        XCTAssertTrue(app.buttons["Skip"].exists)
        XCTAssertTrue(app.buttons["Restart cycle"].exists)
        XCTAssertTrue(app.buttons["Quit"].exists)
        XCTAssertEqual(text(app.staticTexts["completedTotal"]), "0 done this session")
        let dots = app.descendants(matching: .any)["cycleDots"]
        XCTAssertTrue(dots.exists)
        XCTAssertEqual(dots.label, "0 of 4 pomodoros before the long break")
    }

    func testStartAndPause() {
        app.buttons["Start"].click()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 2))
        // Wait for the countdown to move off 25:00.
        let deadline = Date().addingTimeInterval(4)
        while text(remainingTime) == "25:00" && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertNotEqual(text(remainingTime), "25:00", "countdown did not move")
        app.buttons["Pause"].click()
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 2))
        let paused = text(remainingTime)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertEqual(text(remainingTime), paused, "paused timer kept counting")
    }

    func testResetRestoresTheFullSession() {
        app.buttons["Start"].click()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        app.buttons["Reset"].click()
        waitFor(remainingTime, toRead: "25:00")
        XCTAssertTrue(app.buttons["Start"].exists)
    }

    func testSkipCyclesThroughPhases() {
        app.buttons["Skip"].click()
        waitFor(phaseTitle, toRead: "Short break")
        XCTAssertEqual(text(remainingTime), "05:00")
        app.buttons["Skip"].click()
        waitFor(phaseTitle, toRead: "Focus")
        XCTAssertEqual(text(remainingTime), "25:00")
        XCTAssertEqual(text(app.staticTexts["completedTotal"]), "0 done this session")
    }

    func testRestartCycleGoesBackToFocus() {
        app.buttons["Skip"].click()
        waitFor(phaseTitle, toRead: "Short break")
        app.buttons["Restart cycle"].click()
        waitFor(phaseTitle, toRead: "Focus")
        XCTAssertEqual(text(remainingTime), "25:00")
    }

    func testMenuBarItemShowsTheTime() {
        let title = statusItem.title.isEmpty ? text(statusItem) : statusItem.title
        XCTAssertTrue(title.contains("25:00"), "menu bar shows '\(title)'")
    }

    func testClickingTheMenuBarItemAgainClosesThePanel() {
        statusItem.click()
        XCTAssertTrue(remainingTime.waitForNonExistence(timeout: 3), "panel stayed open")
        statusItem.click()
        XCTAssertTrue(remainingTime.waitForExistence(timeout: 3), "panel did not reopen")
    }

    func testQuitClosesTheApp() {
        app.buttons["Quit"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
    }

    // MARK: Settings disclosure

    func testClickingTheSettingsTextTogglesSettings() {
        let field = app.textFields["workMinutesField"]
        XCTAssertFalse(field.exists, "settings should start collapsed")
        XCTAssertTrue(settingsToggle.waitForExistence(timeout: 2))
        XCTAssertEqual(settingsToggle.label, "Settings")
        // Click the word "Settings" itself, not the arrow.
        settingsText.click()
        XCTAssertTrue(field.waitForExistence(timeout: 3), "clicking the Settings text did not expand")
        settingsText.click()
        XCTAssertTrue(field.waitForNonExistence(timeout: 3), "clicking the Settings text did not collapse")
    }

    func testClickingTheEmptyRowAreaTogglesSettings() {
        let field = app.textFields["workMinutesField"]
        XCTAssertTrue(settingsToggle.waitForExistence(timeout: 2))
        settingsRowSpace.click()
        XCTAssertTrue(field.waitForExistence(timeout: 3), "clicking the row did not expand settings")
    }

    // MARK: Number settings

    /// Regression: clicking the short break stepper crashed the app.
    func testShortBreakStepperDoesNotCrash() {
        openSettings()
        stepper("shortBreakMinutes").incrementArrows.firstMatch.click()
        assertAppAlive()
        XCTAssertEqual(fieldValue("shortBreakMinutes"), 6)
        stepper("shortBreakMinutes").decrementArrows.firstMatch.click()
        assertAppAlive()
        XCTAssertEqual(fieldValue("shortBreakMinutes"), 5)
    }

    func testEveryStepperIncrementsAndDecrements() {
        openSettings()
        let rows: [(String, Int)] = [
            ("workMinutes", 25),
            ("shortBreakMinutes", 5),
            ("longBreakMinutes", 15),
            ("pomodorosUntilLongBreak", 4),
            ("soundRepeats", 2),
        ]
        for (id, start) in rows {
            XCTAssertEqual(fieldValue(id), start, id)
            stepper(id).incrementArrows.firstMatch.click()
            assertAppAlive()
            XCTAssertEqual(fieldValue(id), start + 1, id)
            stepper(id).decrementArrows.firstMatch.click()
            stepper(id).decrementArrows.firstMatch.click()
            assertAppAlive()
            XCTAssertEqual(fieldValue(id), start - 1, id)
        }
    }

    func testSteppersStopAtTheirLimits() {
        openSettings()
        // Repeat runs 1...5 and starts at 2.
        for _ in 0..<5 { stepper("soundRepeats").incrementArrows.firstMatch.click() }
        assertAppAlive()
        XCTAssertEqual(fieldValue("soundRepeats"), 5)
        for _ in 0..<7 { stepper("soundRepeats").decrementArrows.firstMatch.click() }
        assertAppAlive()
        XCTAssertEqual(fieldValue("soundRepeats"), 1)
    }

    func testFocusStepperResizesTheUnstartedSession() {
        openSettings()
        stepper("workMinutes").incrementArrows.firstMatch.click()
        waitFor(remainingTime, toRead: "26:00")
    }

    func testBreakStepperResizesTheUnstartedBreak() {
        app.buttons["Skip"].click()
        waitFor(phaseTitle, toRead: "Short break")
        openSettings()
        stepper("shortBreakMinutes").incrementArrows.firstMatch.click()
        waitFor(remainingTime, toRead: "06:00")
    }

    func testCycleStepperChangesTheDots() {
        openSettings()
        stepper("pomodorosUntilLongBreak").decrementArrows.firstMatch.click()
        let dots = app.descendants(matching: .any)["cycleDots"]
        waitFor(dots, toRead: "0 of 3 pomodoros before the long break")
    }

    func testTypingANumberIsAccepted() {
        openSettings()
        let focus = field("workMinutes")
        focus.doubleClick()
        focus.typeKey("a", modifierFlags: .command)
        focus.typeText("40\r")
        assertAppAlive()
        XCTAssertEqual(fieldValue("workMinutes"), 40)
        waitFor(remainingTime, toRead: "40:00")
    }

    func testTypingAnOutOfRangeNumberIsClamped() {
        openSettings()
        let longBreak = field("longBreakMinutes")
        longBreak.doubleClick()
        longBreak.typeKey("a", modifierFlags: .command)
        longBreak.typeText("999\r")
        assertAppAlive()
        let deadline = Date().addingTimeInterval(3)
        while fieldValue("longBreakMinutes") != 180 && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertEqual(fieldValue("longBreakMinutes"), 180)
    }

    // MARK: Menu bar display toggles

    func testMenuBarTogglesKeepOneItemVisible() {
        openSettings()
        let icon = checkbox("Show icon")
        let time = checkbox("Show time")
        let seconds = checkbox("Show seconds")
        XCTAssertTrue(isOn(icon) && isOn(time) && isOn(seconds))

        time.click()
        assertAppAlive()
        XCTAssertFalse(isOn(time))
        XCTAssertFalse(icon.isEnabled, "icon must stay on while time is hidden")
        XCTAssertFalse(seconds.isEnabled, "seconds mean nothing without the time")

        time.click()
        XCTAssertTrue(isOn(time))
        XCTAssertTrue(icon.isEnabled)

        icon.click()
        assertAppAlive()
        XCTAssertFalse(isOn(icon))
        XCTAssertFalse(time.isEnabled, "time must stay on while the icon is hidden")
        icon.click()
        XCTAssertTrue(isOn(icon))
    }

    func testHidingSecondsShortensTheMenuBarTime() {
        openSettings()
        checkbox("Show seconds").click()
        assertAppAlive()
        XCTAssertFalse(isOn(checkbox("Show seconds")))
        let deadline = Date().addingTimeInterval(3)
        var title = statusItem.title
        while !title.contains("25m") && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            title = statusItem.title
        }
        XCTAssertTrue(title.contains("25m"), "menu bar shows '\(title)'")
    }

    // MARK: Behaviour and sound settings

    func testBehaviourTogglesFlip() {
        openSettings()
        for title in ["Start the next interval automatically",
                      "Show a notification banner",
                      "Always play the alert on the MacBook speakers"] {
            let box = checkbox(title)
            XCTAssertTrue(box.exists, title)
            let before = isOn(box)
            box.click()
            assertAppAlive()
            XCTAssertNotEqual(isOn(box), before, title)
            box.click()
            XCTAssertEqual(isOn(box), before, title)
        }
    }

    func testSpeakerToggleUpdatesTheOutputDescription() {
        openSettings()
        let description = app.staticTexts["outputDescription"]
        let speakers = checkbox("Always play the alert on the MacBook speakers")
        if isOn(speakers) { speakers.click() }
        waitFor(description, toRead: "Plays through the current system output.")
        speakers.click()
        XCTAssertNotEqual(text(description), "Plays through the current system output.")
    }

    func testSoundPickerChangesTheSound() {
        openSettings()
        let picker = app.popUpButtons["soundPicker"]
        XCTAssertTrue(picker.exists)
        picker.click()
        let ping = app.menuItems["Ping"]
        XCTAssertTrue(ping.waitForExistence(timeout: 3))
        ping.click()
        assertAppAlive()
        waitFor(picker, toRead: "Ping")
    }

    func testVolumeSliderMoves() {
        openSettings()
        let slider = app.sliders["volumeSlider"]
        XCTAssertTrue(slider.exists)
        slider.adjust(toNormalizedSliderPosition: 0.5)
        assertAppAlive()
        let value = (slider.value as? NSNumber)?.doubleValue ?? Double(text(slider)) ?? -1
        XCTAssertEqual(value, 0.5, accuracy: 0.1)
    }

    func testTestSoundButtonDoesNotCrash() {
        openSettings()
        app.buttons["Test sound"].click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        assertAppAlive()
    }
}
