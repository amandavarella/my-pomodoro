import AppKit
import Combine
import SwiftUI

/// Owns the menu bar item: the app icon, the live countdown next to it, and
/// the popover with controls and settings.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private let settings: PomodoroSettings

    init(timer: PomodoroTimer, settings: PomodoroSettings, sound: AlertSound) {
        self.settings = settings
        super.init()

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            // Monospaced digits stop the menu bar from jiggling every second.
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hosting = NSHostingController(rootView: MenuView(timer: timer, settings: settings, sound: sound))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        // @Published emits before the property changes, so render from the emitted values.
        Publishers.CombineLatest3(timer.$remaining, timer.$phase, timer.$isRunning)
            .sink { [weak self] remaining, phase, isRunning in
                self?.render(remaining: remaining, phase: phase, isRunning: isRunning)
            }
            .store(in: &cancellables)

        // Redraw when the menu bar display settings change; hop a run loop pass so the new values have landed.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self, weak timer] _ in
                guard let timer else { return }
                self?.render(remaining: timer.remaining, phase: timer.phase, isRunning: timer.isRunning)
            }
            .store(in: &cancellables)
    }

    private func render(remaining: TimeInterval, phase: Phase, isRunning: Bool) {
        guard let button = statusItem.button else { return }
        button.image = settings.showMenuBarIcon ? MenuBarIcon.image(for: phase) : nil
        if settings.showMenuBarTime {
            let time = TimeFormat.menuBar(remaining, showSeconds: settings.showMenuBarSeconds)
            button.title = settings.showMenuBarIcon ? " " + time : time
        } else {
            button.title = ""
        }
        // Dim the item while paused so a stopped timer is obvious at a glance.
        button.appearsDisabled = !isRunning
        button.toolTip = "\(phase.title) \(TimeFormat.clock(remaining))\(isRunning ? "" : " (paused)")"
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
