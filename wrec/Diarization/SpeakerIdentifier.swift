import Foundation

final class SpeakerIdentifier {
    init() {}

    func identifyMySpeaker(
        myEmbedding: [Float],
        diarization: DiarizationResult,
        allEmbeddings: [Int: [Float]]
    ) -> Int? {
        // Compare myEmbedding against each speaker cluster centroid
        // Return the speakerId with highest cosine similarity

        var maxSimilarity: Float = -1
        var mySpeakerId: Int?

        for segment in diarization.segments {
            if let embedding = allEmbeddings[segment.speakerId] {
                let similarity = cosineSimilarity(myEmbedding, embedding)

                if similarity > maxSimilarity {
                    maxSimilarity = similarity
                    mySpeakerId = segment.speakerId
                }
            }
        }

        return mySpeakerId
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }

        var dotProduct: Float = 0
        var magnitudeA: Float = 0
        var magnitudeB: Float = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            magnitudeA += a[i] * a[i]
            magnitudeB += b[i] * b[i]
        }

        magnitudeA = sqrt(magnitudeA)
        magnitudeB = sqrt(magnitudeB)

        guard magnitudeA > 0 && magnitudeB > 0 else { return 0 }

        return dotProduct / (magnitudeA * magnitudeB)
    }

    func labelSpeakers(
        diarization: DiarizationResult,
        mySpeakerId: Int?
    ) -> [(speakerId: Int, label: String)] {
        var labels: [(Int, String)] = []
        var remoteIndex = 0

        for segment in diarization.segments {
            if !labels.contains(where: { $0.0 == segment.speakerId }) {
                if segment.speakerId == mySpeakerId {
                    labels.append((segment.speakerId, "Me"))
                } else {
                    remoteIndex += 1
                    let letterValue = UnicodeScalar("A").value + UInt32(remoteIndex - 1)
                    let letter = String(UnicodeScalar(letterValue)!)
                    labels.append((segment.speakerId, "Remote Speaker \(letter)"))
                }
            }
        }

        return labels
    }
}
