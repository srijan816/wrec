import Foundation

final class TranscriptMerger {
    init() {}

    func merge(
        transcription: TranscriptionResult,
        diarization: DiarizationResult,
        speakerLabels: [(speakerId: Int, label: String)]
    ) -> [AttributedSegment] {
        var attributedSegments: [AttributedSegment] = []

        let labelMap = Dictionary(uniqueKeysWithValues: speakerLabels.map { ($0.speakerId, $0.label) })

        for sentence in transcription.sentences {
            let overlappingSegment = diarization.segments.first { segment in
                sentence.startTime < segment.endTime && sentence.endTime > segment.startTime
            }

            let speakerId = overlappingSegment?.speakerId ?? 0
            let speakerLabel = labelMap[speakerId] ?? "Unknown"

            let segment = AttributedSegment(
                speakerLabel: speakerLabel,
                speakerId: speakerId,
                startTime: sentence.startTime,
                endTime: sentence.endTime,
                text: sentence.text
            )

            attributedSegments.append(segment)
        }

        return attributedSegments
    }

    func mergeWithSimpleAttribution(
        transcription: TranscriptionResult,
        diarization: DiarizationResult
    ) -> [AttributedSegment] {
        var attributedSegments: [AttributedSegment] = []

        for sentence in transcription.sentences {
            let overlappingSegment = diarization.segments.first { segment in
                sentence.startTime < segment.endTime && sentence.endTime > segment.startTime
            }

            let speakerId = overlappingSegment?.speakerId ?? 0
            let speakerLabel: String

            if speakerId == 0 {
                speakerLabel = "Me"
            } else {
                let letter = String(UnicodeScalar(64 + speakerId)!)
                speakerLabel = "Remote Speaker \(letter)"
            }

            let segment = AttributedSegment(
                speakerLabel: speakerLabel,
                speakerId: speakerId,
                startTime: sentence.startTime,
                endTime: sentence.endTime,
                text: sentence.text
            )

            attributedSegments.append(segment)
        }

        return attributedSegments
    }
}
