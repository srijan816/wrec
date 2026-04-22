import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("defaultMicrophoneUID") private var defaultMicrophoneUID = ""
    @AppStorage("autoTranscribe") private var autoTranscribe = true
    @AppStorage("autoDiarize") private var autoDiarize = true
    @AppStorage("maxSpeakers") private var maxSpeakers = 0
    @AppStorage("startReminderEnabled") private var startReminderEnabled = true
    @AppStorage("endReminderEnabled") private var endReminderEnabled = true
    @AppStorage("reminderOffset") private var reminderOffset = 60.0
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 0
    @AppStorage("minimaxApiKey") private var minimaxApiKey = ""

    @State private var availableDevices: [AVCaptureDevice] = []

    var body: some View {
        TabView {
            audioSettingsTab
            transcriptionSettingsTab
            diarizationSettingsTab
            notificationSettingsTab
            storageSettingsTab
            aiSettingsTab
        }
        .frame(width: 500, height: 400)
        .onAppear {
            refreshDevices()
        }
    }

    private var audioSettingsTab: some View {
        Form {
            Section("Microphone") {
                Picker("Default Device", selection: $defaultMicrophoneUID) {
                    Text("System Default").tag("")
                    ForEach(availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
            }

            Section("Audio Quality") {
                Text("16kHz mono (recommended)")
                    .foregroundColor(.secondary)
                Text("44.1kHz stereo (archival)")
                    .foregroundColor(.secondary)
            }
        }
        .tabItem {
            Label("Audio", systemImage: "speaker.wave.2")
        }
    }

    private var transcriptionSettingsTab: some View {
        Form {
            Section("Transcription") {
                Toggle("Auto-transcribe after recording", isOn: $autoTranscribe)

                Picker("Model", selection: .constant("Parakeet TDT 0.6b-v3")) {
                    Text("Parakeet TDT 0.6b-v3").tag("Parakeet TDT 0.6b-v3")
                }

                HStack {
                    Text("Language")
                    Spacer()
                    Text("English (Parakeet is English-only)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .tabItem {
            Label("Transcription", systemImage: "text.alignleft")
        }
    }

    private var diarizationSettingsTab: some View {
        Form {
            Section("Diarization") {
                Toggle("Auto-diarize after recording", isOn: $autoDiarize)

                Picker("Max Speakers", selection: $maxSpeakers) {
                    Text("Auto-detect").tag(0)
                    ForEach(2...10, id: \.self) { count in
                        Text("\(count) speakers").tag(count)
                    }
                }
            }

            Section("Advanced") {
                HStack {
                    Text("Clustering Threshold")
                    Spacer()
                    Slider(value: .constant(0.5), in: 0...1)
                        .frame(width: 150)
                    Text("0.5")
                        .foregroundColor(.secondary)
                }
            }
        }
        .tabItem {
            Label("Diarization", systemImage: "person.2")
        }
    }

    private var notificationSettingsTab: some View {
        Form {
            Section("Reminders") {
                Toggle("Start reminder", isOn: $startReminderEnabled)
                Toggle("End reminder", isOn: $endReminderEnabled)

                HStack {
                    Text("Reminder offset")
                    Spacer()
                    Picker("", selection: $reminderOffset) {
                        Text("1 min").tag(60.0)
                        Text("5 min").tag(300.0)
                        Text("10 min").tag(600.0)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .tabItem {
            Label("Notifications", systemImage: "bell")
        }
    }

    private var storageSettingsTab: some View {
        Form {
            Section("Storage") {
                HStack {
                    Text("Data Location")
                    Spacer()
                    Text("~/Library/Application Support/wrec")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Picker("Auto-delete audio after", selection: $autoDeleteDays) {
                    Text("Never").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            }

            Section("Usage") {
                HStack {
                    Text("Total Storage Used")
                    Spacer()
                    Text("Calculating...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .tabItem {
            Label("Storage", systemImage: "externaldrive")
        }
    }

    private var aiSettingsTab: some View {
        Form {
            Section("MiniMax API") {
                SecureField("API Key", text: $minimaxApiKey)

                Text("Get your API key from minimax.chat")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Analysis") {
                Text("AI analysis uses the MiniMax M2.7 API for post-meeting summarization and insight extraction.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .tabItem {
            Label("AI Analysis", systemImage: "brain")
        }
    }

    private func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        availableDevices = discoverySession.devices
    }
}
