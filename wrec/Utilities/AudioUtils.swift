import Foundation
import AVFoundation

enum AudioUtils {
    static func convertToWav(inputURL: URL, outputURL: URL, targetSampleRate: Double = 16000, targetChannels: AVAudioChannelCount = 1) throws {
        let audioFile = try AVAudioFile(forReading: inputURL)
        let sourceFormat = audioFile.processingFormat

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw AudioUtilsError.converterCreationFailed
        }

        let frameCount = AVAudioFrameCount(Double(audioFile.length) * targetSampleRate / sourceFormat.sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
            throw AudioUtilsError.bufferCreationFailed
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            var frameCount = audioFile.length
            guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                outStatus.pointee = .noDataNow
                return nil
            }

            do {
                try audioFile.read(into: buffer)
                outStatus.pointee = .haveData
                return buffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            throw error
        }

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputBuffer.format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        try outputFile.write(from: outputBuffer)
    }

    static func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let floatData = buffer.floatChannelData else { return 0 }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(floatData[0][i])
        }

        let average = sum / Float(frameLength)
        let db = 20 * log10(average)
        let normalized = max(0, min(1, (db + 60) / 60))

        return normalized
    }

    static func loadAudioSamples(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioUtilsError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)

        guard let floatData = buffer.floatChannelData else {
            throw AudioUtilsError.invalidAudioData
        }

        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
    }
}

enum AudioUtilsError: Error {
    case converterCreationFailed
    case bufferCreationFailed
    case invalidAudioData
}
