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

    init(timer: PomodoroTimer, settings: PomodoroSettings, sound: AlertSound) {
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
    }

    private func render(remaining: TimeInterval, phase: Phase, isRunning: Bool) {
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.image(for: phase)
        button.title = " " + TimeFormat.clock(remaining)
        // Dim the countdown while paused so a stopped timer is obvious at a glance.
        button.appearsDisabled = !isRunning
        button.toolTip = "\(phase.title)\(isRunning ? "" : " (paused)")"
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
