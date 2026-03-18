import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "notificationsEnabled") }
    }
    @Published var threshold5h: Int {
        didSet { UserDefaults.standard.set(threshold5h, forKey: "notifThreshold5h") }
    }
    @Published var threshold7d: Int {
        didSet { UserDefaults.standard.set(threshold7d, forKey: "notifThreshold7d") }
    }

    private var lastNotified5h = false
    private var lastNotified7d = false

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        let stored5h = UserDefaults.standard.integer(forKey: "notifThreshold5h")
        self.threshold5h = stored5h > 0 ? stored5h : 80
        let stored7d = UserDefaults.standard.integer(forKey: "notifThreshold7d")
        self.threshold7d = stored7d > 0 ? stored7d : 80
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(pct5h: Double, pct7d: Double) {
        guard isEnabled else { return }

        let pct5hInt = Int(round(pct5h * 100))
        let pct7dInt = Int(round(pct7d * 100))

        if pct5hInt >= threshold5h && !lastNotified5h {
            lastNotified5h = true
            send(
                title: Lsync("notif_title_5h"),
                body: String(format: Lsync("notif_body"), pct5hInt)
            )
        } else if pct5hInt < threshold5h {
            lastNotified5h = false
        }

        if pct7dInt >= threshold7d && !lastNotified7d {
            lastNotified7d = true
            send(
                title: Lsync("notif_title_7d"),
                body: String(format: Lsync("notif_body"), pct7dInt)
            )
        } else if pct7dInt < threshold7d {
            lastNotified7d = false
        }
    }

    func sendTest() {
        send(
            title: Lsync("notif_test_title"),
            body: Lsync("notif_test_body")
        )
    }

    private func send(title: String, body: String) {
        // Use osascript for reliable notifications in LSUIElement apps
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\" sound name \"default\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
