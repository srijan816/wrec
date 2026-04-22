import Foundation
import SwiftData
import Combine

@MainActor
final class MeetingScheduler: ObservableObject {
    @Published var upcomingMeetings: [ScheduledMeeting] = []

    private var checkTimer: Timer?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingMeetings()
            }
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func scheduleMeeting(_ meeting: ScheduledMeeting) {
        NotificationManager.shared.scheduleMeetingReminder(for: meeting)
        NotificationManager.shared.scheduleEndReminder(for: meeting)
    }

    func cancelScheduledMeeting(_ meeting: ScheduledMeeting) {
        NotificationManager.shared.cancelReminders(for: meeting.id)
    }

    private func checkUpcomingMeetings() {
        // Check for meetings that are 1 minute away and haven't fired reminder
        for meeting in upcomingMeetings {
            let timeUntilStart = meeting.scheduledStart.timeIntervalSinceNow

            if timeUntilStart <= 60 && timeUntilStart > 0 && !meeting.reminderFired {
                meeting.reminderFired = true
            }

            if timeUntilStart <= -60 && !meeting.endReminderFired {
                meeting.endReminderFired = true
            }
        }
    }
}
