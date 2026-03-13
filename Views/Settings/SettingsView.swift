import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Bindable var playerViewModel: PlayerViewModel
    @AppStorage("defaultSpeed") private var defaultSpeed: Double = 1.0
    @AppStorage("defaultPitch") private var defaultPitch: Double = 1.0
    @AppStorage("defaultVoiceIdentifier") private var defaultVoiceIdentifier: String = ""
    @AppStorage("readerFontSize") private var readerFontSize: Double = 18.0
    @AppStorage("readerBackground") private var readerBackgroundRaw: String = "white"
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("storeInICloud") private var storeInICloud: Bool = true

    @State private var showVoicePicker: Bool = false
    @State private var cloudStorageUsed: Int64 = 0
    @State private var cloudFileCount: Int = 0

    private let cloudStorage = CloudStorageManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // Voice Section
                voiceSection

                // Playback Section
                playbackSection

                // Reader Section
                readerSection

                // Appearance Section
                appearanceSection

                // Storage Section
                storageSection

                // About Section
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showVoicePicker) {
                VoicePickerView(playerViewModel: playerViewModel)
            }
            .task {
                await loadCloudStorageUsage()
            }
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            Button {
                showVoicePicker = true
            } label: {
                HStack {
                    Label("Default Voice", systemImage: "person.wave.2")
                    Spacer()
                    Text(currentVoiceName)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Voice")
        }
    }

    private var currentVoiceName: String {
        if let voice = playerViewModel.ttsEngine.currentVoice {
            return voice.name
        }
        return "System Default"
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Speed", systemImage: "speedometer")
                    Spacer()
                    Text(String(format: "%.1fx", defaultSpeed))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: $defaultSpeed,
                    in: Double(AppConstants.TTS.minSpeed)...Double(AppConstants.TTS.maxSpeed),
                    step: 0.25
                ) {
                    Text("Speed")
                } minimumValueLabel: {
                    Text("0.5x")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("4x")
                        .font(.caption2)
                }
                .onChange(of: defaultSpeed) { _, newValue in
                    playerViewModel.ttsEngine.speed = Float(newValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Pitch", systemImage: "tuningfork")
                    Spacer()
                    Text(String(format: "%.1f", defaultPitch))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: $defaultPitch,
                    in: Double(AppConstants.TTS.minPitch)...Double(AppConstants.TTS.maxPitch),
                    step: 0.1
                ) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("Low")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("High")
                        .font(.caption2)
                }
                .onChange(of: defaultPitch) { _, newValue in
                    playerViewModel.ttsEngine.pitch = Float(newValue)
                }
            }
        } header: {
            Text("Playback")
        }
    }

    // MARK: - Reader Section

    private var readerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Font Size", systemImage: "textformat.size")
                    Spacer()
                    Text("\(Int(readerFontSize)) pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(
                    value: $readerFontSize,
                    in: Double(AppConstants.Reader.minFontSize)...Double(AppConstants.Reader.maxFontSize),
                    step: 1
                ) {
                    Text("Font Size")
                } minimumValueLabel: {
                    Text("A")
                        .font(.caption2)
                } maximumValueLabel: {
                    Text("A")
                        .font(.body)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Background", systemImage: "paintpalette")

                HStack(spacing: 16) {
                    ForEach(ReaderBackground.allCases, id: \.self) { bg in
                        Button {
                            readerBackgroundRaw = bg.rawValue
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(bg.backgroundColor)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle().strokeBorder(
                                            readerBackgroundRaw == bg.rawValue ? Color.accentColor : Color.secondary.opacity(0.3),
                                            lineWidth: readerBackgroundRaw == bg.rawValue ? 3 : 1
                                        )
                                    )
                                Text(bg.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(readerBackgroundRaw == bg.rawValue ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } header: {
            Text("Reader")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Picker(selection: $appTheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            Toggle(isOn: $storeInICloud) {
                Label("Store Originals in iCloud", systemImage: "icloud")
            }

            HStack {
                Label("iCloud Storage Used", systemImage: "externaldrive.badge.icloud")
                Spacer()
                VStack(alignment: .trailing) {
                    Text(cloudStorageUsed.formattedFileSize)
                        .foregroundStyle(.secondary)
                    Text("\(cloudFileCount) files")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Storage")
        } footer: {
            Text("When enabled, original PDF and EPUB files are stored in iCloud and automatically managed by iOS. Extracted text stays on device for instant playback.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("iOS Requirement", systemImage: "iphone")
                Spacer()
                Text("iOS 17+")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Built With", systemImage: "swift")
                Spacer()
                Text("SwiftUI + AVFoundation")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Helpers

    private func loadCloudStorageUsage() async {
        let usage = await cloudStorage.cloudStorageUsage()
        cloudStorageUsed = usage.used
        cloudFileCount = usage.fileCount
    }
}
