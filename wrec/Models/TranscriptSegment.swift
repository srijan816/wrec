import Foundation
import SwiftData

// MARK: - Transcript Segment
@Model
final class TranscriptSegment {
    var id: UUID
    var speakerLabel: String
    var speakerId: Int
    var startTime: Double
    var endTime: Double
    var text: String

    @Relationship(inverse: \Meeting.segments) var meeting: Meeting?

    init(
        id: UUID = UUID(),
        speakerLabel: String,
        speakerId: Int,
        startTime: Double,
        endTime: Double,
        text: String,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.speakerLabel = speakerLabel
        self.speakerId = speakerId
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.meeting = meeting
    }

    var formattedStartTime: String {
        formatTime(startTime)
    }

    var formattedEndTime: String {
        formatTime(endTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
