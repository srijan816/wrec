import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import CoreAudio

protocol SystemAudioCaptureDelegate: AnyObject {
    func systemAudioCapture(_ capture: SystemAudioCapture, didReceiveBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime)
}

final class SystemAudioCapture: NSObject {
    weak var delegate: SystemAudioCaptureDelegate?

    private var stream: SCStream?
    private var isCapturing = false
    private let targetSampleRate: Double = 16000
    private let audioQueue = DispatchQueue(label: "com.wrec.systemAudio", qos: .userInteractive)

    override init() {}

    @available(macOS 15.0, *)
    func start() async throws {
        guard !isCapturing else { return }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(targetSampleRate)
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true
        config.captureResolution = .best

        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream?.startCapture()

        isCapturing = true
    }

    func stop() async {
        guard isCapturing else { return }

        do {
            try await stream?.stopCapture()
        } catch {
            print("Error stopping system audio capture: \(error)")
        }

        stream = nil
        isCapturing = false
    }

    var isRunning: Bool {
        isCapturing
    }
}

extension SystemAudioCapture: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("System audio stream stopped with error: \(error)")
        isCapturing = false
    }
}

extension SystemAudioCapture: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        guard let buffer = createPCMBuffer(from: sampleBuffer) else { return }

        // Get timing information
        let time = AVAudioTime(
            sampleTime: AVAudioFramePosition(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * targetSampleRate),
            atRate: targetSampleRate
        )

        delegate?.systemAudioCapture(self, didReceiveBuffer: buffer, at: time)
    }

    private func createPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }

        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription?.pointee else { return nil }

        let sampleRate = asbd.mSampleRate
        let channelCount = asbd.mChannelsPerFrame
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)

        guard let pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else { return nil }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let data = dataPointer, let floatData = pcmBuffer.floatChannelData else { return nil }

        let bytesPerSample = 4 // Float32
        let channelStride = frameCount

        for channel in 0..<Int(channelCount) {
            let channelData = floatData[channel]
            for frame in 0..<frameCount {
                let offset = frame * bytesPerSample
                let floatValue = data.advanced(by: offset).withMemoryRebound(to: Float.self, capacity: 1) { $0.pointee }
                channelData[frame] = floatValue
            }
        }

        return pcmBuffer
    }
}

enum SystemAudioCaptureError: Error {
    case noDisplayFound
    case captureNotStarted
}
