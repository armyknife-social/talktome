import SwiftUI

struct FullPlayerView: View {
    @Bindable var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Document Info
                documentInfo

                Spacer()

                // Progress Slider
                progressSection

                // Main Controls
                mainControls

                // Secondary Controls
                secondaryControls

                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .fontWeight(.semibold)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let timer = playerViewModel.sleepTimerRemaining {
                        Label(timer, systemImage: "moon.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $playerViewModel.showVoicePicker) {
                VoicePickerView(playerViewModel: playerViewModel)
            }
            .sheet(isPresented: $playerViewModel.showSleepTimer) {
                sleepTimerSheet
            }
            .sheet(isPresented: $playerViewModel.showDisplaySettings) {
                displaySettingsSheet
            }
        }
    }

    // MARK: - Document Info

    private var documentInfo: some View {
        VStack(spacing: 16) {
            // Large icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: .accentColor.opacity(0.2), radius: 16, x: 0, y: 8)

                Image(systemName: playerViewModel.currentDocument?.sourceType.iconName ?? "doc.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 4) {
                Text(playerViewModel.currentDocument?.title ?? "No Document")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let author = playerViewModel.currentDocument?.author, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { playerViewModel.progress },
                    set: { playerViewModel.seekTo(percentage: $0) }
                ),
                in: 0...1
            )
            .tint(.accentColor)

            HStack {
                Text(currentTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                Text(remainingTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var currentTimeText: String {
        guard let doc = playerViewModel.currentDocument else { return "0:00" }
        let elapsed = doc.estimatedDuration * playerViewModel.progress / Double(playerViewModel.speed)
        return elapsed.formattedDuration
    }

    private var remainingTimeText: String {
        guard let doc = playerViewModel.currentDocument else { return "0:00" }
        let remaining = doc.estimatedDuration * (1.0 - playerViewModel.progress) / Double(playerViewModel.speed)
        return "-" + remaining.formattedDuration
    }

    // MARK: - Main Controls

    private var mainControls: some View {
        HStack(spacing: 40) {
            // Skip backward
            Button {
                playerViewModel.skipBackward()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "gobackward.15")
                        .font(.title)
                    Text("15s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60)

            // Play/Pause
            Button {
                playerViewModel.playPause()
            } label: {
                Image(systemName: playerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)
            }

            // Skip forward
            Button {
                playerViewModel.skipForward()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "goforward.15")
                        .font(.title)
                    Text("15s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60)
        }
    }

    // MARK: - Secondary Controls

    private var secondaryControls: some View {
        HStack(spacing: 24) {
            // Speed selector
            Menu {
                ForEach(AppConstants.TTS.speedOptions, id: \.self) { speed in
                    Button {
                        playerViewModel.setSpeed(speed)
                    } label: {
                        HStack {
                            Text(speedLabel(speed))
                            if playerViewModel.speed == speed {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(speedLabel(playerViewModel.speed))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }

            // Voice picker
            Button {
                playerViewModel.showVoicePicker = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "person.wave.2")
                        .font(.title3)
                    Text("Voice")
                        .font(.caption2)
                }
            }

            // Pitch slider
            VStack(spacing: 2) {
                Image(systemName: "tuningfork")
                    .font(.title3)
                Text("Pitch")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .overlay {
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { pitchValue in
                        Button {
                            playerViewModel.ttsEngine.pitch = Float(pitchValue)
                            UserDefaults.standard.set(Float(pitchValue), forKey: "defaultPitch")
                        } label: {
                            HStack {
                                Text(String(format: "%.2fx", pitchValue))
                                if playerViewModel.pitch == Float(pitchValue) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Color.clear
                        .frame(width: 44, height: 44)
                }
            }

            // Sleep timer
            Button {
                playerViewModel.showSleepTimer = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: playerViewModel.sleepTimerEndDate != nil ? "moon.fill" : "moon")
                        .font(.title3)
                    Text("Timer")
                        .font(.caption2)
                }
            }

            // Display settings
            Button {
                playerViewModel.showDisplaySettings = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "textformat.size")
                        .font(.title3)
                    Text("Aa")
                        .font(.caption2)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return "\(Int(speed))x"
        }
        return String(format: "%.1fx", speed).replacingOccurrences(of: ".0x", with: "x")
    }

    // MARK: - Sleep Timer Sheet

    private var sleepTimerSheet: some View {
        NavigationStack {
            List {
                if playerViewModel.sleepTimerEndDate != nil {
                    Section {
                        Button(role: .destructive) {
                            playerViewModel.cancelSleepTimer()
                            playerViewModel.showSleepTimer = false
                        } label: {
                            Label("Cancel Timer", systemImage: "xmark.circle")
                        }
                    }
                }

                Section("Set Sleep Timer") {
                    ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Button {
                            playerViewModel.setSleepTimer(minutes: minutes)
                            playerViewModel.showSleepTimer = false
                        } label: {
                            HStack {
                                Text(timerLabel(minutes))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if playerViewModel.sleepTimerMinutes == minutes {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { playerViewModel.showSleepTimer = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func timerLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        }
        return "\(hours)h \(remaining)m"
    }

    // MARK: - Display Settings Sheet

    private var displaySettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Pitch") {
                    HStack {
                        Text("Low")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { playerViewModel.pitch },
                                set: {
                                    playerViewModel.ttsEngine.pitch = $0
                                    UserDefaults.standard.set($0, forKey: "defaultPitch")
                                }
                            ),
                            in: AppConstants.TTS.minPitch...AppConstants.TTS.maxPitch,
                            step: 0.1
                        )
                        Text("High")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(String(format: "Current: %.1f", playerViewModel.pitch))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { playerViewModel.showDisplaySettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
