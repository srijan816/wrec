import SwiftUI
import AVFoundation

struct AudioPlayerTabView: View {
    @Bindable var meeting: Meeting

    @State private var isPlaying = false
    @State private var playbackPosition: Double = 0
    @State private var playbackDuration: Double = 0
    @State private var playbackSpeed: Double = 1.0
    @State private var selectedAudioSource: AudioSource = .combined

    var body: some View {
        VStack(spacing: 20) {
            // Audio source selector
            Picker("Audio Source", selection: $selectedAudioSource) {
                Text("Combined").tag(AudioSource.combined)
                Text("Microphone").tag(AudioSource.microphone)
                Text("System").tag(AudioSource.system)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Waveform
            WaveformView(
                samples: waveformSamples,
                speakerRegions: speakerRegions
            )
            .padding(.horizontal)

            // Playback controls
            playbackControlsView

            Spacer()

            // Speaker legend
            speakerLegendView
        }
        .padding()
        .onAppear {
            setupAudioPlayer()
        }
    }

    private var playbackControlsView: some View {
        VStack(spacing: 12) {
            // Progress slider
            HStack {
                Text(formatTime(playbackPosition))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50)

                Slider(value: $playbackPosition, in: 0...max(playbackDuration, 1))
                    .onChange(of: playbackPosition) { _, newValue in
                        seek(to: newValue)
                    }

                Text(formatTime(playbackDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50)
            }

            // Control buttons
            HStack(spacing: 24) {
                Button(action: { playbackSpeed = max(0.5, playbackSpeed - 0.25) }) {
                    Text("\(playbackSpeed, specifier: "%.2f")x")
                        .font(.caption)
                        .frame(width: 50)
                }
                .buttonStyle(.bordered)

                Button(action: skipBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .buttonStyle(.bordered)

                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                }
                .buttonStyle(.plain)

                Button(action: skipForward) {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var speakerLegendView: some View {
        HStack(spacing: 16) {
            ForEach(meeting.speakers.sorted { $0.speakerId < $1.speakerId }) { speaker in
                SpeakerBadge(
                    label: speaker.label,
                    isMe: speaker.isMe
                )
            }
        }
    }

    private var waveformSamples: [Float] {
        // Placeholder - would load actual audio data
        (0..<100).map { _ in Float.random(in: 0.1...0.9) }
    }

    private var speakerRegions: [(start: Double, end: Double, color: Color)] {
        meeting.segments.map { segment in
            let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
            let color = segment.speakerLabel == "Me" ? Color.blue : colors[segment.speakerId % colors.count]
            return (segment.startTime, segment.endTime, color)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func setupAudioPlayer() {
        guard let combinedPath = meeting.combinedAudioPath else { return }
        // Setup AVAudioPlayer here
    }

    private func togglePlayback() {
        isPlaying.toggle()
    }

    private func skipBackward() {
        playbackPosition = max(0, playbackPosition - 15)
    }

    private func skipForward() {
        playbackPosition = min(playbackDuration, playbackPosition + 15)
    }

    private func seek(to position: Double) {
        // Seek audio player to position
    }
}

enum AudioSource {
    case combined
    case microphone
    case system
}
