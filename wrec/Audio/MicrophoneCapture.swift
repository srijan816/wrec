import Foundation
import AVFoundation

protocol MicrophoneCaptureDelegate: AnyObject {
    func microphoneCapture(_ capture: MicrophoneCapture, didReceiveBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime)
}

final class MicrophoneCapture: @unchecked Sendable {
    weak var delegate: MicrophoneCaptureDelegate?

    private let audioEngine = AVAudioEngine()
    private var isCapturing = false
    private var currentInputNode: AVAudioInputNode?

    init() {}

    func start() throws {
        guard !isCapturing else { return }

        let inputNode = audioEngine.inputNode
        currentInputNode = inputNode

        let deviceFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: deviceFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            self.delegate?.microphoneCapture(self, didReceiveBuffer: buffer, at: time)
        }

        try audioEngine.start()
        isCapturing = true
    }

    func stop() {
        guard isCapturing else { return }

        currentInputNode?.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false
        currentInputNode = nil
    }

    var isRunning: Bool {
        isCapturing
    }
}
