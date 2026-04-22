import Foundation
import AVFoundation

protocol LiveTranscriptionEngineDelegate: AnyObject {
    func liveTranscriptionEngine(_ engine: LiveTranscriptionEngine, didReceivePartialText text: String)
    func liveTranscriptionEngine(_ engine: LiveTranscriptionEngine, didReceiveFinalText text: String, at timestamp: Double)
}

final class LiveTranscriptionEngine {
    weak var delegate: LiveTranscriptionEngineDelegate?

    private var isRunning = false
    private var partialText = ""

    init() {}

    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at timestamp: TimeInterval) async {
        guard isRunning else { return }

        // Note: ParakeetStreamingASR usage would go here
        // This is a placeholder for the actual streaming transcription
        // which would use the ParakeetStreamingASRModel.fromPretrained()
    }

    func start() {
        isRunning = true
        partialText = ""
    }

    func stop() {
        isRunning = false
    }

    func appendPartialText(_ text: String) {
        partialText = text
        delegate?.liveTranscriptionEngine(self, didReceivePartialText: text)
    }

    func finalizeText(_ text: String, at timestamp: TimeInterval) {
        partialText = ""
        delegate?.liveTranscriptionEngine(self, didReceiveFinalText: text, at: timestamp)
    }
}
