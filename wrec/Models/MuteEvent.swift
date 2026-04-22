import Foundation
import SwiftData

// MARK: - Audio Stream
enum AudioStream: String, Codable {
    case microphone
    case systemAudio
}

// MARK: - Mute Action
enum MuteAction: String, Codable {
    case muted
    case unmuted
}

// MARK: - Mute Event
@Model
final class MuteEvent {
    var id: UUID
    var timestamp: Double
    var stream: AudioStream
    var action: MuteAction

    @Relationship(inverse: \Meeting.muteEvents) var meeting: Meeting?

    init(
        id: UUID = UUID(),
        timestamp: Double,
        stream: AudioStream,
        action: MuteAction,
        meeting: Meeting? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stream = stream
        self.action = action
        self.meeting = meeting
    }

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
