import Foundation
import SwiftData

// MARK: - Scheduled Meeting
@Model
final class ScheduledMeeting {
    var id: UUID
    var title: String
    var meetingType: MeetingType
    var scheduledStart: Date
    var scheduledEnd: Date
    var preNotes: String
    var reminderFired: Bool
    var endReminderFired: Bool

    @Relationship var linkedMeeting: Meeting?

    init(
        id: UUID = UUID(),
        title: String,
        meetingType: MeetingType = .other,
        scheduledStart: Date,
        scheduledEnd: Date,
        preNotes: String = "",
        reminderFired: Bool = false,
        endReminderFired: Bool = false,
        linkedMeeting: Meeting? = nil
    ) {
        self.id = id
        self.title = title
        self.meetingType = meetingType
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.preNotes = preNotes
        self.reminderFired = reminderFired
        self.endReminderFired = endReminderFired
        self.linkedMeeting = linkedMeeting
    }

    var isUpcoming: Bool {
        scheduledStart > Date()
    }

    var timeUntilStart: TimeInterval {
        scheduledStart.timeIntervalSinceNow
    }

    var formattedTimeUntilStart: String {
        let interval = timeUntilStart
        if interval < 60 {
            return "Starting soon"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "in \(minutes) min"
        } else {
            let hours = Int(interval / 3600)
            return "in \(hours) hour\(hours > 1 ? "s" : "")"
        }
    }
}
