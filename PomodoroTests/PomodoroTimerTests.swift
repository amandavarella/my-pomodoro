import XCTest
@testable import Pomodoro

/// A clock the tests move by hand.
private final class TestClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(_ seconds: TimeInterval) { now += seconds }
}

@MainActor
final class PomodoroTimerTests: XCTestCase {
    private var suiteName: String!
    private var settings: PomodoroSettings!
    private var clock: TestClock!
    private var timer: PomodoroTimer!

    override func setUp() async throws {
        suiteName = "PomodoroTimerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        settings = PomodoroSettings(defaults: defaults)
        settings.soundVolume = 0
        settings.showNotifications = false
        clock = TestClock()
        timer = makeTimer()
    }

    override func tearDown() async throws {
        timer?.pause()
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    private func makeTimer() -> PomodoroTimer {
        let clock = clock!
        return PomodoroTimer(settings: settings, sound: AlertSound(), now: { clock.now })
    }

    /// Lets the settings observer (which hops a run loop pass) catch up.
    private func drainMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    /// Runs the current phase to its end.
    private func finishPhase() {
        if !timer.isRunning { timer.start() }
        clock.advance(timer.remaining + 0.01)
        timer.tick()
    }

    // MARK: Initial state

    func testStartsOnAPausedFullFocusSession() {
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remaining, 25 * 60)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.completedInCycle, 0)
        XCTAssertEqual(timer.completedTotal, 0)
        XCTAssertEqual(timer.phaseDuration, 25 * 60)
    }

    func testInitialLengthFollowsSettings() {
        settings.workMinutes = 40
        timer = makeTimer()
        XCTAssertEqual(timer.remaining, 40 * 60)
    }

    // MARK: Start, pause, toggle

    func testStartRunsAndTickCountsDown() {
        timer.start()
        XCTAssertTrue(timer.isRunning)
        clock.advance(10)
        timer.tick()
        XCTAssertEqual(timer.remaining, 25 * 60 - 10, accuracy: 0.001)
    }

    func testStartTwiceIsHarmless() {
        timer.start()
        clock.advance(5)
        timer.start()
        timer.tick()
        XCTAssertEqual(timer.remaining, 25 * 60 - 5, accuracy: 0.001)
    }

    func testPauseKeepsRemainingTime() {
        timer.start()
        clock.advance(90)
        timer.pause()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 25 * 60 - 90, accuracy: 0.001)

        // Time spent paused does not count.
        clock.advance(600)
        timer.tick()
        XCTAssertEqual(timer.remaining, 25 * 60 - 90, accuracy: 0.001)

        timer.start()
        clock.advance(30)
        timer.tick()
        XCTAssertEqual(timer.remaining, 25 * 60 - 120, accuracy: 0.001)
    }

    func testPauseWhenNotRunningChangesNothing() {
        timer.pause()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 25 * 60)
    }

    func testToggleStartsAndPauses() {
        timer.toggle()
        XCTAssertTrue(timer.isRunning)
        timer.toggle()
        XCTAssertFalse(timer.isRunning)
    }

    func testCountdownSurvivesALongGapSuchAsSleep() {
        timer.start()
        clock.advance(20 * 60)
        timer.tick()
        XCTAssertEqual(timer.remaining, 5 * 60, accuracy: 0.001)
    }

    // MARK: Finishing phases

    func testFinishingFocusMovesToShortBreakAndCounts() {
        finishPhase()
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.remaining, 5 * 60)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.completedInCycle, 1)
        XCTAssertEqual(timer.completedTotal, 1)
    }

    func testFinishingShortBreakReturnsToFocus() {
        finishPhase()
        finishPhase()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remaining, 25 * 60)
        XCTAssertEqual(timer.completedInCycle, 1)
    }

    func testLongBreakAfterConfiguredPomodoros() {
        settings.pomodorosUntilLongBreak = 3
        for _ in 0..<2 {
            finishPhase() // focus
            XCTAssertEqual(timer.phase, .shortBreak)
            finishPhase() // break
        }
        finishPhase()
        XCTAssertEqual(timer.phase, .longBreak)
        XCTAssertEqual(timer.remaining, 15 * 60)
        XCTAssertEqual(timer.completedInCycle, 3)
    }

    func testFinishingLongBreakStartsANewCycle() {
        settings.pomodorosUntilLongBreak = 1
        finishPhase()
        XCTAssertEqual(timer.phase, .longBreak)
        finishPhase()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.completedInCycle, 0)
        XCTAssertEqual(timer.completedTotal, 1)
    }

    func testTickBeforeTheEndDoesNotFinish() {
        timer.start()
        clock.advance(25 * 60 - 1)
        timer.tick()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertTrue(timer.isRunning)
    }

    func testAutoStartNextRunsTheNextPhase() {
        settings.autoStartNext = true
        finishPhase()
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertTrue(timer.isRunning)
        clock.advance(60)
        timer.tick()
        XCTAssertEqual(timer.remaining, 4 * 60, accuracy: 0.001)
    }

    // MARK: Skip, reset, restart

    func testSkipMovesOnWithoutCounting() {
        timer.skip()
        XCTAssertEqual(timer.phase, .shortBreak)
        XCTAssertEqual(timer.completedInCycle, 0)
        XCTAssertEqual(timer.completedTotal, 0)
        XCTAssertFalse(timer.isRunning)
        timer.skip()
        XCTAssertEqual(timer.phase, .work)
    }

    func testSkipWhileRunningStops() {
        timer.start()
        timer.skip()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining, 5 * 60)
    }

    func testSkippedFocusNeverTriggersLongBreak() {
        settings.pomodorosUntilLongBreak = 1
        timer.skip()
        XCTAssertEqual(timer.phase, .shortBreak)
    }

    func testResetRestoresTheFullPhase() {
        timer.start()
        clock.advance(300)
        timer.tick()
        timer.reset()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remaining, 25 * 60)
    }

    func testRestartCycleClearsProgress() {
        finishPhase()
        finishPhase()
        finishPhase()
        XCTAssertEqual(timer.completedInCycle, 2)
        timer.restartCycle()
        XCTAssertEqual(timer.phase, .work)
        XCTAssertEqual(timer.remaining, 25 * 60)
        XCTAssertEqual(timer.completedInCycle, 0)
        XCTAssertEqual(timer.completedTotal, 2, "the session total keeps counting")
        XCTAssertFalse(timer.isRunning)
    }

    // MARK: Settings changes

    func testChangingLengthResizesAnUnstartedPhase() {
        settings.workMinutes = 30
        drainMainRunLoop()
        XCTAssertEqual(timer.remaining, 30 * 60)
    }

    func testChangingBreakLengthResizesAnUnstartedBreak() {
        timer.skip()
        settings.shortBreakMinutes = 8
        drainMainRunLoop()
        XCTAssertEqual(timer.remaining, 8 * 60)
    }

    func testChangingLengthNeverYanksARunningTimer() {
        timer.start()
        settings.workMinutes = 30
        drainMainRunLoop()
        clock.advance(1)
        timer.tick()
        XCTAssertEqual(timer.remaining, 25 * 60 - 1, accuracy: 0.001)
    }

    func testChangingLengthKeepsAPausedStartedPhase() {
        timer.start()
        clock.advance(60)
        timer.pause()
        settings.workMinutes = 30
        drainMainRunLoop()
        XCTAssertEqual(timer.remaining, 24 * 60, accuracy: 0.001)
    }

    func testChangingAnotherPhaseLengthLeavesTheCurrentOneAlone() {
        settings.shortBreakMinutes = 9
        drainMainRunLoop()
        XCTAssertEqual(timer.remaining, 25 * 60)
        timer.skip()
        XCTAssertEqual(timer.remaining, 9 * 60)
    }

    func testResetPicksUpTheNewLength() {
        timer.start()
        settings.workMinutes = 45
        drainMainRunLoop()
        timer.reset()
        XCTAssertEqual(timer.remaining, 45 * 60)
    }
}
