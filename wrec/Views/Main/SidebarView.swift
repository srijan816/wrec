import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [Meeting]
    @Query private var scheduledMeetings: [ScheduledMeeting]

    @Binding var selectedCategory: SidebarCategory
    @Binding var showSettings: Bool
    @Binding var showImport: Bool

    var body: some View {
        List {
            Section("Import") {
                Button(action: { showImport = true }) {
                    Label("Import File...", systemImage: "square.and.arrow.down")
                }
            }

            Section("Meetings") {
                NavigationLink(value: SidebarCategory.allMeetings) {
                    Label {
                        HStack {
                            Text("All Meetings")
                            Spacer()
                            Text("\(meetings.count)")
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "list.bullet")
                    }
                }

                ForEach(MeetingType.allCases, id: \.self) { type in
                    let count = meetings.filter { $0.meetingType == type }.count
                    if count > 0 {
                        NavigationLink(value: SidebarCategory.meetingType(type)) {
                            Label {
                                HStack {
                                    Text(type.rawValue)
                                    Spacer()
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                            } icon: {
                                Image(systemName: iconForMeetingType(type))
                            }
                        }
                    }
                }
            }

            Section("Scheduled") {
                if scheduledMeetings.filter({ $0.isUpcoming }).isEmpty {
                    Text("No upcoming meetings")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(scheduledMeetings.filter { $0.isUpcoming }.prefix(5)) { meeting in
                        NavigationLink(value: SidebarCategory.scheduled(meeting)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.title)
                                    .font(.subheadline)
                                Text(meeting.formattedTimeUntilStart)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                NavigationLink(value: SidebarCategory.scheduleList) {
                    Label("Schedule Meeting", systemImage: "calendar.badge.plus")
                }
            }

            Section {
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .navigationTitle("wrec")
        .navigationDestination(for: SidebarCategory.self) { category in
            Text("Selected: \(String(describing: category))")
        }
    }

    private func iconForMeetingType(_ type: MeetingType) -> String {
        switch type {
        case .marketingMeeting: return "megaphone"
        case .lessonPlanMeeting: return "book"
        case .studentInterview: return "person.fill.questionmark"
        case .parentTeacherMeeting: return "figure.2.and.child.holdinghands"
        case .parentIntroductoryCall: return "phone"
        case .classSession: return "graduationcap"
        case .spar: return "bolt"
        case .other: return "ellipsis.circle"
        }
    }
}

enum SidebarCategory: Hashable {
    case allMeetings
    case meetingType(MeetingType)
    case scheduled(ScheduledMeeting)
    case scheduleList
    case settings
}
