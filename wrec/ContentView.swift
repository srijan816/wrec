import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var audioEngine: AudioCaptureEngine
    @EnvironmentObject var deviceManager: DeviceManager

    @State private var showingMainWindow = false
    @State private var isRecording = false
    @State private var selectedMeetingType: MeetingType = .other
    @State private var currentMeetingDirectory: URL?

    var body: some View {
        ZStack {
            if showingMainWindow {
                MainWindowView()
            } else {
                MenuBarContentView(
                    audioEngine: audioEngine,
                    deviceManager: deviceManager,
                    selectedMeetingType: $selectedMeetingType,
                    isRecording: $isRecording,
                    onOpenMainWindow: { showingMainWindow = true },
                    onStartRecording: startRecording,
                    onStopRecording: stopRecording,
                    onToggleMic: { audioEngine.toggleMicMute() },
                    onToggleSystem: { audioEngine.toggleSystemMute() },
                    onAddNote: { /* Add note action */ }
                )
            }
        }
        .onAppear {
            _ = audioEngine
            _ = deviceManager
            setupNotificationObservers()
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: .startRecording, object: nil, queue: .main) { _ in
            startRecording()
        }
        NotificationCenter.default.addObserver(forName: .stopRecording, object: nil, queue: .main) { _ in
            stopRecording()
        }
    }

    private func startRecording() {
        let meetingDir = FileManager.createMeetingDirectory(title: "New Meeting")
        currentMeetingDirectory = meetingDir

        do {
            try audioEngine.startRecording(meetingDirectory: meetingDir)
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioEngine.stopRecording()
        isRecording = false
    }
}

struct MenuBarContentView: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedMeetingType: MeetingType
    @Binding var isRecording: Bool

    let onOpenMainWindow: () -> Void
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onToggleMic: () -> Void
    let onToggleSystem: () -> Void
    let onAddNote: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isRecording {
                RecordingControlsView(
                    audioEngine: audioEngine,
                    selectedMeetingType: $selectedMeetingType,
                    onStartRecording: {},
                    onStopRecording: onStopRecording,
                    onToggleMic: onToggleMic,
                    onToggleSystem: onToggleSystem,
                    onAddNote: onAddNote,
                    onOpenApp: onOpenMainWindow
                )
            } else {
                PreRecordingView(
                    audioEngine: audioEngine,
                    deviceManager: deviceManager,
                    selectedMeetingType: $selectedMeetingType,
                    onStartRecording: onStartRecording,
                    onOpenApp: onOpenMainWindow
                )
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct PreRecordingView: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedMeetingType: MeetingType

    let onStartRecording: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // App name
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text("wrec")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }

            Divider()

            // Meeting type
            VStack(alignment: .leading, spacing: 4) {
                Text("Meeting Type")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedMeetingType) {
                    ForEach(MeetingType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .labelsHidden()
            }

            // Device selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: Binding(
                    get: { deviceManager.selectedInputDevice?.uniqueID ?? "" },
                    set: { deviceManager.selectDevice(byUID: $0) }
                )) {
                    Text("System Default").tag("")
                    ForEach(deviceManager.availableInputDevices, id: \.uniqueID) { audioDevice in
                        Text(audioDevice.localizedName).tag(audioDevice.uniqueID)
                    }
                }
                .labelsHidden()
            }

            // Start button
            Button(action: onStartRecording) {
                HStack {
                    Image(systemName: "record.circle")
                    Text("Start Recording")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Divider()

            // Open app button
            Button(action: onOpenApp) {
                HStack {
                    Image(systemName: "rectangle.on.rectangle")
                    Text("Open wrec")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioCaptureEngine())
        .environmentObject(DeviceManager())
        .environmentObject(MeetingScheduler())
        .modelContainer(for: [Meeting.self, TranscriptSegment.self], inMemory: true)
}
