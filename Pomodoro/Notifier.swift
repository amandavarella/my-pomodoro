import Foundation
import UserNotifications

/// Silent banners when a phase ends. The audible alert comes from AlertSound,
/// so the notification itself never plays a sound on the system output.
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func post(finished: Phase, next: Phase, nextMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = finished == .work ? "Focus session done" : "\(finished.title) is over"
        content.body = "Next: \(next.title.lowercased()), \(nextMinutes) min."
        content.sound = nil
        let request = UNNotificationRequest(identifier: "phase-finished", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
