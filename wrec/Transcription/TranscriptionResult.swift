import Foundation

struct TranscriptionResult: Codable {
    let words: [WordResult]
    let sentences: [SentenceResult]
}

struct WordResult: Codable {
    let text: String
    let startTime: Double
    let endTime: Double
    let confidence: Float
}

struct SentenceResult: Codable {
    let text: String
    let startTime: Double
    let endTime: Double
    let words: [WordResult]
}

struct DiarizationResult: Codable {
    let segments: [DiarizationSegment]
    let numSpeakers: Int
}

struct DiarizationSegment: Codable {
    let speakerId: Int
    let startTime: Double
    let endTime: Double
    let embedding: [Float]?
}

struct AttributedSegment: Codable, Identifiable {
    let id: UUID
    let speakerLabel: String
    let speakerId: Int
    let startTime: Double
    let endTime: Double
    let text: String

    init(
        id: UUID = UUID(),
        speakerLabel: String,
        speakerId: Int,
        startTime: Double,
        endTime: Double,
        text: String
    ) {
        self.id = id
        self.speakerLabel = speakerLabel
        self.speakerId = speakerId
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}
