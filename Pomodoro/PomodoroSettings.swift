import Foundation

/// User preferences, persisted in UserDefaults.
final class PomodoroSettings: ObservableObject {
    static let minutesRange = 1...180
    static let cycleRange = 1...12
    static let repeatRange = 1...5

    private enum Key {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let pomodorosUntilLongBreak = "pomodorosUntilLongBreak"
        static let forceBuiltInSpeakers = "forceBuiltInSpeakers"
        static let soundName = "soundName"
        static let soundVolume = "soundVolume"
        static let soundRepeats = "soundRepeats"
        static let autoStartNext = "autoStartNext"
        static let showNotifications = "showNotifications"
    }

    private let defaults: UserDefaults

    @Published var workMinutes: Int {
        didSet { workMinutes = workMinutes.clamped(to: Self.minutesRange); defaults.set(workMinutes, forKey: Key.workMinutes) }
    }
    @Published var shortBreakMinutes: Int {
        didSet { shortBreakMinutes = shortBreakMinutes.clamped(to: Self.minutesRange); defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) }
    }
    @Published var longBreakMinutes: Int {
        didSet { longBreakMinutes = longBreakMinutes.clamped(to: Self.minutesRange); defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) }
    }
    /// How many focus sessions to complete before the long break.
    @Published var pomodorosUntilLongBreak: Int {
        didSet { pomodorosUntilLongBreak = pomodorosUntilLongBreak.clamped(to: Self.cycleRange); defaults.set(pomodorosUntilLongBreak, forKey: Key.pomodorosUntilLongBreak) }
    }
    /// Route the alert to the built-in MacBook speakers instead of the system output device.
    @Published var forceBuiltInSpeakers: Bool {
        didSet { defaults.set(forceBuiltInSpeakers, forKey: Key.forceBuiltInSpeakers) }
    }
    @Published var soundName: String {
        didSet { defaults.set(soundName, forKey: Key.soundName) }
    }
    @Published var soundVolume: Double {
        didSet { defaults.set(soundVolume, forKey: Key.soundVolume) }
    }
    @Published var soundRepeats: Int {
        didSet { soundRepeats = soundRepeats.clamped(to: Self.repeatRange); defaults.set(soundRepeats, forKey: Key.soundRepeats) }
    }
    @Published var autoStartNext: Bool {
        didSet { defaults.set(autoStartNext, forKey: Key.autoStartNext) }
    }
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: Key.showNotifications) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.workMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.pomodorosUntilLongBreak: 4,
            Key.forceBuiltInSpeakers: true,
            Key.soundName: "Glass",
            Key.soundVolume: 0.8,
            Key.soundRepeats: 2,
            Key.autoStartNext: false,
            Key.showNotifications: true,
        ])
        workMinutes = defaults.integer(forKey: Key.workMinutes).clamped(to: Self.minutesRange)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes).clamped(to: Self.minutesRange)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes).clamped(to: Self.minutesRange)
        pomodorosUntilLongBreak = defaults.integer(forKey: Key.pomodorosUntilLongBreak).clamped(to: Self.cycleRange)
        forceBuiltInSpeakers = defaults.bool(forKey: Key.forceBuiltInSpeakers)
        soundName = defaults.string(forKey: Key.soundName) ?? "Glass"
        soundVolume = defaults.double(forKey: Key.soundVolume)
        soundRepeats = defaults.integer(forKey: Key.soundRepeats).clamped(to: Self.repeatRange)
        autoStartNext = defaults.bool(forKey: Key.autoStartNext)
        showNotifications = defaults.bool(forKey: Key.showNotifications)
    }

    func minutes(for phase: Phase) -> Int {
        switch phase {
        case .work: return workMinutes
        case .shortBreak: return shortBreakMinutes
        case .longBreak: return longBreakMinutes
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
