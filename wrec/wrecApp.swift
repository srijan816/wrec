import SwiftUI
import SwiftData
import AppKit
import Combine

@main
struct wrecApp: App {
    @StateObject private var audioEngine = AudioCaptureEngine()
    @StateObject private var deviceManager = DeviceManager()
    @StateObject private var meetingScheduler = MeetingScheduler()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("selectedMeetingType") private var selectedMeetingTypeRaw = MeetingType.other.rawValue

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meeting.self,
            TranscriptSegment.self,
            MeetingNote.self,
            Speaker.self,
            ScheduledMeeting.self,
            MuteEvent.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(deviceManager)
                .environmentObject(meetingScheduler)
                .sheet(isPresented: .constant(!hasCompletedOnboarding)) {
                    OnboardingView(isCompleted: $hasCompletedOnboarding)
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Meeting") {
                    // Start new meeting
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    init() {
        setupMenuBar()
        setupNotifications()
    }

    private func setupMenuBar() {
        NSApplication.shared.setActivationPolicy(.accessory)
        MenuBarManager.shared.setupMenuBar()
    }

    private func setupNotifications() {
        NotificationManager.shared.setupNotificationCategories()
    }
}

final class MenuBarManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = MenuBarManager()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    @Published var isRecording = false

    private override init() {
        super.init()
    }

    func setupMenuBar() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "wrec")
        }
        statusItem.menu = createMenu()
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "wrec", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let startItem = NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "r")
        startItem.target = self
        menu.addItem(startItem)

        let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "r")
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open wrec", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit wrec", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func startRecording() {
        // Post notification to start recording
        NotificationCenter.default.post(name: .startRecording, object: nil)
    }

    @objc private func stopRecording() {
        NotificationCenter.default.post(name: .stopRecording, object: nil)
    }

    @objc private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
    static let stopRecording = Notification.Name("stopRecording")
}
