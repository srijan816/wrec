import Foundation
import AVFoundation
import SpeechVAD
import AudioCommon

struct DiarizeTool {
    static func run() async {
        print("wrec Diarization Tool")
        print("========================\n")

        guard CommandLine.arguments.count >= 2 else {
            print("Usage: DiarizeTool <audio_or_video_file>")
            print("Example: DiarizeTool /path/to/video.MOV")
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

            // Run diarization
            print("\n--- Diarization ---\n")
            let result = try await diarize(samples: samples)

            // Count unique speakers
            let uniqueSpeakers = Set(result.segments.map { $0.speakerId })
            print("Detected \(uniqueSpeakers.count) speakers")
            print("Found \(result.segments.count) speech segments\n")

            for (i, segment) in result.segments.enumerated() {
                let start = String(format: "%.2f", segment.startTime)
                let end = String(format: "%.2f", segment.endTime)
                print("[\(i)] Speaker \(segment.speakerId): \(start)s - \(end)s")
            }

        } catch {
            print("Error: \(error)")
        }
    }

    static func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw DiarizeError.noAudioTrack
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
            throw DiarizeError.bufferCreationFailed
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw DiarizeError.noAudioData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(frameCount)))
        return samples
    }

    static func diarize(samples: [Float]) async throws -> DiarizationResult {
        print("Loading DiarizationPipeline model...")
        let pipeline = try await DiarizationPipeline.fromPretrained()

        print("Running diarization...\n")

        let config = DiarizationConfig(
            onset: 0.5,
            offset: 0.3,
            minSpeechDuration: 0.3,
            minSilenceDuration: 0.15,
            clusteringThreshold: 0.715
        )

        let result = pipeline.diarize(audio: samples, sampleRate: 16000, config: config)

        return result
    }
}

enum DiarizeError: Error {
    case noAudioTrack
    case bufferCreationFailed
    case noAudioData
}
