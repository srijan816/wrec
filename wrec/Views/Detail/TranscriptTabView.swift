import SwiftUI
import SwiftData

struct TranscriptTabView: View {
    @Bindable var meeting: Meeting
    @State private var searchText = ""
    @State private var editingSpeakerId: Int?
    @State private var editedLabel = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search transcript...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding()

            // Transcript content
            if meeting.segments.isEmpty {
                emptyStateView
            } else {
                transcriptListView
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if meeting.transcriptionStatus == .inProgress {
                ProgressView("Transcribing...")
                    .padding()
            } else {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No Transcript")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Transcript will appear here after processing.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(filteredSegments) { segment in
                    TranscriptSegmentView(
                        segment: segment,
                        isEditing: editingSpeakerId == segment.speakerId,
                        editedLabel: $editedLabel,
                        onStartEditing: {
                            editingSpeakerId = segment.speakerId
                            editedLabel = segment.speakerLabel
                        },
                        onEndEditing: {
                            updateSpeakerLabel(segment: segment)
                            editingSpeakerId = nil
                        }
                    )
                }
            }
            .padding()
        }
    }

    private var filteredSegments: [TranscriptSegment] {
        if searchText.isEmpty {
            return meeting.segments.sorted { $0.startTime < $1.startTime }
        } else {
            return meeting.segments.filter {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.startTime < $1.startTime }
        }
    }

    private func updateSpeakerLabel(segment: TranscriptSegment) {
        guard !editedLabel.isEmpty else { return }

        for s in meeting.segments where s.speakerId == segment.speakerId {
            s.speakerLabel = editedLabel
        }

        if let speaker = meeting.speakers.first(where: { $0.speakerId == segment.speakerId }) {
            speaker.label = editedLabel
        }
    }
}

struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    let isEditing: Bool
    @Binding var editedLabel: String
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(segment.formattedStartTime)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Speaker badge
            if isEditing {
                TextField("Label", text: $editedLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit(onEndEditing)
            } else {
                Button(action: onStartEditing) {
                    SpeakerBadge(
                        label: segment.speakerLabel,
                        isMe: segment.speakerLabel == "Me"
                    )
                }
                .buttonStyle(.plain)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.text)
                    .font(.body)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
