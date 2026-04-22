import SwiftUI
import SwiftData

struct ScheduleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScheduledMeeting.scheduledStart) private var scheduledMeetings: [ScheduledMeeting]

    @State private var showingNewMeeting = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scheduled Meetings")
                    .font(.headline)

                Spacer()

                Button(action: { showingNewMeeting = true }) {
                    Label("Schedule", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Content
            if scheduledMeetings.isEmpty {
                emptyStateView
            } else {
                scheduledMeetingsList
            }
        }
        .sheet(isPresented: $showingNewMeeting) {
            ScheduleMeetingView()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Scheduled Meetings")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Schedule a meeting to receive a reminder before it starts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Schedule Meeting") {
                showingNewMeeting = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scheduledMeetingsList: some View {
        List {
            Section("Upcoming") {
                ForEach(scheduledMeetings.filter { $0.isUpcoming }) { meeting in
                    ScheduledMeetingRowView(meeting: meeting)
                }
                .onDelete { indexSet in
                    deleteMeetings(at: indexSet, from: scheduledMeetings.filter { $0.isUpcoming })
                }
            }

            Section("Past") {
                ForEach(scheduledMeetings.filter { !$0.isUpcoming }) { meeting in
                    ScheduledMeetingRowView(meeting: meeting)
                }
                .onDelete { indexSet in
                    deleteMeetings(at: indexSet, from: scheduledMeetings.filter { !$0.isUpcoming })
                }
            }
        }
        .listStyle(.inset)
    }

    private func deleteMeetings(at offsets: IndexSet, from meetings: [ScheduledMeeting]) {
        for index in offsets {
            modelContext.delete(meetings[index])
        }
    }
}

struct ScheduledMeetingRowView: View {
    let meeting: ScheduledMeeting

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meeting.title)
                    .font(.headline)

                Spacer()

                if meeting.reminderFired {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            HStack {
                Text(meeting.meetingType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Text(meeting.scheduledStart, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if meeting.isUpcoming {
                Text(meeting.formattedTimeUntilStart)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}
