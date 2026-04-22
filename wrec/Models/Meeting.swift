import Foundation
import SwiftData

// MARK: - Meeting Types
enum MeetingType: String, Codable, CaseIterable {
    case marketingMeeting = "Marketing Meeting"
    case lessonPlanMeeting = "Lesson Plan Meeting"
    case studentInterview = "Student Interview"
    case parentTeacherMeeting = "Parent Teacher Meeting"
    case parentIntroductoryCall = "Parent Introductory Call"
    case classSession = "Class"
    case spar = "Spar"
    case other = "Other"
}

// MARK: - Processing Status
enum ProcessingStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}

// MARK: - Meeting
@Model
final class Meeting {
    @Attribute(.unique) var id: UUID
    var title: String
    var meetingType: MeetingType
    var scheduledStartTime: Date?
    var scheduledEndTime: Date?
    var actualStartTime: Date?
    var actualEndTime: Date?
    var createdAt: Date
    var updatedAt: Date

    // Audio file paths (relative to meeting directory)
    var micAudioPath: String?
    var systemAudioPath: String?
    var combinedAudioPath: String?

    // Processing state
    var transcriptionStatus: ProcessingStatus
    var diarizationStatus: ProcessingStatus

    // Relationships
    @Relationship(deleteRule: .cascade) var segments: [TranscriptSegment]
    @Relationship(deleteRule: .cascade) var notes: [MeetingNote]
    @Relationship(deleteRule: .cascade) var muteEvents: [MuteEvent]
    @Relationship(deleteRule: .cascade) var speakers: [Speaker]

    // For future MiniMax M2.7 AI analysis
    var aiAnalysisStatus: ProcessingStatus
    var aiAnalysisResult: String?

    init(
        id: UUID = UUID(),
        title: String,
        meetingType: MeetingType = .other,
        scheduledStartTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        actualStartTime: Date? = nil,
        actualEndTime: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        micAudioPath: String? = nil,
        systemAudioPath: String? = nil,
        combinedAudioPath: String? = nil,
        transcriptionStatus: ProcessingStatus = .pending,
        diarizationStatus: ProcessingStatus = .pending,
        segments: [TranscriptSegment] = [],
        notes: [MeetingNote] = [],
        muteEvents: [MuteEvent] = [],
        speakers: [Speaker] = [],
        aiAnalysisStatus: ProcessingStatus = .pending,
        aiAnalysisResult: String? = nil
    ) {
        self.id = id
        self.title = title
        self.meetingType = meetingType
        self.scheduledStartTime = scheduledStartTime
        self.scheduledEndTime = scheduledEndTime
        self.actualStartTime = actualStartTime
        self.actualEndTime = actualEndTime
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.micAudioPath = micAudioPath
        self.systemAudioPath = systemAudioPath
        self.combinedAudioPath = combinedAudioPath
        self.transcriptionStatus = transcriptionStatus
        self.diarizationStatus = diarizationStatus
        self.segments = segments
        self.notes = notes
        self.muteEvents = muteEvents
        self.speakers = speakers
        self.aiAnalysisStatus = aiAnalysisStatus
        self.aiAnalysisResult = aiAnalysisResult
    }

    var duration: TimeInterval? {
        guard let start = actualStartTime, let end = actualEndTime else { return nil }
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
