import Foundation
import AVFoundation
import ParakeetASR
import SpeechVAD
import AudioCommon

@main
struct TranscribeTool {
    static func main() async {
        print("wrec Transcription Tool")
        print("========================\n")

        guard CommandLine.arguments.count >= 2 else {
            print("Usage: TranscribeTool <audio_or_video_file>")
            print("Example: TranscribeTool /path/to/video.MOV")
            return
        }

        let inputPath = CommandLine.arguments[1]
        let inputURL = URL(fileURLWithPath: inputPath)

        guard FileManager.default.fileExists(atPath: inputPath) else {
            print("Error: File not found at \(inputPath)")
            return
        }

        print("Input: \(inputURL.lastPathComponent)")
        print("Loading audio...\n")

        do {
            // Extract audio from video
            let audioURL = try await extractAudio(from: inputURL)
            print("Audio extracted to: \(audioURL.path)")

            // Load audio samples
            let samples = try await loadAudioSamples(from: audioURL)
            print("Loaded \(samples.count) audio samples at 16kHz")

            // Clean up extracted audio
            try? FileManager.default.removeItem(at: audioURL)

            // Transcribe
            print("\n--- Transcription ---\n")
            let transcript = try await transcribe(samples: samples)
            print(transcript)

        } catch {
            print("Error: \(error)")
        }
    }

    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw TranscribeError.noAudioTrack
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(readerOutput)

        let writer = try AVAssetWriter(url: outputURL, fileType: .wav)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writer.add(writerInput)

        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio.writer")) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            continuation.resume()
                        }
                        return
                    }
                }
            }
        }

        return outputURL
    }

    static func loadAudioSamples(from url: URL) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TranscribeError.bufferCreationFailed
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw TranscribeError.noAudioData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(frameCount)))
        return samples
    }

    static func transcribe(samples: [Float]) async throws -> String {
        print("Loading Parakeet ASR model...")
        let model = try await ParakeetASRModel.fromPretrained()

        print("Transcribing...\n")

        let result = model.transcribe(audio: samples, sampleRate: 16000, language: nil)

        return result
    }
}

enum TranscribeError: Error {
    case noAudioTrack
    case bufferCreationFailed
    case noAudioData
}
