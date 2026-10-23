# my-pomodoro

A Pomodoro timer that lives in the macOS menu bar.

## What it does

- Shows a tomato icon and the remaining time (for example `24:59`) in the menu bar. During breaks the icon switches to a cup, and the countdown dims while paused.
- Click the icon to open the panel: start, pause, reset, or skip the current interval, and see how many pomodoros are left before the long break.
- Open **Settings** in the panel to change:
  - Focus, short break, and long break lengths (1 to 180 minutes).
  - How many pomodoros before the long break (1 to 12).
  - What the menu bar shows: the icon, the time, or both, and whether the time includes seconds (`24:59`) or only minutes (`25m`). Useful when the menu bar is crowded.
  - Whether the next interval starts automatically, and whether a notification banner appears.
  - The alert sound, its volume, and how many times it repeats.
- **The alert always plays on the MacBook speakers**, even when the system output is set to a Multi-Output Device, BlackHole, an aggregate device, or headphones. Turn off "Always play the alert on the MacBook speakers" to follow the system output instead.

Settings are saved and restored between launches.

## Build and run

Requires macOS 13 or later and Xcode 16 or later.

1. Open `Pomodoro.xcodeproj` in Xcode.
2. Pick the **Pomodoro** scheme and **My Mac**, then press Run (⌘R).
3. The app has no Dock icon. Look for the tomato in the menu bar.

To keep it installed, use **Product > Archive**, then **Distribute App > Copy App**, and move `Pomodoro.app` into `/Applications`. Add it under **System Settings > General > Login Items** to start it at login.

## How the speaker routing works

`AlertSound` uses Core Audio to find the output device whose transport type is "built-in" (that is the "MacBook Pro Speakers" entry in the Sound menu), then plays the sound with an `AVQueuePlayer` whose `audioOutputDeviceUniqueID` is set to that device. This targets the speakers directly without changing the system output, so calls, music, and BlackHole routing are left alone.

If no built-in speakers are found, the alert falls back to the system output. The panel tells you which device it will use. The built-in speakers' own volume still applies, so if they are muted you won't hear the alert.

## Project layout

| File | Purpose |
| --- | --- |
| `PomodoroApp.swift` | App entry point; starts the menu bar item. |
| `StatusBarController.swift` | Menu bar icon, countdown text, and the popover. |
| `PomodoroTimer.swift` | Focus and break cycle logic. |
| `PomodoroSettings.swift` | Saved preferences. |
| `MenuView.swift` | The panel UI and settings form. |
| `AlertSound.swift` | Alert playback and the built-in speaker lookup. |
| `MenuBarIcon.swift` | Template icons drawn for the menu bar. |
| `Notifier.swift` | Silent notification banners. |
