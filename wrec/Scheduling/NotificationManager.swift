import Foundation
import UserNotifications

@MainActor
final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleMeetingReminder(for meeting: ScheduledMeeting) {
        let content = UNMutableNotificationContent()
        content.title = "wrec"
        content.body = "'\(meeting.title)' starts in 1 minute. Ready to record?"
        content.sound = .default
        content.categoryIdentifier = "MEETING_REMINDER"

        let triggerDate = meeting.scheduledStart.addingTimeInterval(-60)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "meeting-reminder-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func scheduleEndReminder(for meeting: ScheduledMeeting) {
        let content = UNMutableNotificationContent()
        content.title = "wrec"
        content.body = "'\(meeting.title)' was scheduled to end 1 minute ago. Stop recording?"
        content.sound = .default
        content.categoryIdentifier = "MEETING_END_REMINDER"

        let triggerDate = meeting.scheduledEnd.addingTimeInterval(60)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "meeting-end-\(meeting.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminders(for meetingId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "meeting-reminder-\(meetingId)",
            "meeting-end-\(meetingId)"
        ])
    }

    func setupNotificationCategories() {
        let startAction = UNNotificationAction(
            identifier: "START_RECORDING",
            title: "Start Recording Now",
            options: .foreground
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )

        let stopAction = UNNotificationAction(
            identifier: "STOP_RECORDING",
            title: "Stop Recording",
            options: .foreground
        )

        let keepGoingAction = UNNotificationAction(
            identifier: "KEEP_GOING",
            title: "Keep Going",
            options: .destructive
        )

        let meetingReminderCategory = UNNotificationCategory(
            identifier: "MEETING_REMINDER",
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let meetingEndCategory = UNNotificationCategory(
            identifier: "MEETING_END_REMINDER",
            actions: [stopAction, keepGoingAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            meetingReminderCategory,
            meetingEndCategory
        ])
    }
}
