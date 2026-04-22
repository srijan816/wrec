import SwiftUI

struct MenuBarView: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    @ObservedObject var deviceManager: DeviceManager
    @Binding var selectedMeetingType: MeetingType
    @Binding var isRecording: Bool

    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onToggleMic: () -> Void
    let onToggleSystem: () -> Void
    let onAddNote: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RecordingControlsView(
                audioEngine: audioEngine,
                selectedMeetingType: $selectedMeetingType,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onToggleMic: onToggleMic,
                onToggleSystem: onToggleSystem,
                onAddNote: onAddNote,
                onOpenApp: onOpenApp
            )
        }
        .frame(width: 280)
    }
}

struct MenuBarIcon: View {
    let isRecording: Bool
    let isProcessing: Bool

    var body: some View {
        ZStack {
            if isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 8, y: -8)
            }

            if isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .offset(x: 8, y: -8)
            }

            Image(systemName: "waveform")
                .font(.system(size: 16, weight: .medium))
        }
    }
}
