import XCTest
@testable import Pomodoro

final class AudioDevicesTests: XCTestCase {
    // Apple silicon Macs list the headphone jack as its own built-in output device,
    // often ahead of the speakers. It must never be picked as "the speakers".
    func testBuiltInSpeakersIsNeverTheHeadphoneJack() throws {
        let speakers = try XCTUnwrap(AudioDevices.builtInSpeakers(), "This Mac has no built-in speakers")
        XCTAssertNotEqual(speakers.uid, "BuiltInHeadphoneOutputDevice")
        XCTAssertFalse(speakers.name.localizedCaseInsensitiveContains("headphone"), speakers.name)
    }
}
