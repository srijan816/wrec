import Foundation

enum ExportFormat {
    case txt
    case srt
    case json
    case wav
    case pdf
}

final class TranscriptExporter {
    func export(meeting: Meeting, format: ExportFormat) throws -> URL {
        let exportDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(meeting.title.sanitizedFileName)_\(Date().timeIntervalSince1970)"

        switch format {
        case .txt:
            return try exportAsTxt(meeting: meeting, to: exportDirectory.appendingPathComponent("\(fileName).txt"))
        case .srt:
            return try exportAsSrt(meeting: meeting, to: exportDirectory.appendingPathComponent("\(fileName).srt"))
        case .json:
            return try exportAsJson(meeting: meeting, to: exportDirectory.appendingPathComponent("\(fileName).json"))
        case .wav:
            return try exportAudio(meeting: meeting, to: exportDirectory.appendingPathComponent("\(fileName).wav"))
        case .pdf:
            return try exportAsPdf(meeting: meeting, to: exportDirectory.appendingPathComponent("\(fileName).pdf"))
        }
    }

    private func exportAsTxt(meeting: Meeting, to url: URL) throws -> URL {
        var content = "Meeting: \(meeting.title)\n"
        content += "Date: \(meeting.actualStartTime?.formatted() ?? "Unknown")\n"
        content += "Duration: \(meeting.formattedDuration)\n"
        content += "Type: \(meeting.meetingType.rawValue)\n"
        content += "\n---\n\n"

        for segment in meeting.segments.sorted(by: { $0.startTime < $1.startTime }) {
            content += "[\(segment.formattedStartTime)] \(segment.speakerLabel): \(segment.text)\n\n"
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportAsSrt(meeting: Meeting, to url: URL) throws -> URL {
        var content = ""
        var index = 1

        for segment in meeting.segments.sorted(by: { $0.startTime < $1.startTime }) {
            content += "\(index)\n"
            content += "\(formatSrtTime(segment.startTime)) --> \(formatSrtTime(segment.endTime))\n"
            content += "[\(segment.speakerLabel)] \(segment.text)\n\n"
            index += 1
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func formatSrtTime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, millis)
    }

    private func exportAsJson(meeting: Meeting, to url: URL) throws -> URL {
        let exportData = ExportData(from: meeting)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        try data.write(to: url)
        return url
    }

    private func exportAudio(meeting: Meeting, to url: URL) throws -> URL {
        guard let audioPath = meeting.combinedAudioPath else {
            throw ExportError.audioNotFound
        }

        let sourceURL = URL(fileURLWithPath: audioPath)
        try FileManager.default.copyItem(at: sourceURL, to: url)
        return url
    }

    private func exportAsPdf(meeting: Meeting, to url: URL) throws -> URL {
        let generator = PDFGenerator()
        return try generator.generatePdf(for: meeting, to: url)
    }
}

struct ExportData: Codable {
    let title: String
    let meetingType: String
    let startTime: Date?
    let endTime: Date?
    let duration: String
    let segments: [ExportSegment]
    let notes: [ExportNote]
    let speakers: [ExportSpeaker]

    init(from meeting: Meeting) {
        self.title = meeting.title
        self.meetingType = meeting.meetingType.rawValue
        self.startTime = meeting.actualStartTime
        self.endTime = meeting.actualEndTime
        self.duration = meeting.formattedDuration
        self.segments = meeting.segments.map { ExportSegment(from: $0) }
        self.notes = meeting.notes.map { ExportNote(from: $0) }
        self.speakers = meeting.speakers.map { ExportSpeaker(from: $0) }
    }
}

struct ExportSegment: Codable {
    let speakerLabel: String
    let startTime: Double
    let endTime: Double
    let text: String

    init(from segment: TranscriptSegment) {
        self.speakerLabel = segment.speakerLabel
        self.startTime = segment.startTime
        self.endTime = segment.endTime
        self.text = segment.text
    }
}

struct ExportNote: Codable {
    let content: String
    let timestamp: Date
    let meetingTimestamp: Double?
    let phase: String

    init(from note: MeetingNote) {
        self.content = note.content
        self.timestamp = note.timestamp
        self.meetingTimestamp = note.meetingTimestamp
        self.phase = note.phase.rawValue
    }
}

struct ExportSpeaker: Codable {
    let speakerId: Int
    let label: String
    let isMe: Bool

    init(from speaker: Speaker) {
        self.speakerId = speaker.speakerId
        self.label = speaker.label
        self.isMe = speaker.isMe
    }
}

enum ExportError: Error {
    case audioNotFound
    case exportFailed
}

extension String {
    var sanitizedFileName: String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
