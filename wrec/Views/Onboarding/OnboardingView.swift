import SwiftUI
import AVFoundation
import ScreenCaptureKit
import UserNotifications

struct OnboardingView: View {
    @Binding var isCompleted: Bool

    @State private var currentStep = 0
    @State private var microphoneGranted = false
    @State private var screenRecordingGranted = false
    @State private var notificationsGranted = false

    @State private var isDownloadingModels = false
    @State private var downloadProgress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding()

            Divider()

            // Content
            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                permissionsStep.tag(1)
                modelDownloadStep.tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 500, height: 400)
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Welcome to wrec")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Record, transcribe, and analyze your meetings — entirely on your device. No cloud, no subscriptions, no data leaves your Mac.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button("Get Started") {
                withAnimation {
                    currentStep = 1
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            Text("Permissions Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("wrec needs a few permissions to work properly.")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Record your voice during meetings",
                    isGranted: microphoneGranted,
                    action: requestMicrophonePermission
                )

                PermissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen & System Audio",
                    description: "Capture audio from Zoom, Meet, Teams, and more",
                    isGranted: screenRecordingGranted,
                    action: requestScreenRecordingPermission
                )

                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Remind you before meetings start",
                    isGranted: notificationsGranted,
                    action: requestNotificationPermission
                )
            }
            .padding()

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation {
                        currentStep = 0
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(microphoneGranted && screenRecordingGranted ? "Continue" : "Skip for Now") {
                    withAnimation {
                        currentStep = 2
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var modelDownloadStep: some View {
        VStack(spacing: 24) {
            Text("Downloading AI Models")
                .font(.title2)
                .fontWeight(.semibold)

            if isDownloadingModels {
                VStack(spacing: 16) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(.linear)

                    Text("Downloading models... \(Int(downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text("These models run entirely on your Mac's Neural Engine and GPU. No internet needed after this.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    ModelDownloadRow(name: "Parakeet TDT", size: "~1.2 GB", isDownloaded: false)
                    ModelDownloadRow(name: "pyannote Segmentation", size: "~5.7 MB", isDownloaded: false)
                    ModelDownloadRow(name: "WeSpeaker ResNet34", size: "~25 MB", isDownloaded: false)
                    ModelDownloadRow(name: "Silero VAD", size: "~1.2 MB", isDownloaded: false)
                }
                .padding()
            }

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation {
                        currentStep = 1
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Start Download") {
                    startModelDownload()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloadingModels)

                Button("Complete Setup") {
                    isCompleted = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloadingModels)
            }
        }
        .padding()
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphoneGranted = granted
            }
        }
    }

    private func requestScreenRecordingPermission() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                await MainActor.run {
                    screenRecordingGranted = true
                }
            } catch {
                await MainActor.run {
                    screenRecordingGranted = false
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
            }
        }
    }

    private func startModelDownload() {
        isDownloadingModels = true

        // Simulate download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            downloadProgress += 0.02
            if downloadProgress >= 1.0 {
                timer.invalidate()
                isDownloadingModels = false
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

struct ModelDownloadRow: View {
    let name: String
    let size: String
    let isDownloaded: Bool

    var body: some View {
        HStack {
            Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                .foregroundColor(isDownloaded ? .green : .secondary)

            Text(name)

            Spacer()

            Text(size)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
