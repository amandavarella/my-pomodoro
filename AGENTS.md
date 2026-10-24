# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Cursor, and others) working in this repository. This is the single source of truth; tool-specific files such as `CLAUDE.md` only point here.

The shared guidance in `~/Code/AGENTS.md` also applies. Where the two disagree, this file wins.

## Project

A macOS menu bar Pomodoro timer written in Swift (SwiftUI + AppKit). The goal is a Pomodoro app that beats the existing ones. There is no Dock icon (`LSUIElement`); everything lives in an `NSStatusItem` and its popover.

- Deployment target: macOS 13. Owner's Mac runs macOS 26 on a notched MacBook.
- Xcode 16+ project (`Pomodoro.xcodeproj`) using file-system synchronized groups: any file added under `Pomodoro/` is compiled automatically, so don't edit `project.pbxproj` just to add sources.
- Swift language mode 5. Info.plist is generated from `INFOPLIST_KEY_*` build settings; there is no Info.plist file.
- No third-party dependencies.

## Build

```sh
xcodebuild -project Pomodoro.xcodeproj -scheme Pomodoro -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Pomodoro.app
```

This only works on macOS. In a Linux cloud container you cannot compile; say so plainly and get the build verified on the owner's Mac (clone at `~/Code/my-pomodoro`) before claiming it works.

## Tests

```sh
xcodebuild -project Pomodoro.xcodeproj -scheme Pomodoro -derivedDataPath build test
```

- `PomodoroTests` (unit, hosted in the app): settings clamping and persistence, the timer state machine, and `TimeFormat`. `PomodoroTimer` takes a `now` clock, so tests drive time by hand and call `tick()`.
- `PomodoroUITests`: launches the app with `--ui-testing` (fresh, silent settings in a separate `UserDefaults` suite), clicks the menu bar item, and exercises every control in the popover and Settings. Add an `accessibilityIdentifier` for any new control and cover it here.
- UI tests need a logged-in Mac session and Accessibility permission for the test runner, so they cannot run in a cloud container.
- Run the whole suite and get it green before committing.

## Architecture

| File | Role |
| --- | --- |
| `PomodoroApp.swift` | `@main` app; `AppDelegate` wires settings, sound, timer, and the status bar. |
| `StatusBarController.swift` | Owns the `NSStatusItem`: icon, countdown text, popover. Re-renders on timer and settings changes. |
| `PomodoroTimer.swift` | `@MainActor` state machine for focus / short break / long break. Counts down against an end `Date` so it survives sleep. Also `TimeFormat`. |
| `PomodoroSettings.swift` | `ObservableObject` persisted to `UserDefaults`; values are clamped in `didSet`. |
| `MenuView.swift` | SwiftUI popover: controls, cycle dots, settings form. |
| `AlertSound.swift` | Plays the alert. Finds the built-in speakers via Core Audio (transport type `kAudioDeviceTransportTypeBuiltIn` with output streams) and sets `AVQueuePlayer.audioOutputDeviceUniqueID`, so it bypasses the system output (the owner routes audio through a Multi-Output Device and BlackHole). |
| `MenuBarIcon.swift` | Template (monochrome) menu bar icons. |
| `Notifier.swift` | Silent `UserNotifications` banners. |

## Requirements to preserve

- The menu bar shows the app icon and remaining time; users can hide either one (never both) and drop the seconds to save space. The owner's menu bar is crowded, so keep the item narrow.
- Focus, short break, long break, and pomodoros-before-long-break are all configurable.
- The interval-finished alert plays on the built-in MacBook speakers regardless of the system output device, falling back to the system output only when no built-in speakers exist.

## Conventions

- Every commit must be authored as `Amanda Varella <amandavarella@gmail.com>`. Before committing in a fresh clone, run:
  `git config user.name "Amanda Varella" && git config user.email amandavarella@gmail.com`
- Never assign a `@Published` property unconditionally inside its own `didSet`: unlike a plain stored property, that re-enters `didSet` and recurses until the app crashes. Only write back when the value actually needs correcting.
- Combine `@Published` publishers emit before the value changes: render from the emitted values, or hop with `.receive(on: RunLoop.main)` before reading the object.
- Ask the owner before opening a PR or merging.
