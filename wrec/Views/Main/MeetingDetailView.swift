import SwiftUI
import SwiftData

struct MeetingDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var selectedTab = 0
    @State private var isEditing = false
    @State private var editedTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if meeting.id == UUID() {
                emptyStateView
            } else {
                meetingContentView
            }
        }
        .navigationTitle(meeting.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(action: {}) {
                        Label("Export as TXT", systemImage: "doc.text")
                    }
                    Button(action: {}) {
                        Label("Export as JSON", systemImage: "doc.badge.gearshape")
                    }
                    Button(action: {}) {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button(action: { isEditing = true }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditMeetingSheet(meeting: meeting)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select a Meeting")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Choose a meeting from the list to view its details")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var meetingContentView: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Tab view
            TabView(selection: $selectedTab) {
                TranscriptTabView(meeting: meeting)
                    .tabItem {
                        Label("Transcript", systemImage: "text.alignleft")
                    }
                    .tag(0)

                AudioPlayerTabView(meeting: meeting)
                    .tabItem {
                        Label("Audio", systemImage: "waveform")
                    }
                    .tag(1)

                NotesTabView(meeting: meeting)
                    .tabItem {
                        Label("Notes", systemImage: "note.text")
                    }
                    .tag(2)

                AIAnalysisTabView(meeting: meeting)
                    .tabItem {
                        Label("AI Analysis", systemImage: "brain")
                    }
                    .tag(3)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Title", text: $editedTitle)
                            .font(.title2)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(meeting.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    HStack(spacing: 8) {
                        Text(meeting.meetingType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)

                        if let startTime = meeting.actualStartTime {
                            Text(startTime, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("• \(meeting.formattedDuration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    ProcessingStatusBadge(status: meeting.transcriptionStatus, label: "Transcript")
                    ProcessingStatusBadge(status: meeting.diarizationStatus, label: "Diarization")
                }
            }

            HStack {
                Button(action: {}) {
                    Label("Re-process", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding()
    }
}

struct EditMeetingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var meeting: Meeting

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Meeting")
                .font(.headline)

            Form {
                TextField("Title", text: $meeting.title)
                Picker("Type", selection: $meeting.meetingType) {
                    ForEach(MeetingType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
