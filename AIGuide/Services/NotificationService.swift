// Notification Service - Local Notifications

import Foundation
import UserNotifications

@MainActor
class NotificationService: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - Singleton
    static let shared = NotificationService()
    
    // MARK: - Initialization
    init() {
        checkAuthorization()
    }
    
    // MARK: - Public Methods
    
    /// Request notification permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            isAuthorized = granted
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    /// Check authorization status
    func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Schedule POI notification
    func schedulePOINotification(poi: POI, delay: TimeInterval = 5) {
        let content = UNMutableNotificationContent()
        content.title = "到达\(poi.name)"
        content.body = poi.description
        content.sound = .default
        content.userInfo = ["poiId": poi.id]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "poi-\(poi.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Schedule tour reminder
    func scheduleTourReminder(tour: TourService.Tour, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "路线提醒"
        content.body = "您计划的\(tour.name)路线即将开始"
        content.sound = .default
        content.userInfo = ["tourId": tour.id]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "tour-\(tour.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Schedule daily tip
    func scheduleDailyTip() {
        let content = UNMutableNotificationContent()
        content.title = "今日小知识"
        content.body = "太和殿是紫禁城最大的宫殿，您知道它有多少根柱子吗？"
        content.sound = .default
        
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily-tip",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Remove notification
    func removeNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Remove all notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Get pending notifications
    func loadPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            Task { @MainActor in
                self?.pendingNotifications = requests
            }
        }
    }
}
