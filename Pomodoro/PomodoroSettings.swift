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
        static let showMenuBarIcon = "showMenuBarIcon"
        static let showMenuBarTime = "showMenuBarTime"
        static let showMenuBarSeconds = "showMenuBarSeconds"
    }

    private let defaults: UserDefaults

    @Published var workMinutes: Int {
        didSet { store(workMinutes, in: Self.minutesRange, key: Key.workMinutes) { workMinutes = $0 } }
    }
    @Published var shortBreakMinutes: Int {
        didSet { store(shortBreakMinutes, in: Self.minutesRange, key: Key.shortBreakMinutes) { shortBreakMinutes = $0 } }
    }
    @Published var longBreakMinutes: Int {
        didSet { store(longBreakMinutes, in: Self.minutesRange, key: Key.longBreakMinutes) { longBreakMinutes = $0 } }
    }
    /// How many focus sessions to complete before the long break.
    @Published var pomodorosUntilLongBreak: Int {
        didSet { store(pomodorosUntilLongBreak, in: Self.cycleRange, key: Key.pomodorosUntilLongBreak) { pomodorosUntilLongBreak = $0 } }
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
        didSet { store(soundRepeats, in: Self.repeatRange, key: Key.soundRepeats) { soundRepeats = $0 } }
    }
    @Published var autoStartNext: Bool {
        didSet { defaults.set(autoStartNext, forKey: Key.autoStartNext) }
    }
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: Key.showNotifications) }
    }
    /// Menu bar contents. At least one of icon or time stays on so the item never vanishes.
    @Published var showMenuBarIcon: Bool {
        didSet {
            if !showMenuBarIcon && !showMenuBarTime { showMenuBarIcon = true }
            defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
        }
    }
    @Published var showMenuBarTime: Bool {
        didSet {
            if !showMenuBarTime && !showMenuBarIcon { showMenuBarTime = true }
            defaults.set(showMenuBarTime, forKey: Key.showMenuBarTime)
        }
    }
    /// Show m:ss in the menu bar; when off, show whole minutes (e.g. "25m") to save space.
    @Published var showMenuBarSeconds: Bool {
        didSet { defaults.set(showMenuBarSeconds, forKey: Key.showMenuBarSeconds) }
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
            Key.showMenuBarIcon: true,
            Key.showMenuBarTime: true,
            Key.showMenuBarSeconds: true,
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
        let showIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        let showTime = defaults.bool(forKey: Key.showMenuBarTime)
        showMenuBarIcon = showIcon || !showTime
        showMenuBarTime = showTime
        showMenuBarSeconds = defaults.bool(forKey: Key.showMenuBarSeconds)
    }

    /// Saves an in-range value, or clamps it and lets the re-entered didSet save that.
    /// Assigning a @Published property inside its own didSet re-enters didSet (unlike a
    /// plain stored property), so writing back unconditionally recurses until the stack overflows.
    private func store(_ value: Int, in range: ClosedRange<Int>, key: String, clamp: (Int) -> Void) {
        if range.contains(value) {
            defaults.set(value, forKey: key)
        } else {
            clamp(value.clamped(to: range))
        }
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
