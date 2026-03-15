import Foundation
import UserNotifications
import UIKit

@Observable
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized = false

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run { isAuthorized = granted }
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Workout Reminders

    func scheduleWorkoutReminder(hour: Int, minute: Int, weekdays: [Int]) {
        // Remove existing workout reminders first
        cancelWorkoutReminders()

        for weekday in weekdays {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.weekday = weekday  // 1=Sunday, 2=Monday, etc.

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = "Time to Train"
            content.body = "Your workout is waiting. Let's get after it."
            content.sound = .default
            content.categoryIdentifier = "WORKOUT_REMINDER"

            let request = UNNotificationRequest(
                identifier: "workout-reminder-\(weekday)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelWorkoutReminders() {
        let identifiers = (1...7).map { "workout-reminder-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Streak Reminders

    func scheduleStreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your Streak!"
        content.body = "You haven't trained today. Keep your streak alive!"
        content.sound = .default
        content.categoryIdentifier = "STREAK_REMINDER"

        // Fire at 7 PM if no workout logged today
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "streak-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Rest Day Reminder

    func scheduleRestDayCheck() {
        let content = UNMutableNotificationContent()
        content.title = "Rest & Recover"
        content.body = "You've trained hard this week. Remember, growth happens during recovery."
        content.sound = .default

        // Schedule for Sunday at 10 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 10

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "rest-day-check",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - One-off Notifications

    func scheduleLocalNotification(title: String, body: String, delay: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel All

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
