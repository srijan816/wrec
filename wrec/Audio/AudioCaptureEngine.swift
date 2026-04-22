import Foundation
import AVFoundation
import Combine

enum RecordingState {
    case idle
    case scheduled
    case preMeeting
    case recording
    case postProcessing
    case completed
}

protocol AudioCaptureEngineDelegate: AnyObject {
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didReceiveLiveTranscript text: String, isFinal: Bool)
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didUpdateMeterLevel level: Float, forStream stream: AudioStreamType)
    func audioCaptureEngineDidStartRecording(_ engine: AudioCaptureEngine)
    func audioCaptureEngineDidStopRecording(_ engine: AudioCaptureEngine)
    func audioCaptureEngine(_ engine: AudioCaptureEngine, didEncounterError error: Error)
}

enum AudioStreamType {
    case microphone
    case systemAudio
    case combined
}

final class AudioCaptureEngine: ObservableObject, @unchecked Sendable {
    weak var delegate: AudioCaptureEngineDelegate?

    @Published var recordingState: RecordingState = .idle
    @Published var isMicMuted: Bool = false
    @Published var isSystemMuted: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var liveTranscript: String = ""

    private let microphoneCapture = MicrophoneCapture()
    private let systemAudioCapture = SystemAudioCapture()
    private let audioMixer = AudioMixer()

    private var micRecorder: AudioRecorder?
    private var systemRecorder: AudioRecorder?
    private var combinedRecorder: AudioRecorder?

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var meterTimer: Timer?

    private var currentMeetingDirectory: URL?

    init() {
        microphoneCapture.delegate = self
    }

    func startRecording(meetingDirectory: URL) throws {
        guard recordingState == .idle || recordingState == .preMeeting else { return }

        currentMeetingDirectory = meetingDirectory

        let micPath = meetingDirectory.appendingPathComponent("mic.wav")
        let systemPath = meetingDirectory.appendingPathComponent("system.wav")
        let combinedPath = meetingDirectory.appendingPathComponent("combined.wav")

        micRecorder = try AudioRecorder(filePath: micPath)
        systemRecorder = try AudioRecorder(filePath: systemPath)
        combinedRecorder = try AudioRecorder(filePath: combinedPath)

        try microphoneCapture.start()

        if #available(macOS 15.0, *) {
            Task {
                do {
                    try await systemAudioCapture.start()
                } catch {
                    print("System audio capture failed to start: \(error)")
                }
            }
        }

        recordingStartTime = Date()
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(startTime)
        }

        recordingState = .recording
        delegate?.audioCaptureEngineDidStartRecording(self)
    }

    func stopRecording() {
        guard recordingState == .recording else { return }

        recordingState = .postProcessing

        recordingTimer?.invalidate()
        recordingTimer = nil

        microphoneCapture.stop()

        Task {
            await systemAudioCapture.stop()
        }

        micRecorder?.close()
        systemRecorder?.close()
        combinedRecorder?.close()

        micRecorder = nil
        systemRecorder = nil
        combinedRecorder = nil

        recordingState = .completed
        delegate?.audioCaptureEngineDidStopRecording(self)
    }

    func toggleMicMute() {
        isMicMuted.toggle()

        if isMicMuted {
            audioMixer.writeMicSilence(duration: .infinity)
        }
    }

    func toggleSystemMute() {
        isSystemMuted.toggle()

        if isSystemMuted {
            audioMixer.writeSystemSilence(duration: .infinity)
        }
    }

    func setMicMuted(_ muted: Bool) {
        isMicMuted = muted
    }

    func setSystemMuted(_ muted: Bool) {
        isSystemMuted = muted
    }

    private func processCombinedBuffer(_ buffer: AVAudioPCMBuffer) {
        try? combinedRecorder?.write(buffer: buffer)
    }

    private func calculateMeterLevel(for buffer: AVAudioPCMBuffer) -> Float {
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
}

extension AudioCaptureEngine: MicrophoneCaptureDelegate {
    func microphoneCapture(_ capture: MicrophoneCapture, didReceiveBuffer buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard !isMicMuted else { return }

        try? micRecorder?.write(buffer: buffer)
        audioMixer.addMicSamples(buffer)

        if let mixedBuffer = audioMixer.getMixedBuffer() {
            processCombinedBuffer(mixedBuffer)
            delegate?.audioCaptureEngine(self, didUpdateMeterLevel: calculateMeterLevel(for: mixedBuffer), forStream: .microphone)
        }
    }
}
