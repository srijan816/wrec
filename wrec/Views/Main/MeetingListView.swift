import SwiftUI
import SwiftData

struct MeetingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meeting.actualStartTime, order: .reverse) private var meetings: [Meeting]

    let category: SidebarCategory
    @Binding var selectedMeeting: Meeting?

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search meetings...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding()

            // Meeting list
            List(selection: $selectedMeeting) {
                ForEach(filteredMeetings) { meeting in
                    MeetingRowView(meeting: meeting)
                        .tag(meeting)
                        .contextMenu {
                            Button("Export") {
                                // Export action
                            }
                            Button("Delete", role: .destructive) {
                                deleteMeeting(meeting)
                            }
                        }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var filteredMeetings: [Meeting] {
        var result = meetings

        switch category {
        case .allMeetings:
            break
        case .meetingType(let type):
            result = result.filter { $0.meetingType == type }
        case .scheduled(let scheduled):
            result = result.filter { $0.id == scheduled.linkedMeeting?.id }
        case .scheduleList, .settings:
            result = []
        }

        if !searchText.isEmpty {
            result = result.filter { meeting in
                meeting.title.localizedCaseInsensitiveContains(searchText) ||
                meeting.segments.contains { $0.text.localizedCaseInsensitiveContains(searchText) } ||
                meeting.notes.contains { $0.content.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    private var navigationTitle: String {
        switch category {
        case .allMeetings:
            return "All Meetings"
        case .meetingType(let type):
            return type.rawValue
        case .scheduled(let meeting):
            return meeting.title
        case .scheduleList:
            return "Scheduled"
        case .settings:
            return "Settings"
        }
    }

    private func deleteMeeting(_ meeting: Meeting) {
        modelContext.delete(meeting)
    }
}

struct MeetingRowView: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if meeting.transcriptionStatus == .inProgress || meeting.diarizationStatus == .inProgress {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            HStack {
                if let startTime = meeting.actualStartTime {
                    Text(startTime, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if meeting.formattedDuration != "--:--" {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(meeting.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ProcessingStatusBadge(status: meeting.transcriptionStatus, label: "Transcript")
            }

            if !meeting.segments.isEmpty {
                Text(meeting.segments.first?.text ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
