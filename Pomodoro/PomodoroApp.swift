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
        let uiTesting = CommandLine.arguments.contains("--ui-testing")
        let settings = PomodoroSettings(defaults: uiTesting ? Self.uiTestDefaults() : .standard)
        let sound = AlertSound()
        let timer = PomodoroTimer(settings: settings, sound: sound)
        statusBar = StatusBarController(timer: timer, settings: settings, sound: sound)
        if !uiTesting {
            Notifier.requestAuthorization()
        }
    }

    /// UI tests start from fresh, silent settings and never touch the owner's real preferences.
    private static func uiTestDefaults() -> UserDefaults {
        let suite = "com.amandavarella.MyPomodoro.uitests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(0.0, forKey: "soundVolume")
        defaults.set(false, forKey: "showNotifications")
        return defaults
    }
}
