import SwiftUI
import SwiftData

struct NotesTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var meeting: Meeting

    @State private var newNoteContent = ""
    @State private var showingAddNote = false

    var body: some View {
        VStack(spacing: 0) {
            // Add note button
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                Button(action: { showingAddNote = true }) {
                    Label("Add Note", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Notes content
            if meeting.notes.isEmpty {
                emptyStateView
            } else {
                notesListView
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(meeting: meeting, onSave: addNote)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Notes")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Add notes before, during, or after the meeting.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Add First Note") {
                showingAddNote = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notesListView: some View {
        List {
            ForEach([NotePhase.before, .during, .after], id: \.self) { phase in
                let phaseNotes = meeting.notes.filter { $0.phase == phase }.sorted { $0.timestamp < $1.timestamp }

                if !phaseNotes.isEmpty {
                    Section(header: Text(phaseTitle(phase))) {
                        ForEach(phaseNotes) { note in
                            NoteRowView(note: note)
                        }
                        .onDelete { indexSet in
                            deleteNotes(at: indexSet, from: phaseNotes)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func phaseTitle(_ phase: NotePhase) -> String {
        switch phase {
        case .before: return "Before Meeting"
        case .during: return "During Meeting"
        case .after: return "After Meeting"
        }
    }

    private func addNote(content: String, phase: NotePhase, meetingTimestamp: Double?) {
        let note = MeetingNote(
            timestamp: Date(),
            meetingTimestamp: meetingTimestamp,
            phase: phase,
            content: content,
            meeting: meeting
        )
        modelContext.insert(note)
        meeting.notes.append(note)
    }

    private func deleteNotes(at offsets: IndexSet, from notes: [MeetingNote]) {
        for index in offsets {
            let note = notes[index]
            modelContext.delete(note)
        }
    }
}

struct NoteRowView: View {
    let note: MeetingNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let meetingTimestamp = note.formattedMeetingTimestamp {
                    Text("[\(meetingTimestamp)]")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Text(note.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(phaseLabel(note.phase))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(phaseColor(note.phase).opacity(0.2))
                    .cornerRadius(4)
            }

            Text(note.content)
                .font(.body)
        }
        .padding(.vertical, 4)
    }

    private func phaseLabel(_ phase: NotePhase) -> String {
        switch phase {
        case .before: return "Before"
        case .during: return "During"
        case .after: return "After"
        }
    }

    private func phaseColor(_ phase: NotePhase) -> Color {
        switch phase {
        case .before: return .blue
        case .during: return .orange
        case .after: return .green
        }
    }
}

struct AddNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let meeting: Meeting
    let onSave: (String, NotePhase, Double?) -> Void

    @State private var content = ""
    @State private var selectedPhase: NotePhase = .during
    @State private var useMeetingTimestamp = false
    @State private var meetingTimestamp: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Note")
                .font(.headline)

            Picker("Phase", selection: $selectedPhase) {
                Text("Before").tag(NotePhase.before)
                Text("During").tag(NotePhase.during)
                Text("After").tag(NotePhase.after)
            }
            .pickerStyle(.segmented)

            TextEditor(text: $content)
                .frame(height: 150)
                .border(Color.secondary.opacity(0.3))

            Toggle("Add meeting timestamp", isOn: $useMeetingTimestamp)

            if useMeetingTimestamp {
                HStack {
                    Text("Timestamp:")
                    TextField("seconds", value: $meetingTimestamp, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("seconds")
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    onSave(content, selectedPhase, useMeetingTimestamp ? meetingTimestamp : nil)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(content.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
