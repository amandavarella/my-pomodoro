import SwiftUI

struct MenuView: View {
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: PomodoroSettings
    let sound: AlertSound
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            Text(timer.phase.title)
                .font(.headline)
                .foregroundStyle(timer.phase.color)
                .accessibilityIdentifier("phaseTitle")

            Text(TimeFormat.clock(timer.remaining))
                .font(.system(size: 48, weight: .light, design: .rounded).monospacedDigit())
                .accessibilityIdentifier("remainingTime")

            CycleDots(completed: timer.completedInCycle, total: settings.pomodorosUntilLongBreak)

            HStack {
                Button(timer.isRunning ? "Pause" : "Start") { timer.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .tint(timer.phase.color)
                Button("Reset") { timer.reset() }
                Button("Skip") { timer.skip() }
            }

            Divider()

            DisclosureGroup(isExpanded: $showSettings) {
                SettingsForm(settings: settings, sound: sound)
                    .padding(.top, 8)
            } label: {
                // On macOS only the arrow toggles a DisclosureGroup, so make the label
                // (stretched to the full row width) a plain button that toggles it too.
                Button {
                    withAnimation { showSettings.toggle() }
                } label: {
                    Text("Settings")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settingsToggle")
            }

            Divider()

            HStack {
                Text("\(timer.completedTotal) done this session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("completedTotal")
                Spacer()
                Button("Restart cycle") { timer.restartCycle() }
                    .controlSize(.small)
                Button("Quit") { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

/// One dot per pomodoro in the cycle; filled dots are finished focus sessions.
private struct CycleDots: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < completed ? Color.red : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(completed) of \(total) pomodoros before the long break")
        .accessibilityIdentifier("cycleDots")
    }
}

private struct SettingsForm: View {
    @ObservedObject var settings: PomodoroSettings
    let sound: AlertSound

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NumberRow(id: "workMinutes", title: "Focus", unit: "min", value: $settings.workMinutes, range: PomodoroSettings.minutesRange)
            NumberRow(id: "shortBreakMinutes", title: "Short break", unit: "min", value: $settings.shortBreakMinutes, range: PomodoroSettings.minutesRange)
            NumberRow(id: "longBreakMinutes", title: "Long break", unit: "min", value: $settings.longBreakMinutes, range: PomodoroSettings.minutesRange)
            NumberRow(id: "pomodorosUntilLongBreak", title: "Long break after", unit: "pomodoros", value: $settings.pomodorosUntilLongBreak, range: PomodoroSettings.cycleRange)

            Text("Menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Toggle("Show icon", isOn: $settings.showMenuBarIcon)
                .disabled(!settings.showMenuBarTime)
            Toggle("Show time", isOn: $settings.showMenuBarTime)
                .disabled(!settings.showMenuBarIcon)
            Toggle("Show seconds", isOn: $settings.showMenuBarSeconds)
                .disabled(!settings.showMenuBarTime)

            Divider().padding(.vertical, 4)

            Toggle("Start the next interval automatically", isOn: $settings.autoStartNext)
            Toggle("Show a notification banner", isOn: $settings.showNotifications)

            Divider().padding(.vertical, 4)

            Toggle("Always play the alert on the MacBook speakers", isOn: $settings.forceBuiltInSpeakers)
            Text(AlertSound.outputDescription(forceBuiltInSpeakers: settings.forceBuiltInSpeakers))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("outputDescription")

            Picker("Sound", selection: $settings.soundName) {
                ForEach(AlertSound.availableSounds, id: \.self) { Text($0).tag($0) }
            }
            .accessibilityIdentifier("soundPicker")

            HStack {
                Text("Volume")
                Slider(value: $settings.soundVolume, in: 0...1)
                    .accessibilityIdentifier("volumeSlider")
            }

            NumberRow(id: "soundRepeats", title: "Repeat", unit: "times", value: $settings.soundRepeats, range: PomodoroSettings.repeatRange)

            Button("Test sound") { sound.play(settings: settings) }
        }
    }
}

private struct NumberRow: View {
    /// Accessibility identifier prefix, so UI tests can find the field and stepper.
    let id: String
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .accessibilityIdentifier("\(id)Field")
            Text(unit)
                .foregroundStyle(.secondary)
            Stepper(title, value: $value, in: range)
                .labelsHidden()
                .accessibilityIdentifier("\(id)Stepper")
        }
    }
}
