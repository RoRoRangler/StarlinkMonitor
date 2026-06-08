import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestPermission()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func sendOutageNotification(cause: String) {
        let content = UNMutableNotificationContent()
        content.title = "Starlink Outage Detected"
        content.body = "Connection lost: \(cause)"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendRestoredNotification(durationSeconds: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Starlink Restored"
        content.body = "Connection restored after \(String(format: "%.0f", durationSeconds)) seconds."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
