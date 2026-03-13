import Foundation
import SwiftUI

@Observable
final class PlayerViewModel {
    // MARK: - State
    var currentDocument: Document?
    var showFullPlayer: Bool = false
    var showVoicePicker: Bool = false
    var showSleepTimer: Bool = false
    var showDisplaySettings: Bool = false
    var sleepTimerMinutes: Int? = nil
    var sleepTimerEndDate: Date? = nil

    let ttsEngine = TTSEngine()

    // MARK: - Computed Properties

    var isActive: Bool {
        currentDocument != nil && (ttsEngine.isPlaying || ttsEngine.isPaused)
    }

    var isPlaying: Bool {
        ttsEngine.isPlaying
    }

    var isPaused: Bool {
        ttsEngine.isPaused
    }

    var progress: Double {
        guard let doc = currentDocument, !doc.fullText.isEmpty else { return 0 }
        return Double(ttsEngine.currentCharacterOffset) / Double(doc.fullText.count)
    }

    var currentPositionText: String {
        guard let doc = currentDocument else { return "" }
        let percentage = Int(progress * 100)
        let remaining = doc.estimatedDuration * (1.0 - progress) / Double(ttsEngine.speed)
        return "\(percentage)% • \(remaining.shortDuration) left"
    }

    var speed: Float {
        get { ttsEngine.speed }
        set { ttsEngine.speed = newValue }
    }

    var pitch: Float {
        get { ttsEngine.pitch }
        set { ttsEngine.pitch = newValue }
    }

    // MARK: - Playback Control

    func play(document: Document, fromOffset: Int = 0) {
        currentDocument = document
        let startOffset = fromOffset > 0 ? fromOffset : (document.readingProgress?.characterOffset ?? 0)
        ttsEngine.play(text: document.fullText, fromCharacterOffset: startOffset)
    }

    func playPause() {
        if ttsEngine.isPlaying {
            ttsEngine.pause()
        } else if ttsEngine.isPaused {
            ttsEngine.resume()
        } else if let doc = currentDocument {
            play(document: doc)
        }
    }

    func stop() {
        ttsEngine.stop()
        currentDocument = nil
        sleepTimerEndDate = nil
    }

    func skipForward() {
        ttsEngine.skipForward()
    }

    func skipBackward() {
        ttsEngine.skipBackward()
    }

    func seekTo(percentage: Double) {
        guard let doc = currentDocument else { return }
        let offset = Int(percentage * Double(doc.fullText.count))
        ttsEngine.seekTo(characterOffset: offset)
    }

    // MARK: - Voice

    func selectVoice(_ voice: AVSpeechSynthesisVoice) {
        ttsEngine.currentVoice = voice
        UserDefaults.standard.set(voice.identifier, forKey: "defaultVoiceIdentifier")

        // If currently playing, restart from current position
        if ttsEngine.isPlaying || ttsEngine.isPaused {
            let currentOffset = ttsEngine.currentCharacterOffset
            if let doc = currentDocument {
                ttsEngine.play(text: doc.fullText, fromCharacterOffset: currentOffset)
            }
        }
    }

    // MARK: - Speed

    func setSpeed(_ speed: Float) {
        ttsEngine.speed = speed
        UserDefaults.standard.set(speed, forKey: "defaultSpeed")

        // Restart if playing to apply new speed
        if ttsEngine.isPlaying || ttsEngine.isPaused {
            let currentOffset = ttsEngine.currentCharacterOffset
            if let doc = currentDocument {
                ttsEngine.play(text: doc.fullText, fromCharacterOffset: currentOffset)
            }
        }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        sleepTimerMinutes = minutes
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)
            if self.sleepTimerEndDate != nil {
                self.ttsEngine.pause()
                self.sleepTimerEndDate = nil
                self.sleepTimerMinutes = nil
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimerMinutes = nil
        sleepTimerEndDate = nil
    }

    var sleepTimerRemaining: String? {
        guard let endDate = sleepTimerEndDate else { return nil }
        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else {
            sleepTimerEndDate = nil
            return nil
        }
        return remaining.formattedDuration
    }

    // MARK: - Initialization

    func loadDefaults() {
        // Load saved voice
        if let voiceID = UserDefaults.standard.string(forKey: "defaultVoiceIdentifier"),
           let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            ttsEngine.currentVoice = voice
        }

        // Load saved speed
        let savedSpeed = UserDefaults.standard.float(forKey: "defaultSpeed")
        if savedSpeed >= AppConstants.TTS.minSpeed && savedSpeed <= AppConstants.TTS.maxSpeed {
            ttsEngine.speed = savedSpeed
        }

        // Load saved pitch
        let savedPitch = UserDefaults.standard.float(forKey: "defaultPitch")
        if savedPitch >= AppConstants.TTS.minPitch && savedPitch <= AppConstants.TTS.maxPitch {
            ttsEngine.pitch = savedPitch
        }
    }
}

import AVFoundation
