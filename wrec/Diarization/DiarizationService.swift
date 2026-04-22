import Foundation
import SpeechVAD
import AudioCommon

actor DiarizationService {
    private var pipeline: DiarizationPipeline?

    func loadModels(progressHandler: ((Double) -> Void)? = nil) async throws {
        pipeline = try await DiarizationPipeline.fromPretrained(
            progress: { fraction in
                progressHandler?(fraction)
            }
        )
    }

    func diarize(
        audio: [Float],
        sampleRate: Int = 16000,
        config: DiarizationConfig? = nil
    ) async throws -> DiarizationResult {
        guard let pipeline else {
            throw DiarizationError.modelsNotLoaded
        }

        let cfg = config ?? DiarizationConfig(
            onset: 0.5,
            offset: 0.3,
            minSpeechDuration: 0.3,
            minSilenceDuration: 0.15,
            clusteringThreshold: 0.715
        )

        return pipeline.diarize(audio: audio, sampleRate: sampleRate, config: cfg)
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        let dot = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }
}

enum DiarizationError: Error {
    case modelsNotLoaded
    case audioConversionFailed
    case noSpeakersDetected
}
