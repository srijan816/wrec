import Foundation
import AVFoundation

final class AudioMixer {
    private var micBuffer: [Float] = []
    private var systemBuffer: [Float] = []
    private let bufferLock = NSLock()

    private let mixRatio: Float = 0.5

    init() {}

    func addMicSamples(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard let floatData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        micBuffer.append(contentsOf: Array(UnsafeBufferPointer(start: floatData[0], count: frameCount)))

        trimBuffers()
    }

    func addSystemSamples(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard let floatData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        systemBuffer.append(contentsOf: Array(UnsafeBufferPointer(start: floatData[0], count: frameCount)))

        trimBuffers()
    }

    func getMixedBuffer(minFrames: Int = 1024) -> AVAudioPCMBuffer? {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let availableFrames = min(micBuffer.count, systemBuffer.count)
        guard availableFrames > 0 else { return nil }

        let frameCount = min(minFrames, availableFrames)

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let floatData = buffer.floatChannelData else { return nil }

        for i in 0..<frameCount {
            floatData[0][i] = (micBuffer[i] * mixRatio) + (systemBuffer[i] * mixRatio)
        }

        micBuffer.removeFirst(frameCount)
        systemBuffer.removeFirst(frameCount)

        return buffer
    }

    func writeMicSilence(duration: TimeInterval) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let frameCount = Int(16000 * duration)
        micBuffer.append(contentsOf: [Float](repeating: 0, count: frameCount))
    }

    func writeSystemSilence(duration: TimeInterval) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        let frameCount = Int(16000 * duration)
        systemBuffer.append(contentsOf: [Float](repeating: 0, count: frameCount))
    }

    private func trimBuffers(maxSize: Int = 48000 * 60) {
        if micBuffer.count > maxSize {
            micBuffer.removeFirst(micBuffer.count - maxSize)
        }
        if systemBuffer.count > maxSize {
            systemBuffer.removeFirst(systemBuffer.count - maxSize)
        }
    }

    func reset() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        micBuffer.removeAll()
        systemBuffer.removeAll()
    }
}
