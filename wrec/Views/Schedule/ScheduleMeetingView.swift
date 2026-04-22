import SwiftUI
import SwiftData

struct ScheduleMeetingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var meetingType: MeetingType = .other
    @State private var scheduledStart = Date()
    @State private var scheduledEnd = Date().addingTimeInterval(3600)
    @State private var preNotes = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Schedule Meeting")
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

            // Form
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    Picker("Type", selection: $meetingType) {
                        ForEach(MeetingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Time") {
                    DatePicker("Start", selection: $scheduledStart)

                    DatePicker("End", selection: $scheduledEnd)
                }

                Section("Pre-Meeting Notes") {
                    TextEditor(text: $preNotes)
                        .frame(height: 100)
                }
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Schedule") {
                    saveMeeting()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || scheduledEnd <= scheduledStart)
            }
            .padding()
        }
        .frame(width: 450)
    }

    private func saveMeeting() {
        let scheduled = ScheduledMeeting(
            title: title,
            meetingType: meetingType,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            preNotes: preNotes
        )

        modelContext.insert(scheduled)
        dismiss()
    }
}
