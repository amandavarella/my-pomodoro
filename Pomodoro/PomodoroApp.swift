import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The whole UI lives in the menu bar; this empty scene keeps SwiftUI happy.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = PomodoroSettings()
        let sound = AlertSound()
        let timer = PomodoroTimer(settings: settings, sound: sound)
        statusBar = StatusBarController(timer: timer, settings: settings, sound: sound)
        Notifier.requestAuthorization()
    }
}
