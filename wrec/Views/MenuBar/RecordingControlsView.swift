import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    @Binding var selectedMeetingType: MeetingType
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onToggleMic: () -> Void
    let onToggleSystem: () -> Void
    let onAddNote: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if audioEngine.recordingState == .recording {
                recordingView
            } else {
                preRecordingView
            }
        }
        .padding()
    }

    private var preRecordingView: some View {
        VStack(spacing: 16) {
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

            Picker("Meeting Type", selection: $selectedMeetingType) {
                ForEach(MeetingType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)

            Button(action: onOpenApp) {
                Text("Open wrec")
                    .font(.subheadline)
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 16) {
            // Recording timer
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(pulsing ? 1 : 0.3)

                Text(formatDuration(audioEngine.recordingDuration))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
            }

            // Meeting type badge
            Text(selectedMeetingType.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)

            // Stream toggles
            HStack(spacing: 20) {
                streamToggle(
                    icon: "mic.fill",
                    label: "Mic",
                    isMuted: audioEngine.isMicMuted,
                    action: onToggleMic
                )

                streamToggle(
                    icon: "speaker.wave.2.fill",
                    label: "System",
                    isMuted: audioEngine.isSystemMuted,
                    action: onToggleSystem
                )
            }

            // Live transcript preview
            if !audioEngine.liveTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Transcript")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(audioEngine.liveTranscript)
                        .font(.caption)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onAddNote) {
                    Image(systemName: "note.text")
                        .font(.title3)
                }
                .buttonStyle(.bordered)

                Button(action: onStopRecording) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }

            Button(action: onOpenApp) {
                Text("Open wrec")
                    .font(.caption)
            }
        }
    }

    private func streamToggle(icon: String, label: String, isMuted: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isMuted ? .red : .green)

                Text(label)
                    .font(.caption)
                    .foregroundColor(isMuted ? .red : .primary)
            }
            .padding(8)
            .background(isMuted ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    @State private var pulsing = true

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulsing = true
        }
    }
}
