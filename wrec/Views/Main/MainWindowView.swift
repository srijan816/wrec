import SwiftUI
import SwiftData

struct MainWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var meetings: [Meeting]

    @State private var selectedCategory: SidebarCategory = .allMeetings
    @State private var selectedMeeting: Meeting?
    @State private var showSettings = false
    @State private var showImport = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCategory: $selectedCategory,
                showSettings: $showSettings,
                showImport: $showImport
            )
        } content: {
            MeetingListView(
                category: selectedCategory,
                selectedMeeting: $selectedMeeting
            )
        } detail: {
            if let meeting = selectedMeeting {
                MeetingDetailView(meeting: meeting)
            } else {
                emptyDetailView
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Meeting Selected")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Select a meeting from the list to view its transcript, audio, and notes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Divider()
                .frame(width: 200)
                .padding(.vertical, 8)

            VStack(spacing: 8) {
                Text("Or import an audio/video file")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { showImport = true }) {
                    Label("Import File...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
