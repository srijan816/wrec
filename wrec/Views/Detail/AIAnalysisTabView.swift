import SwiftUI

struct AIAnalysisTabView: View {
    @Bindable var meeting: Meeting
    @AppStorage("minimaxApiKey") private var apiKey = ""

    @State private var selectedAnalysisType: MeetingType?
    @State private var isAnalyzing = false

    var body: some View {
        VStack(spacing: 20) {
            if meeting.aiAnalysisStatus == .pending || meeting.aiAnalysisResult == nil {
                placeholderView
            } else {
                analysisResultView
            }
        }
        .padding()
    }

    private var placeholderView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("AI Analysis")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AI-powered analysis of your meeting transcript will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            if apiKey.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "key.slash")
                        .font(.title)
                        .foregroundColor(.orange)

                    Text("API Key Required")
                        .font(.headline)

                    Text("Please add your MiniMax API key in Settings to enable AI analysis.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis Type")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Analysis Type", selection: $selectedAnalysisType) {
                        Text("Auto-detect").tag(MeetingType?.none)
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(MeetingType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(spacing: 8) {
                    Text("Run Analysis")
                        .font(.headline)

                    Button(action: runAnalysis) {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isAnalyzing ? "Analyzing..." : "Analyze Transcript")
                        }
                        .frame(maxWidth: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzing || meeting.segments.isEmpty)

                    Text("Powered by MiniMax M2.7 API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var analysisResultView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Analysis Complete")
                        .font(.headline)

                    Spacer()

                    Button("Re-analyze") {
                        runAnalysis()
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                if let result = meeting.aiAnalysisResult {
                    Text(result)
                        .font(.body)
                } else {
                    Text("Analysis result unavailable.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private func runAnalysis() {
        guard !isAnalyzing, !apiKey.isEmpty else { return }

        isAnalyzing = true
        meeting.aiAnalysisStatus = .inProgress

        Task {
            do {
                let analyzer = MiniMaxAnalyzer(apiKey: apiKey)
                let transcriptText = meeting.segments.map { "\($0.speakerLabel): \($0.text)" }.joined(separator: "\n")

                let result = try await analyzer.analyzeTranscript(
                    transcript: transcriptText,
                    meetingType: selectedAnalysisType ?? meeting.meetingType
                )

                await MainActor.run {
                    meeting.aiAnalysisResult = result
                    meeting.aiAnalysisStatus = .completed
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    meeting.aiAnalysisStatus = .failed
                    isAnalyzing = false
                }
            }
        }
    }
}
