import Combine
import Foundation
import SwiftUI

enum Phase: String {
    case work, shortBreak, longBreak

    var title: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var color: Color {
        switch self {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

/// Drives the work / break cycle. Time is measured against a target end date,
/// so the countdown stays correct across sleep and timer drift.
@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: Phase = .work
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false
    /// Focus sessions finished since the last long break.
    @Published private(set) var completedInCycle = 0
    /// Focus sessions finished since the app launched.
    @Published private(set) var completedTotal = 0

    let settings: PomodoroSettings
    private let sound: AlertSound
    /// The current time; tests swap in a controllable clock.
    private let now: () -> Date
    private var endDate: Date?
    /// True until the current phase has been started, so settings changes can resize it.
    private var phaseUntouched = true
    private var ticker: AnyCancellable?
    private var settingsObserver: AnyCancellable?

    init(settings: PomodoroSettings, sound: AlertSound, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.sound = sound
        self.now = now
        remaining = TimeInterval(settings.workMinutes * 60)
        // objectWillChange fires before the new value lands, so hop to the next run loop pass.
        settingsObserver = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.settingsChanged() }
    }

    var phaseDuration: TimeInterval {
        TimeInterval(settings.minutes(for: phase) * 60)
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        phaseUntouched = false
        endDate = now().addingTimeInterval(remaining)
        isRunning = true
        ticker = Timer.publish(every: 0.5, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        if let endDate {
            remaining = max(0, endDate.timeIntervalSince(now()))
        }
        endDate = nil
        isRunning = false
        ticker = nil
    }

    /// Restarts the current phase from its full length.
    func reset() {
        pause()
        remaining = phaseDuration
        phaseUntouched = true
    }

    /// Moves to the next phase without counting the current one as finished.
    func skip() {
        advance(completed: false)
    }

    /// Clears the cycle and goes back to a fresh focus session.
    func restartCycle() {
        pause()
        completedInCycle = 0
        phase = .work
        remaining = phaseDuration
        phaseUntouched = true
    }

    func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSince(now())
        if left <= 0 {
            finish()
        } else {
            remaining = left
        }
    }

    private func finish() {
        let finished = phase
        sound.play(settings: settings)
        advance(completed: true)
        if settings.showNotifications {
            Notifier.post(finished: finished, next: phase, nextMinutes: settings.minutes(for: phase))
        }
        if settings.autoStartNext {
            start()
        }
    }

    private func advance(completed: Bool) {
        pause()
        switch phase {
        case .work:
            if completed {
                completedInCycle += 1
                completedTotal += 1
            }
            phase = completedInCycle >= settings.pomodorosUntilLongBreak ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .work
        case .longBreak:
            completedInCycle = 0
            phase = .work
        }
        remaining = phaseDuration
        phaseUntouched = true
    }

    private func settingsChanged() {
        // Only resize a phase that hasn't been started yet; never yank a running timer.
        if !isRunning && phaseUntouched && remaining != phaseDuration {
            remaining = phaseDuration
        }
    }
}

enum TimeFormat {
    /// Formats seconds as m:ss (or h:mm:ss), rounding up so 0:00 means done.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Short form for the menu bar: m:ss, or whole minutes rounded up (e.g. "25m").
    static func menuBar(_ seconds: TimeInterval, showSeconds: Bool) -> String {
        if showSeconds { return clock(seconds) }
        let minutes = Int((seconds / 60).rounded(.up))
        return "\(minutes)m"
    }
}
