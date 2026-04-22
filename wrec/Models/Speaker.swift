import Foundation
import SwiftData

// MARK: - Speaker
@Model
final class Speaker {
    var id: UUID
    var speakerId: Int
    var label: String
    var isMe: Bool

    @Relationship(inverse: \Meeting.speakers) var meeting: Meeting?

    init(
        id: UUID = UUID(),
        speakerId: Int,
        label: String,
        isMe: Bool = false,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.speakerId = speakerId
        self.label = label
        self.isMe = isMe
        self.meeting = meeting
    }
}
