import Foundation
import SwiftData

// MARK: - Note Phase
enum NotePhase: String, Codable {
    case before
    case during
    case after
}

// MARK: - Meeting Note
@Model
final class MeetingNote {
    var id: UUID
    var timestamp: Date
    var meetingTimestamp: Double?
    var phase: NotePhase
    var content: String

    @Relationship(inverse: \Meeting.notes) var meeting: Meeting?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        meetingTimestamp: Double? = nil,
        phase: NotePhase = .during,
        content: String,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.meetingTimestamp = meetingTimestamp
        self.phase = phase
        self.content = content
        self.meeting = meeting
    }

    var formattedMeetingTimestamp: String? {
        guard let mt = meetingTimestamp else { return nil }
        let minutes = Int(mt) / 60
        let seconds = Int(mt) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
