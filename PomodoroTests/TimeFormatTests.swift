import XCTest
@testable import Pomodoro

final class TimeFormatTests: XCTestCase {
    func testClockFormatsMinutesAndSeconds() {
        XCTAssertEqual(TimeFormat.clock(0), "00:00")
        XCTAssertEqual(TimeFormat.clock(5), "00:05")
        XCTAssertEqual(TimeFormat.clock(65), "01:05")
        XCTAssertEqual(TimeFormat.clock(25 * 60), "25:00")
        XCTAssertEqual(TimeFormat.clock(59 * 60 + 59), "59:59")
    }

    func testClockRoundsUpSoZeroMeansDone() {
        XCTAssertEqual(TimeFormat.clock(0.1), "00:01")
        XCTAssertEqual(TimeFormat.clock(59.2), "01:00")
    }

    func testClockShowsHoursForLongPhases() {
        XCTAssertEqual(TimeFormat.clock(3600), "1:00:00")
        XCTAssertEqual(TimeFormat.clock(3661), "1:01:01")
        XCTAssertEqual(TimeFormat.clock(180 * 60), "3:00:00")
    }

    func testMenuBarWithSecondsMatchesClock() {
        XCTAssertEqual(TimeFormat.menuBar(1500, showSeconds: true), "25:00")
        XCTAssertEqual(TimeFormat.menuBar(61, showSeconds: true), "01:01")
    }

    func testMenuBarWithoutSecondsRoundsUpToWholeMinutes() {
        XCTAssertEqual(TimeFormat.menuBar(1500, showSeconds: false), "25m")
        XCTAssertEqual(TimeFormat.menuBar(1499, showSeconds: false), "25m")
        XCTAssertEqual(TimeFormat.menuBar(61, showSeconds: false), "2m")
        XCTAssertEqual(TimeFormat.menuBar(60, showSeconds: false), "1m")
        XCTAssertEqual(TimeFormat.menuBar(0, showSeconds: false), "0m")
    }

    func testPhaseTitles() {
        XCTAssertEqual(Phase.work.title, "Focus")
        XCTAssertEqual(Phase.shortBreak.title, "Short break")
        XCTAssertEqual(Phase.longBreak.title, "Long break")
    }
}
