import UIKit
import UserNotifications

extension Notification.Name {
    static let jarvisNotificationOpened = Notification.Name("jarvis.notification.opened")
}
final class JarvisAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Active voice coaching should not be interrupted by a duplicate notification sound.
        completionHandler([.banner])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        if request.identifier.hasPrefix("jarvis-"),
           let day = request.content.userInfo["jarvisDay"] as? String,
           let task = request.content.userInfo["jarvisActivity"] as? String {
            NotificationRoute.save(day: day, taskID: task)
            DispatchQueue.main.async { NotificationCenter.default.post(name: .jarvisNotificationOpened, object: nil) }
        }
        completionHandler()
    }
}
