Complete PRD & Claude Code Prompt: "wrec" — macOS Meeting Transcription & Diarization App

PREAMBLE FOR CLAUDE CODE

You are building a native macOS application called "wrec" — a system-level meeting 
transcription and diarization tool. This is a FULL production app, not an MVP. Read this 
entire PRD before writing any code. Ask clarifying questions if anything is ambiguous. 
Do not skip features or defer them. Every section below must be implemented.

Tech stack:
- Swift 6 / SwiftUI / macOS 15+ (Sequoia)
- ScreenCaptureKit for system audio capture
- AVAudioEngine for microphone/AirPods input
- speech-swift library (https://github.com/soniqo/speech-swift) for:
  - Parakeet TDT 0.6b-v3 via CoreML (transcription)
  - Pyannote segmentation 3.0 + WeSpeaker ResNet34 via MLX (speaker diarization)
  - Silero VAD v5 via MLX (voice activity detection for streaming)
- SwiftData for local persistent storage
- MiniMax M2.7 API (OpenAI-compatible) for post-meeting AI analysis (future phase, stub the interface now)
- No Electron, no Python runtime, no web wrapper — pure native Swift

The user runs this on an M1 Pro MacBook and an M4 Mac Mini. Both have 16GB+ RAM.

1. APP ARCHITECTURE & PLATFORM DECISION

Why a Native macOS SwiftUI App

This must be a native macOS menu bar app with a companion window for the following reasons:

ScreenCaptureKit is the only reliable way to capture system audio on macOS without third-party kernel extensions like BlackHole. It's an Apple-native API available on macOS 13+ that captures system audio output directly — including audio from Zoom, Google Meet, Teams, FaceTime, browser tabs, or any app producing sound. ScreenCaptureKit requires the "Screen & System Audio Recording" permission, which only native apps can reliably request and hold. Python scripts and Electron apps fight with TCC permission resets constantly.

AVAudioEngine provides native access to all audio input devices — built-in mic, external mic, AirPods, or any connected Bluetooth device. It gives you low-latency access to raw PCM buffers with full control over sample rate and format.

speech-swift is a native Swift package that provides Parakeet TDT (CoreML/Neural Engine) and the full diarization pipeline (pyannote segmentation + WeSpeaker embeddings + agglomerative clustering) all running natively on Apple Silicon via MLX. No Python, no PyTorch, no conda. 32 MB total for the diarization models, 1.2 GB for Parakeet. This eliminates the need to bridge to Python for pyannote.

SwiftData provides local-first persistent storage that syncs naturally with the SwiftUI lifecycle.

The app lives primarily in the menu bar (always accessible, low-friction start/stop recording) but opens a full window for meeting management, transcript review, notes, and settings.

2. AUDIO CAPTURE ENGINE

2.1 Audio Sources — Three Simultaneous Streams

The app captures up to three independent audio streams simultaneously, recorded as separate channels/files so they can be independently controlled, transcribed, and attributed during diarization:

Stream 1: Microphone Input (Your Voice)
- Captured via AVAudioEngine with an input node tap
- Device selection: the user picks which input device to use (built-in mic, external mic, AirPods mic, etc.) from a dropdown in the recording panel
- Must support switching devices mid-session (e.g., plug in AirPods after starting)
- Can be muted/unmuted mid-session without stopping the recording. When muted, the stream records silence (zero-fill) to maintain time alignment, but the audio is not fed to the transcription engine
- This stream is labeled "Me" in the transcript — we know this is always the user

Stream 2: System Audio (Their Voice)
- Captured via ScreenCaptureKit audio-only stream
- Use SCStreamConfiguration with capturesAudio = true and excludesCurrentProcessApp = true (so our own app's UI sounds are excluded)
- On macOS 15+, you can use SCContentFilter for application-specific audio, but for meetings, capturing all system audio is the right default (Zoom, Meet, etc. all output via system audio)
- This stream represents "everyone else on the call"
- Can be independently muted/unmuted (e.g., if the user wants to listen to music on a different app while keeping the meeting recording going — they'd unmute system audio but mute mic)
- The "Screen & System Audio Recording" permission is required. The app must handle the permission flow gracefully with a first-run setup screen

Stream 3: Combined/Mixed (for Diarization)
- A real-time mix of Stream 1 and Stream 2 at the correct relative levels
- This combined stream is what gets fed to the diarization pipeline post-recording, because pyannote needs to hear all speakers in a single audio track to segment and cluster them
- Also used as the archival recording (the full meeting audio)

2.2 Audio Format & Recording

All streams record at 16kHz mono Float32 — this is the native sample rate for both Parakeet TDT and the pyannote/WeSpeaker pipeline. If the hardware input is at a different rate (typically 44.1kHz or 48kHz), use AVAudioConverter to downsample in real-time.

Audio files are saved as WAV (PCM Float32, 16kHz, mono) in the app's data directory:

~/Library/Application Support/wrec/
├── meetings/
│   ├── 2026-04-22_1430_marketing-meeting/
│   │   ├── mic.wav          # Stream 1: microphone only
│   │   ├── system.wav       # Stream 2: system audio only
│   │   ├── combined.wav     # Stream 3: mixed audio
│   │   ├── transcript.json  # Timestamped transcript with speaker labels
│   │   ├── diarization.json # Raw diarization output
│   │   ├── metadata.json    # Meeting metadata (type, notes, timestamps, etc.)
│   │   └── notes.json       # User's freeform notes with timestamps

2.3 Mute/Unmute Behavior

When a stream is muted:
- The audio buffer continues recording (writing silence/zeros) to maintain time synchronization across all three streams
- The transcription engine stops receiving that stream's audio
- The UI clearly indicates the muted state with a visual indicator (crossed-out mic icon, crossed-out speaker icon)
- A log entry is created in metadata.json noting the mute/unmute event and timestamp for reference

2.4 Device Hot-Swapping

If the user connects AirPods mid-session, the app should detect the new audio device and optionally switch to it. Implement via AVAudioSession.routeChangeNotification observation. Show a non-intrusive notification: "AirPods connected. Switch microphone? [Yes] [No]" — if Yes, seamlessly switch the input tap to the new device without interrupting the recording.

3. REAL-TIME TRANSCRIPTION ENGINE

3.1 Streaming Transcription with Parakeet TDT

Use the ParakeetStreamingASR module from speech-swift for real-time transcription during the meeting. The streaming model (Parakeet-EOU-120M) processes audio in chunks and emits partial results, finalizing when it detects an end-of-utterance.

import ParakeetStreamingASR

let model = try await ParakeetStreamingASRModel.fromPretrained()

// Feed audio chunks from the AVAudioEngine tap
for await partial in model.transcribeStream(audio: audioChunk, sampleRate: 16000) {
    if partial.isFinal {
        // Append to transcript with timestamp
        appendToLiveTranscript(text: partial.text, timestamp: currentTime)
    } else {
        // Update the "currently speaking" line in the UI
        updatePartialTranscript(text: partial.text)
    }
}

During the live meeting, transcription runs on the combined audio stream (Stream 3) so that both the user's voice and the remote participants' voices are transcribed in real-time. Live speaker attribution during the meeting is approximate — we can use a simple heuristic: if the audio energy is primarily coming from the mic stream, label it "Me"; if primarily from system audio, label it "Remote." This is good enough for live display.

3.2 Post-Meeting High-Quality Transcription

After the meeting ends, run a batch transcription pass using the full Parakeet TDT 0.6b-v3 model (higher accuracy than the streaming model) on the combined audio:

import ParakeetASR

let model = try await ParakeetASRModel.fromPretrained()
let result = try model.transcribeAudio(combinedAudioSamples, sampleRate: 16000)
// result contains sentences with word-level timestamps

This produces the definitive, high-accuracy transcript with word-level timestamps that gets stored in transcript.json.

4. SPEAKER DIARIZATION ENGINE

4.1 Post-Meeting Diarization with speech-swift

After the meeting ends, run the full diarization pipeline on the combined audio:

import SpeechVAD

let pipeline = try await DiarizationPipeline.fromPretrained()
// Downloads pyannote segmentation (5.7 MB) + WeSpeaker ResNet34 (25 MB) on first run

let diarization = pipeline.diarize(
    audio: combinedAudioSamples,
    sampleRate: 16000
)

for segment in diarization.segments {
    // segment.speakerId: Int (0-indexed)
    // segment.startTime: Double (seconds)
    // segment.endTime: Double (seconds)
    print("Speaker \(segment.speakerId): [\(segment.startTime)s - \(segment.endTime)s]")
}
print("Detected \(diarization.numSpeakers) speakers")

4.2 Enhancing Diarization with Channel Separation

Because we have separate mic and system audio streams, we can significantly improve speaker attribution beyond what blind diarization provides:

Step 1: Run diarization on the combined audio to get speaker segments and embeddings.

Step 2: Generate a speaker embedding from the mic-only audio (Stream 1) using WeSpeaker:

let embedder = try await WeSpeakerModel.fromPretrained()
let myEmbedding = embedder.embed(audio: micOnlyAudio, sampleRate: 16000)

Step 3: Compare myEmbedding against each detected speaker cluster's centroid using cosine similarity. The cluster with the highest similarity to the mic audio is "Me." All other clusters are remote participants.

Step 4: For remote participants, the diarization output gives us Speaker 1, Speaker 2, etc. We label them as "Remote Speaker A", "Remote Speaker B", etc. The user can optionally rename these post-meeting.

This two-stage approach (blind diarization + channel-aware speaker identification) gives much better results than either approach alone.

4.3 Merging Transcription + Diarization

The final output aligns the Parakeet transcript (which has word-level timestamps) with the diarization segments (which have speaker-labeled time ranges). For each word or sentence in the transcript, find which diarization segment overlaps it, and assign the speaker label:

struct AttributedSegment: Codable {
    let speakerLabel: String   // "Me", "Remote Speaker A", etc.
    let speakerId: Int
    let startTime: Double
    let endTime: Double
    let text: String
}

Store the merged result in transcript.json as an array of AttributedSegment.

4.4 Processing Timeline

The diarization pipeline processes offline after the meeting ends. On an M4 Mac Mini, expect approximately:

- 30-minute meeting: 30-60 seconds for batch transcription + 20-40 seconds for diarization = ~1-2 minutes total
- 60-minute meeting: 60-90 seconds for transcription + 40-80 seconds for diarization = ~2-3 minutes total

Show a progress indicator: "Processing meeting... Transcribing (Step 1/3) → Diarizing (Step 2/3) → Merging (Step 3/3)"

5. DATA MODEL (SwiftData)

import SwiftData

// MARK: - Meeting Types
enum MeetingType: String, Codable, CaseIterable {
    case marketingMeeting = "Marketing Meeting"
    case lessonPlanMeeting = "Lesson Plan Meeting"
    case studentInterview = "Student Interview"
    case parentTeacherMeeting = "Parent Teacher Meeting"
    case parentIntroductoryCall = "Parent Introductory Call"
    case classSession = "Class"
    case spar = "Spar"
    case other = "Other"
}

// MARK: - Meeting
@Model
final class Meeting {
    @Attribute(.unique) var id: UUID
    var title: String                          // User-editable title
    var meetingType: MeetingType               // Pre-selected or post-selected
    var scheduledStartTime: Date?              // If scheduled in advance
    var scheduledEndTime: Date?                // If scheduled in advance
    var actualStartTime: Date?                 // When recording actually started
    var actualEndTime: Date?                   // When recording actually stopped
    var createdAt: Date
    var updatedAt: Date
    
    // Audio file paths (relative to meeting directory)
    var micAudioPath: String?
    var systemAudioPath: String?
    var combinedAudioPath: String?
    
    // Processing state
    var transcriptionStatus: ProcessingStatus  // .pending, .inProgress, .completed, .failed
    var diarizationStatus: ProcessingStatus
    
    // Relationships
    @Relationship(deleteRule: .cascade) var segments: [TranscriptSegment]
    @Relationship(deleteRule: .cascade) var notes: [MeetingNote]
    @Relationship(deleteRule: .cascade) var muteEvents: [MuteEvent]
    @Relationship(deleteRule: .cascade) var speakers: [Speaker]
    
    // For future MiniMax M2.7 AI analysis
    var aiAnalysisStatus: ProcessingStatus
    var aiAnalysisResult: String?              // JSON string of analysis output
}

enum ProcessingStatus: String, Codable {
    case pending
    case inProgress
    case completed
    case failed
}

// MARK: - Transcript Segment
@Model
final class TranscriptSegment {
    var id: UUID
    var speakerLabel: String                   // "Me", "Remote Speaker A", etc.
    var speakerId: Int                         // Numeric ID from diarization
    var startTime: Double                      // Seconds from meeting start
    var endTime: Double
    var text: String
    var meeting: Meeting?
}

// MARK: - Speaker
@Model
final class Speaker {
    var id: UUID
    var speakerId: Int                         // From diarization (0-indexed)
    var label: String                          // "Me", "Remote Speaker A", or user-renamed
    var isMe: Bool                             // Auto-detected via channel separation
    var meeting: Meeting?
}

// MARK: - Meeting Note
@Model
final class MeetingNote {
    var id: UUID
    var timestamp: Date                        // When the note was written
    var meetingTimestamp: Double?               // Seconds from meeting start (if during meeting)
    var phase: NotePhase                       // .before, .during, .after
    var content: String
    var meeting: Meeting?
}

enum NotePhase: String, Codable {
    case before
    case during
    case after
}

// MARK: - Mute Event
@Model
final class MuteEvent {
    var id: UUID
    var timestamp: Double                      // Seconds from meeting start
    var stream: AudioStream                    // .microphone or .systemAudio
    var action: MuteAction                     // .muted or .unmuted
    var meeting: Meeting?
}

enum AudioStream: String, Codable {
    case microphone
    case systemAudio
}

enum MuteAction: String, Codable {
    case muted
    case unmuted
}

// MARK: - Scheduled Meeting (for reminders)
@Model
final class ScheduledMeeting {
    var id: UUID
    var title: String
    var meetingType: MeetingType
    var scheduledStart: Date
    var scheduledEnd: Date
    var preNotes: String                       // Context notes added before the meeting
    var reminderFired: Bool                    // Has the 1-min-early reminder been sent?
    var endReminderFired: Bool                 // Has the 1-min-late reminder been sent?
    var linkedMeeting: Meeting?                // Linked to actual Meeting once recording starts
}

6. USER INTERFACE

6.1 Menu Bar Component

The app installs a menu bar icon (waveform icon) that is always present when the app is running. Clicking it shows a dropdown panel:

When Not Recording:
- "Start Recording" button (prominent, green)
- Dropdown to select meeting type (defaults to last used)
- Quick-select input device dropdown
- "Open wrec" to open the full window
- "Upcoming: [Meeting Title] in 14 min" (if a scheduled meeting is approaching)

When Recording:
- Recording timer (00:12:34) with a red pulsing dot
- Meeting type badge
- Mic toggle button (green = active, red = muted) with label "Mic"
- System audio toggle button (green = active, red = muted) with label "System"
- Live transcript preview (last 2-3 lines, scrolling)
- "Add Note" quick button (opens a small text field)
- "Stop Recording" button (red)
- "Open wrec" to open the full window for more detail

6.2 Main Window — Navigation

Use NavigationSplitView with a three-column layout:

Sidebar (Column 1):
- "All Meetings" with total count
- Sections grouped by MeetingType, each showing count
  - "Marketing Meeting (12)"
  - "Lesson Plan Meeting (8)"
  - etc.
- "Scheduled" section showing upcoming scheduled meetings
- "Settings" at the bottom

Meeting List (Column 2):
- Filtered by the selected category
- Each row shows: Title, Date/Time, Duration, Processing status badge (if still processing)
- Sorted by date, newest first
- Search bar at top for full-text search across titles, notes, and transcript text

Detail (Column 3):
- The full meeting view (see 6.3)

6.3 Meeting Detail View

Header Section:
- Meeting title (editable inline)
- Meeting type (dropdown, changeable post-meeting)
- Date and time (auto-populated from actual start time)
- Duration
- Processing status badges (Transcription: Done ✓, Diarization: Done ✓, AI Analysis: Pending)
- "Re-process" button (re-runs transcription and diarization)
- "Export" button (export transcript as .txt, .srt, .json, or .pdf)

Tabbed Content Area:

Tab 1: Transcript
- The full attributed transcript displayed as a conversation:
  [00:00:12] Me: 
  Good morning everyone, let's start with the agenda for today.
  
  [00:00:18] Remote Speaker A: 
  Sure, I wanted to discuss the Q3 marketing budget first.
  
  [00:00:25] Me: 
  That works. Let me pull up the numbers.
- Each speaker has a distinct color
- Speaker labels are editable (click to rename "Remote Speaker A" to "Sarah")
- Clicking any timestamp jumps to that point in the audio player
- Search within transcript

Tab 2: Audio Player
- Waveform visualization of the combined audio
- Play/pause, scrub, speed control (0.5x, 1x, 1.5x, 2x)
- Speaker-colored regions overlaid on the waveform
- Option to play mic-only, system-only, or combined

Tab 3: Notes
- All notes displayed chronologically with their timestamps and phase labels
- "Before Meeting" section, "During Meeting" section, "After Meeting" section
- Add new note button (phase auto-detected based on meeting state)
- Each note shows both the clock time and the meeting-relative timestamp

Tab 4: AI Analysis (Stub for now)
- Placeholder: "AI analysis will appear here after processing with MiniMax M2.7"
- Dropdown to select analysis type based on meeting type
- "Run Analysis" button (disabled with tooltip: "Coming soon")

6.4 Schedule Meeting View

Accessible from the sidebar "Scheduled" section or via "Schedule Meeting" button.

Fields:
- Title (text field)
- Meeting Type (dropdown)
- Start Date/Time (date picker)
- End Date/Time (date picker)
- Pre-Meeting Notes (text area — for context you want to remember)
- "Save" button

Reminder Behavior:
- 1 minute before scheduled start: macOS notification: "wrec: '[Title]' starts in 1 minute. Ready to record?" with action buttons: [Start Recording Now] [Dismiss]
- 1 minute after scheduled end: macOS notification: "wrec: '[Title]' was scheduled to end 1 minute ago. Stop recording?" with action buttons: [Stop Recording] [Keep Going]
- Reminders use UNUserNotificationCenter with actionable notifications

When the user starts recording for a scheduled meeting, the ScheduledMeeting is linked to the actual Meeting record, and all pre-meeting notes are carried over.

7. PERMISSIONS & FIRST-RUN SETUP

7.1 Required Permissions

The app needs:
1. Microphone Access — requested via AVCaptureDevice.requestAccess(for: .audio)
2. Screen & System Audio Recording — requested when initializing SCShareableContent. On macOS 15+, this is the "Screen & System Audio Recording" toggle in System Settings → Privacy & Security
3. Notifications — requested via UNUserNotificationCenter.requestAuthorization

7.2 First-Run Onboarding

On first launch, show a 3-step onboarding window:

Step 1: Welcome
"wrec records, transcribes, and analyzes your meetings — entirely on your device. No cloud, no subscriptions, no data leaves your Mac."

Step 2: Permissions
"We need two permissions to work:"
- [Grant Microphone Access] button → triggers AVCaptureDevice permission dialog
- [Grant System Audio Access] button → triggers ScreenCaptureKit permission flow
- [Grant Notification Access] button → triggers notification permission dialog
Show green checkmarks as each is granted.

Step 3: Model Download
"Downloading AI models for on-device transcription and speaker recognition..."
- Progress bar for Parakeet TDT 0.6b-v3 (~1.2 GB)
- Progress bar for pyannote segmentation (~5.7 MB)
- Progress bar for WeSpeaker ResNet34 (~25 MB)
- Progress bar for Silero VAD (~1.2 MB)
"These models run entirely on your Mac's Neural Engine and GPU. No internet needed after this."

Step 4: Ready
"You're all set! wrec is now in your menu bar. Click the waveform icon to start recording."

8. RECORDING LIFECYCLE

State Machine

IDLE → SCHEDULED → PRE_MEETING → RECORDING → POST_PROCESSING → COMPLETED
                                     ↕
                                  PAUSED (optional)

IDLE: No active or upcoming meeting. Menu bar shows default icon.

SCHEDULED: A meeting is scheduled. Menu bar shows a clock badge. 1-min-early notification fires.

PRE_MEETING: User has opened the recording panel but hasn't started yet. They can write pre-meeting notes, select meeting type, choose audio devices.

RECORDING: Audio is being captured. Live transcription is running. User can mute/unmute streams, add notes, see live transcript. Menu bar shows red recording dot.

POST_PROCESSING: Recording stopped. Batch transcription, diarization, and merging are running. Progress shown in the detail view. Menu bar shows a processing spinner.

COMPLETED: All processing done. Full attributed transcript available. 1-min-late end reminder fires if applicable.

9. FILE MANAGEMENT & EXPORT

9.1 Storage

All meeting data lives in ~/Library/Application Support/wrec/meetings/. Each meeting gets its own directory named with the pattern {date}{time}{slugified-title}.

9.2 Export Options

From the meeting detail view, the user can export:

- Plain Text (.txt): Speaker-labeled transcript with timestamps
- SRT (.srt): Subtitle format for video editing
- JSON (.json): Full structured data (segments, speakers, notes, metadata)
- Audio (.wav): The combined recording
- PDF (.pdf): Formatted transcript with meeting metadata header (use a simple PDF generation approach — no heavy frameworks)

9.3 Cleanup

In Settings, allow the user to:
- Set auto-delete policy: "Delete audio files after X days" (keep transcripts and metadata)
- Manually delete individual meetings
- "Export All" to a chosen directory

10. SETTINGS

Audio Settings:
- Default microphone device
- Default system audio behavior (capture all apps vs. specific app)
- Audio quality (16kHz is default and recommended; option for 44.1kHz archival recording)

Transcription Settings:
- Model selection (Parakeet TDT 0.6b-v3 is default)
- Auto-transcribe after recording (on/off, default on)
- Language (English is default; show warning that Parakeet is English-only)

Diarization Settings:
- Auto-diarize after recording (on/off, default on)
- Maximum expected speakers (default: auto-detect, or set 2-10)
- Clustering threshold (advanced, default 0.5)

Meeting Types:
- Show default types
- Allow user to add custom meeting types
- Allow user to reorder or hide types

Notifications:
- Enable/disable start reminder
- Enable/disable end reminder  
- Reminder offset (default: 1 minute, configurable)

Storage:
- Data directory location
- Auto-cleanup settings
- Storage usage display

AI Analysis (Future):
- MiniMax API key field
- Model selection
- Per-meeting-type prompt templates (stub UI, functional later)

11. SWIFT PACKAGE DEPENDENCIES

// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/soniqo/speech-swift", branch: "main"),
]

// Targets use these products:
.product(name: "ParakeetASR", package: "speech-swift"),           // Batch transcription
.product(name: "ParakeetStreamingASR", package: "speech-swift"),  // Live streaming transcription
.product(name: "SpeechVAD", package: "speech-swift"),             // VAD + Diarization + Speaker Embeddings
.product(name: "SpeechUI", package: "speech-swift"),              // Optional SwiftUI transcript view
.product(name: "AudioCommon", package: "speech-swift"),           // Shared protocols, WAV I/O

12. PROJECT STRUCTURE

wrec/
├── wrecApp.swift                    # App entry point, menu bar setup
├── Info.plist                             # Privacy usage descriptions
├── wrec.entitlements                # com.apple.security.device.audio-input
│                                          # com.apple.security.screencapture
├── Models/
│   ├── Meeting.swift                      # SwiftData models (from Section 5)
│   ├── TranscriptSegment.swift
│   ├── MeetingNote.swift
│   ├── Speaker.swift
│   ├── ScheduledMeeting.swift
│   └── MuteEvent.swift
├── Audio/
│   ├── AudioCaptureEngine.swift           # Manages all 3 streams
│   ├── MicrophoneCapture.swift            # AVAudioEngine mic input
│   ├── SystemAudioCapture.swift           # ScreenCaptureKit system audio
│   ├── AudioMixer.swift                   # Real-time mixing of streams
│   ├── AudioRecorder.swift                # WAV file writing
│   └── DeviceManager.swift                # Audio device enumeration & hot-swap
├── Transcription/
│   ├── LiveTranscriptionEngine.swift      # Streaming Parakeet during meeting
│   ├── BatchTranscriptionEngine.swift     # Post-meeting full Parakeet pass
│   └── TranscriptionResult.swift          # Shared result types
├── Diarization/
│   ├── DiarizationEngine.swift            # Post-meeting diarization pipeline
│   ├── SpeakerIdentifier.swift            # Channel-aware speaker identification
│   └── TranscriptMerger.swift             # Merges transcription + diarization
├── Scheduling/
│   ├── MeetingScheduler.swift             # Schedule management
│   └── NotificationManager.swift          # UNUserNotificationCenter reminders
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift              # Menu bar dropdown panel
│   │   └── RecordingControlsView.swift    # Mic/system toggle, timer, live preview
│   ├── Main/
│   │   ├── MainWindowView.swift           # NavigationSplitView container
│   │   ├── SidebarView.swift              # Category sidebar
│   │   ├── MeetingListView.swift          # Meeting list for selected category
│   │   └── MeetingDetailView.swift        # Full meeting detail with tabs
│   ├── Detail/
│   │   ├── TranscriptTabView.swift        # Attributed transcript display
│   │   ├── AudioPlayerTabView.swift       # Waveform player
│   │   ├── NotesTabView.swift             # Notes management
│   │   └── AIAnalysisTabView.swift        # Stub for future MiniMax integration
│   ├── Schedule/
│   │   ├── ScheduleListView.swift         # Upcoming scheduled meetings
│   │   └── ScheduleMeetingView.swift      # Create/edit scheduled meeting
│   ├── Onboarding/
│   │   └── OnboardingView.swift           # First-run permission + model download
│   ├── Settings/
│   │   └── SettingsView.swift             # All settings tabs
│   └── Components/
│       ├── WaveformView.swift             # Audio waveform visualization
│       ├── SpeakerBadge.swift             # Colored speaker label
│       └── ProcessingStatusBadge.swift    # Status indicator
├── Export/
│   ├── TranscriptExporter.swift           # Export to txt, srt, json, pdf
│   └── PDFGenerator.swift                 # Simple PDF transcript generation
├── AI/
│   └── MiniMaxAnalyzer.swift              # Stub: OpenAI-compatible API client for M2.7
├── Utilities/
│   ├── FileManager+wrec.swift       # App-specific file paths
│   ├── Date+Formatting.swift              # Date formatting helpers
│   └── AudioUtils.swift                   # Sample rate conversion, level metering
└── Resources/
    └── Assets.xcassets                    # App icon, menu bar icons, speaker colors

13. KEY IMPLEMENTATION NOTES

13.1 ScreenCaptureKit Audio-Only Capture

To capture system audio without recording the screen, configure SCStreamConfiguration to capture audio only. You still need the Screen Recording permission, but you won't be recording any video:

let config = SCStreamConfiguration()
config.capturesAudio = true
config.sampleRate = 16000
config.channelCount = 1
config.excludesCurrentProcessAudio = true  // Don't capture our own app's sounds

// Create a content filter that captures the entire display's audio
let content = try await SCShareableContent.current
let display = content.displays.first!
let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

let stream = SCStream(filter: filter, configuration: config, delegate: self)
try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
try await stream.startCapture()

13.2 AVAudioEngine Microphone Capture

let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
    // Process mic audio buffer
    self.processMicBuffer(buffer, at: time)
}

try audioEngine.start()

13.3 Running Diarization as a Background Task

The diarization pipeline should run on a background thread and not block the UI. Use Swift's structured concurrency:

func processRecording(meeting: Meeting) async {
    meeting.transcriptionStatus = .inProgress
    
    // Step 1: Batch transcription
    let parakeet = try await ParakeetASRModel.fromPretrained()
    let audioSamples = try loadAudio(from: meeting.combinedAudioPath!)
    let transcription = try parakeet.transcribeAudio(audioSamples, sampleRate: 16000)
    
    meeting.transcriptionStatus = .completed
    meeting.diarizationStatus = .inProgress
    
    // Step 2: Diarization
    let diarizer = try await DiarizationPipeline.fromPretrained()
    let diarization = diarizer.diarize(audio: audioSamples, sampleRate: 16000)
    
    // Step 3: Speaker identification via channel separation
    let embedder = try await WeSpeakerModel.fromPretrained()
    let micAudio = try loadAudio(from: meeting.micAudioPath!)
    let myEmbedding = embedder.embed(audio: micAudio, sampleRate: 16000)
    
    // Find which cluster is "Me"
    let mySpeakerId = identifyMySpeaker(
        myEmbedding: myEmbedding,
        diarization: diarization,
        audioSamples: audioSamples,
        embedder: embedder
    )
    
    // Step 4: Merge transcription + diarization
    let segments = mergeTranscriptWithDiarization(
        transcription: transcription,
        diarization: diarization,
        mySpeakerId: mySpeakerId
    )
    
    // Save to SwiftData
    for seg in segments {
        let segment = TranscriptSegment(...)
        meeting.segments.append(segment)
    }
    
    meeting.diarizationStatus = .completed
}

13.4 Handling the "Mute Mic but Keep System Audio" Scenario

When the user mutes the mic (e.g., to listen to music without it being picked up):
- Stop feeding mic audio to the live transcription engine
- Continue feeding system audio to live transcription
- Continue writing silence to mic.wav to maintain time alignment
- The combined stream (combined.wav) will contain only system audio during this period
- This means the post-meeting diarization will naturally not detect the user's voice during muted periods — which is correct behavior

13.5 App Lifecycle

The app should:
- Launch at login (configurable in Settings)
- Run as a menu bar agent (LSUIElement = true in Info.plist, with the option to show in the dock when the main window is open)
- Continue recording if the main window is closed (recording lives in the menu bar)
- Gracefully handle unexpected quit during recording: auto-save whatever audio has been captured, mark the meeting as "Recording Interrupted", and offer to process on next launch

14. FUTURE INTEGRATION STUBS (DO NOT IMPLEMENT YET, JUST SCAFFOLD)

14.1 MiniMax M2.7 AI Analysis

Create MiniMaxAnalyzer.swift with:
- An OpenAI-compatible API client pointing to https://api.minimax.chat/v1
- A method analyzeTranscript(transcript: String, meetingType: MeetingType) -> String that sends the transcript with a meeting-type-specific prompt
- Per-meeting-type prompt templates stored as constants:

static let promptTemplates: [MeetingType: String] = [
    .marketingMeeting: "Analyze this marketing meeting transcript. Extract: 1) Key decisions 2) Action items with owners 3) Campaign ideas discussed 4) Budget implications 5) Next steps",
    .lessonPlanMeeting: "Analyze this lesson planning meeting. Extract: 1) Topics/units discussed 2) Learning objectives defined 3) Materials needed 4) Assessment strategies 5) Timeline",
    .studentInterview: "Analyze this student interview. Extract: 1) Student's strengths 2) Areas for improvement 3) Goals discussed 4) Support needed 5) Follow-up actions",
    .parentTeacherMeeting: "Analyze this parent-teacher meeting. Extract: 1) Student progress summary 2) Concerns raised (by parent and teacher) 3) Agreements made 4) Action items for home and school 5) Next meeting date",
    .parentIntroductoryCall: "Analyze this introductory call with parents. Extract: 1) Family background shared 2) Student's learning needs 3) Parent expectations 4) Program details discussed 5) Next steps",
    .classSession: "Analyze this class session recording. Extract: 1) Topics covered 2) Key concepts taught 3) Student questions asked 4) Areas where students struggled 5) Homework/assignments given",
    .spar: "Analyze this sparring/debate session. Extract: 1) Main arguments presented by each side 2) Strongest points 3) Weakest points 4) Logical fallacies detected 5) Overall assessment",
]

This is stubbed but not connected — just the interface ready for when the user wants to wire it up.

15. BUILD & RUN INSTRUCTIONS

1. Clone or create the Xcode project
Create a new macOS App project in Xcode with SwiftUI lifecycle
Name: wrec
Bundle ID: com.yourname.meetscribe

2. Add the speech-swift package
In Xcode: File → Add Package Dependencies
URL: https://github.com/soniqo/speech-swift
Branch: main
Add products: ParakeetASR, ParakeetStreamingASR, SpeechVAD, AudioCommon

3. Configure signing
Use a Development signing certificate (not ad-hoc) to avoid TCC permission resets
Enable: com.apple.security.device.audio-input in entitlements
The app needs to NOT be sandboxed for ScreenCaptureKit system audio capture
(or use the temporary exception entitlement for screen capture in sandboxed apps)

4. Build the speech-swift Metal shaders
After adding the package, build once — the Metal shader library compiles automatically

5. Run
First run triggers model downloads (~1.2 GB total)
Grant microphone and screen recording permissions when prompted

16. TESTING CHECKLIST

After building, verify each of these works end-to-end:

1. Menu bar icon appears and dropdown panel works
2. Permission flow grants mic and system audio access
3. Model download completes for all 4 models
4. Start recording captures mic audio (verify by playing back mic.wav)
5. System audio capture works (play a YouTube video, verify system.wav has audio)
6. Combined audio has both streams mixed
7. Live transcription shows text appearing in real-time during recording
8. Mute mic stops mic audio but system audio continues; combined stream reflects this
9. Unmute mic resumes mic audio
10. Stop recording triggers post-processing pipeline
11. Batch transcription produces higher-quality transcript than live
12. Diarization correctly identifies multiple speakers
13. Speaker identification correctly labels "Me" vs remote speakers
14. Transcript + diarization merge produces properly attributed conversation
15. Meeting saved to SwiftData and appears in the meeting list
16. Category filtering works in sidebar
17. Notes can be added before, during, and after meeting with correct timestamps
18. Scheduled meeting creates notification at correct time
19. Notification action starts recording when tapped
20. Export produces correct .txt, .srt, .json files
21. Audio player plays back combined audio with waveform
22. Speaker renaming persists across app restarts
23. Search finds meetings by transcript content, title, and notes
24. App survives crash during recording — audio files recoverable on next launch
