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

## Install

1. Download the latest `Pomodoro-<version>.dmg` from the [download page](https://amandavarella.github.io/my-pomodoro/) or [Releases](https://github.com/amandavarella/my-pomodoro/releases/latest).
2. Open the DMG and drag **Pomodoro** into **Applications**.
3. Open Pomodoro from Applications. Look for the tomato in the menu bar; there is no Dock icon.

Works on macOS 13 or later, on Apple silicon and Intel Macs.

### "Pomodoro can't be opened" on first launch

The app is not notarized by Apple, so macOS blocks the first launch. To allow it once:

- **macOS 15 and later:** open Pomodoro, click **Done** on the warning, then go to **System Settings > Privacy & Security**, scroll down to the message about Pomodoro, and click **Open Anyway**. Confirm with your password, then click **Open**.
- **macOS 13 and 14:** in Applications, Control-click Pomodoro, choose **Open**, then click **Open** in the dialog.
- **Terminal alternative:** `xattr -dr com.apple.quarantine /Applications/Pomodoro.app`

After that it opens normally.

## Build and run

Requires macOS 13 or later and Xcode 16 or later.

1. Open `Pomodoro.xcodeproj` in Xcode.
2. Pick the **Pomodoro** scheme and **My Mac**, then press Run (⌘R).
3. The app has no Dock icon. Look for the tomato in the menu bar.

To start it at login, add it under **System Settings > General > Login Items**.

## Making a release

```sh
./scripts/package-release.sh
```

This builds a universal (Apple silicon and Intel) Release app, ad-hoc signs it, and writes `dist/Pomodoro-<version>.dmg`. Bump `MARKETING_VERSION` in the project first, then attach the DMG to a GitHub Release tagged `v<version>`. The download page in `docs/` always points at the latest release.

## Troubleshooting

- **The icon doesn't appear.** On a MacBook with a notch, menu bar items only fit to the right of the notch, and new items are hidden first when space runs out. Turn off other apps' items in **System Settings > Menu Bar**, hold ⌘ and drag the tomato next to the clock, or turn off "Show icon" or "Show seconds" in Pomodoro's settings to make it narrower. On macOS 26, also check that Pomodoro is on under **System Settings > Menu Bar > Allow in the Menu Bar**.
- **No banners.** Turn on notifications in **System Settings > Notifications > Pomodoro**. The alert sound plays either way.

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

## Contributing

See [`AGENTS.md`](AGENTS.md) for architecture notes, the build command, and commit conventions. `CLAUDE.md` points to the same file.
