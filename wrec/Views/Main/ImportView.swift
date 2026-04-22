import SwiftUI
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importStatus: String = "Select a file to import"
    @State private var selectedMeetingType: MeetingType = .other
    @State private var meetingTitle: String = ""
    @State private var errorMessage: String?
    @State private var transcript: String = ""

    private let transcriber = TranscriptionService.shared

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Import Audio/Video")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Import status
            VStack(spacing: 12) {
                if isImporting {
                    ProgressView(value: importProgress)
                        .progressViewStyle(.linear)

                    Text(importStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !transcript.isEmpty {
                        ScrollView {
                            Text(transcript)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 100)
                    }
                } else if let error = errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("Select an audio or video file to transcribe")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Options
            if !isImporting {
                Form {
                    TextField("Meeting Title", text: $meetingTitle)

                    Picker("Meeting Type", selection: $selectedMeetingType) {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                .frame(height: 100)
            }

            // Actions
            HStack {
                Spacer()

                Button("Select File...") {
                    selectFile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)

                if isImporting {
                    Button("Cancel") {
                        transcriber.cancel()
                        isImporting = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .movie,
            .video,
            .audio,
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "mov") ?? .movie,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "mp4") ?? .movie
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            startImport(url: url)
        }
    }

    private func startImport(url: URL) {
        isImporting = true
        importProgress = 0
        errorMessage = nil
        transcript = ""

        if meetingTitle.isEmpty {
            meetingTitle = url.deletingPathExtension().lastPathComponent
        }

        Task {
            do {
                // Step 1: Extract audio
                await MainActor.run {
                    importStatus = "Extracting audio..."
                    importProgress = 0.1
                }

                let audioURL = try await extractAudio(from: url)

                await MainActor.run {
                    importStatus = "Transcribing with Parakeet..."
                    importProgress = 0.3
                }

                // Step 2: Transcribe
                let result = try await transcriber.transcribe(audioURL: audioURL)

                // Clean up extracted audio
                try? FileManager.default.removeItem(at: audioURL)

                await MainActor.run {
                    transcript = result
                    importStatus = "Creating meeting..."
                    importProgress = 0.8
                }

                // Step 3: Create meeting
                let duration = estimateDuration(audioURL: audioURL, transcript: result)
                let meeting = Meeting(
                    title: meetingTitle,
                    meetingType: selectedMeetingType,
                    actualStartTime: Date(),
                    actualEndTime: Date().addingTimeInterval(duration)
                )

                // Add transcript segment
                let segment = TranscriptSegment(
                    speakerLabel: "Speaker 1",
                    speakerId: 0,
                    startTime: 0,
                    endTime: duration,
                    text: result
                )
                segment.meeting = meeting
                meeting.segments.append(segment)

                modelContext.insert(meeting)

                // Final update
                await MainActor.run {
                    importStatus = "Complete!"
                    importProgress = 1.0
                }

                // Wait a moment to show completion
                try await Task.sleep(nanoseconds: 1_000_000_000)
                dismiss()

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func estimateDuration(audioURL: URL, transcript: String) -> TimeInterval {
        // Rough estimate: ~150 words per minute, average 5 chars per word
        let wordCount = Double(transcript.split(separator: " ").count)
        let minutes = wordCount / 150.0
        return max(60, minutes * 60) // Minimum 1 minute
    }

    private func extractAudio(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)

        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ImportError.noAudioTrack
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
}

enum ImportError: Error, LocalizedError {
    case noAudioTrack
    case bufferCreationFailed
    case noAudioData
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in the file"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noAudioData:
            return "No audio data found"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

// MARK: - Transcription Service
// This service invokes the TranscribeTool CLI
final class TranscriptionService: @unchecked Sendable {
    static let shared = TranscriptionService()
    private var currentTask: Task<String, Error>?

    private init() {}

    func transcribe(audioURL: URL) async throws -> String {
        // Use the TranscribeTool directly
        let transcribeTool = "/Users/tikaram/Downloads/code/MiniMax/wrec/.build/release/TranscribeTool"

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: transcribeTool)
            process.arguments = [audioURL.path]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { proc in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    // Inline transcript parsing
                    let lines = output.components(separatedBy: "\n")
                    var transcriptLines: [String] = []
                    var inTranscript = false

                    for line in lines {
                        if line.contains("--- Transcription ---") {
                            inTranscript = true
                            continue
                        }
                        if line.contains("wrec Transcription") ||
                           line.contains("Input:") ||
                           line.contains("Audio extracted") ||
                           line.contains("Loaded ") ||
                           line.contains("Loading Parakeet") ||
                           line.contains("Transcribing...") ||
                           line.contains("Build of product") ||
                           line.contains("Building for") ||
                           line.isEmpty {
                            continue
                        }
                        if inTranscript {
                            transcriptLines.append(line)
                        }
                    }

                    let transcript = transcriptLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: transcript.isEmpty ? "Transcription completed." : transcript)
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: ImportError.transcriptionFailed(errorOutput))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ImportError.transcriptionFailed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}

extension Task where Success == Never, Failure == Never {
    static func sanitizedExecute(_ process: Process) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "Process", code: Int(proc.terminationStatus)))
                }
            }
            try? process.run()
        }
    }
}
