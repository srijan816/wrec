import Foundation
import AVFoundation

final class AudioRecorder {
    private var audioFile: AVAudioFile?
    private let recordingFormat: AVAudioFormat
    private let recordingFilePath: URL

    init(filePath: URL, sampleRate: Double = 16000, channels: AVAudioChannelCount = 1) throws {
        self.recordingFilePath = filePath

        recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )!

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false
        ]

        audioFile = try AVAudioFile(
            forWriting: filePath,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func write(buffer: AVAudioPCMBuffer) throws {
        guard let audioFile = audioFile else { return }

        if buffer.format.sampleRate != recordingFormat.sampleRate ||
           buffer.format.channelCount != recordingFormat.channelCount {
            return
        }

        try audioFile.write(from: buffer)
    }

    func writeSilence(duration: TimeInterval) throws {
        guard let audioFile = audioFile else { return }

        let frameCount = AVAudioFrameCount(recordingFormat.sampleRate * duration)
        guard let silenceBuffer = AVAudioPCMBuffer(
            pcmFormat: recordingFormat,
            frameCapacity: frameCount
        ) else { return }

        silenceBuffer.frameLength = frameCount

        if let floatData = silenceBuffer.floatChannelData {
            for channel in 0..<Int(recordingFormat.channelCount) {
                memset(floatData[channel], 0, Int(frameCount) * MemoryLayout<Float>.size)
            }
        }

        try audioFile.write(from: silenceBuffer)
    }

    func close() {
        audioFile = nil
    }

    var fileURL: URL {
        recordingFilePath
    }
}
