import XCTest
@testable import Pomodoro

final class PomodoroSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PomodoroSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSettings() -> PomodoroSettings {
        PomodoroSettings(defaults: defaults)
    }

    // MARK: Defaults

    func testFreshSettingsUseDefaults() {
        let settings = makeSettings()
        XCTAssertEqual(settings.workMinutes, 25)
        XCTAssertEqual(settings.shortBreakMinutes, 5)
        XCTAssertEqual(settings.longBreakMinutes, 15)
        XCTAssertEqual(settings.pomodorosUntilLongBreak, 4)
        XCTAssertTrue(settings.forceBuiltInSpeakers)
        XCTAssertEqual(settings.soundName, "Glass")
        XCTAssertEqual(settings.soundVolume, 0.8, accuracy: 0.0001)
        XCTAssertEqual(settings.soundRepeats, 2)
        XCTAssertFalse(settings.autoStartNext)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertTrue(settings.showMenuBarTime)
        XCTAssertTrue(settings.showMenuBarSeconds)
    }

    func testMinutesForPhase() {
        let settings = makeSettings()
        settings.workMinutes = 30
        settings.shortBreakMinutes = 7
        settings.longBreakMinutes = 20
        XCTAssertEqual(settings.minutes(for: .work), 30)
        XCTAssertEqual(settings.minutes(for: .shortBreak), 7)
        XCTAssertEqual(settings.minutes(for: .longBreak), 20)
    }

    // MARK: Clamped numbers (the stepper crash)

    private typealias IntSetting = ReferenceWritableKeyPath<PomodoroSettings, Int>

    private let clampedSettings: [(IntSetting, String, ClosedRange<Int>)] = [
        (\.workMinutes, "workMinutes", PomodoroSettings.minutesRange),
        (\.shortBreakMinutes, "shortBreakMinutes", PomodoroSettings.minutesRange),
        (\.longBreakMinutes, "longBreakMinutes", PomodoroSettings.minutesRange),
        (\.pomodorosUntilLongBreak, "pomodorosUntilLongBreak", PomodoroSettings.cycleRange),
        (\.soundRepeats, "soundRepeats", PomodoroSettings.repeatRange),
    ]

    /// Regression: assigning any value used to recurse through didSet until the stack overflowed.
    func testAssigningSameValueDoesNotRecurse() {
        let settings = makeSettings()
        for (keyPath, key, _) in clampedSettings {
            let current = settings[keyPath: keyPath]
            settings[keyPath: keyPath] = current
            XCTAssertEqual(settings[keyPath: keyPath], current, key)
        }
    }

    func testInRangeValuesAreStoredAndPersisted() {
        let settings = makeSettings()
        for (keyPath, key, range) in clampedSettings {
            let value = range.upperBound - 1
            settings[keyPath: keyPath] = value
            XCTAssertEqual(settings[keyPath: keyPath], value, key)
            XCTAssertEqual(defaults.integer(forKey: key), value, key)
        }
    }

    func testRangeEdgesAreAccepted() {
        let settings = makeSettings()
        for (keyPath, key, range) in clampedSettings {
            settings[keyPath: keyPath] = range.lowerBound
            XCTAssertEqual(settings[keyPath: keyPath], range.lowerBound, key)
            settings[keyPath: keyPath] = range.upperBound
            XCTAssertEqual(settings[keyPath: keyPath], range.upperBound, key)
        }
    }

    func testValuesAboveRangeAreClampedAndPersisted() {
        let settings = makeSettings()
        for (keyPath, key, range) in clampedSettings {
            settings[keyPath: keyPath] = range.upperBound + 50
            XCTAssertEqual(settings[keyPath: keyPath], range.upperBound, key)
            XCTAssertEqual(defaults.integer(forKey: key), range.upperBound, key)
        }
    }

    func testValuesBelowRangeAreClampedAndPersisted() {
        let settings = makeSettings()
        for (keyPath, key, range) in clampedSettings {
            settings[keyPath: keyPath] = -3
            XCTAssertEqual(settings[keyPath: keyPath], range.lowerBound, key)
            XCTAssertEqual(defaults.integer(forKey: key), range.lowerBound, key)
        }
    }

    func testStoredOutOfRangeValuesAreClampedOnLoad() {
        defaults.set(999, forKey: "workMinutes")
        defaults.set(0, forKey: "shortBreakMinutes")
        defaults.set(-5, forKey: "longBreakMinutes")
        defaults.set(40, forKey: "pomodorosUntilLongBreak")
        defaults.set(9, forKey: "soundRepeats")
        let settings = makeSettings()
        XCTAssertEqual(settings.workMinutes, PomodoroSettings.minutesRange.upperBound)
        XCTAssertEqual(settings.shortBreakMinutes, PomodoroSettings.minutesRange.lowerBound)
        XCTAssertEqual(settings.longBreakMinutes, PomodoroSettings.minutesRange.lowerBound)
        XCTAssertEqual(settings.pomodorosUntilLongBreak, PomodoroSettings.cycleRange.upperBound)
        XCTAssertEqual(settings.soundRepeats, PomodoroSettings.repeatRange.upperBound)
    }

    func testChangesPublishOncePerAssignment() {
        let settings = makeSettings()
        var count = 0
        let cancellable = settings.objectWillChange.sink { count += 1 }
        settings.shortBreakMinutes = 6
        XCTAssertEqual(count, 1)
        settings.shortBreakMinutes = 500
        XCTAssertEqual(count, 3, "an out-of-range value publishes once for the raw value and once for the clamp")
        cancellable.cancel()
    }

    // MARK: Persistence

    func testAllSettingsSurviveAReload() {
        let settings = makeSettings()
        settings.workMinutes = 50
        settings.shortBreakMinutes = 10
        settings.longBreakMinutes = 30
        settings.pomodorosUntilLongBreak = 3
        settings.forceBuiltInSpeakers = false
        settings.soundName = "Ping"
        settings.soundVolume = 0.25
        settings.soundRepeats = 4
        settings.autoStartNext = true
        settings.showNotifications = false
        settings.showMenuBarIcon = false
        settings.showMenuBarSeconds = false

        let reloaded = makeSettings()
        XCTAssertEqual(reloaded.workMinutes, 50)
        XCTAssertEqual(reloaded.shortBreakMinutes, 10)
        XCTAssertEqual(reloaded.longBreakMinutes, 30)
        XCTAssertEqual(reloaded.pomodorosUntilLongBreak, 3)
        XCTAssertFalse(reloaded.forceBuiltInSpeakers)
        XCTAssertEqual(reloaded.soundName, "Ping")
        XCTAssertEqual(reloaded.soundVolume, 0.25, accuracy: 0.0001)
        XCTAssertEqual(reloaded.soundRepeats, 4)
        XCTAssertTrue(reloaded.autoStartNext)
        XCTAssertFalse(reloaded.showNotifications)
        XCTAssertFalse(reloaded.showMenuBarIcon)
        XCTAssertTrue(reloaded.showMenuBarTime)
        XCTAssertFalse(reloaded.showMenuBarSeconds)
    }

    // MARK: Menu bar contents

    func testCanHideIconWhileTimeShows() {
        let settings = makeSettings()
        settings.showMenuBarIcon = false
        XCTAssertFalse(settings.showMenuBarIcon)
        XCTAssertTrue(settings.showMenuBarTime)
    }

    func testCanHideTimeWhileIconShows() {
        let settings = makeSettings()
        settings.showMenuBarTime = false
        XCTAssertFalse(settings.showMenuBarTime)
        XCTAssertTrue(settings.showMenuBarIcon)
    }

    func testCannotHideIconWhenTimeIsHidden() {
        let settings = makeSettings()
        settings.showMenuBarTime = false
        settings.showMenuBarIcon = false
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertFalse(settings.showMenuBarTime)
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarIcon"))
    }

    func testCannotHideTimeWhenIconIsHidden() {
        let settings = makeSettings()
        settings.showMenuBarIcon = false
        settings.showMenuBarTime = false
        XCTAssertTrue(settings.showMenuBarTime)
        XCTAssertFalse(settings.showMenuBarIcon)
        XCTAssertTrue(defaults.bool(forKey: "showMenuBarTime"))
    }

    func testBothHiddenOnDiskLoadsWithIconShown() {
        defaults.set(false, forKey: "showMenuBarIcon")
        defaults.set(false, forKey: "showMenuBarTime")
        let settings = makeSettings()
        XCTAssertTrue(settings.showMenuBarIcon)
        XCTAssertFalse(settings.showMenuBarTime)
    }

    // MARK: Helpers

    func testClamped() {
        XCTAssertEqual(5.clamped(to: 1...10), 5)
        XCTAssertEqual(0.clamped(to: 1...10), 1)
        XCTAssertEqual(11.clamped(to: 1...10), 10)
        XCTAssertEqual(0.5.clamped(to: 0...1), 0.5)
    }
}
