import Foundation
import AVFoundation

/// Word-level progress information for highlighting
struct WordProgress: Equatable {
    let wordRange: NSRange
    let utteranceIndex: Int
}

@Observable
final class TTSEngine: NSObject {
    // MARK: - Published State
    var isPlaying: Bool = false
    var isPaused: Bool = false
    var currentUtteranceIndex: Int = 0
    var progress: Double = 0.0
    var currentWordRange: NSRange?
    var currentVoice: AVSpeechSynthesisVoice?
    var speed: Float = AppConstants.TTS.defaultSpeed
    var pitch: Float = AppConstants.TTS.defaultPitch
    var availableVoices: [AVSpeechSynthesisVoice] = []

    // MARK: - Private
    private let synthesizer = AVSpeechSynthesizer()
    private var chunks: [TextChunk] = []
    private var fullText: String = ""
    private var onWordSpoken: ((NSRange, Int) -> Void)?
    private var onUtteranceFinished: ((Int) -> Void)?
    private var onAllFinished: (() -> Void)?
    private var playbackStartTime: Date?
    private var accumulatedListeningTime: TimeInterval = 0

    override init() {
        super.init()
        synthesizer.delegate = self
        loadVoices()
        configureAudioSession()
    }

    // MARK: - Voice Management

    private func loadVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().sorted { v1, v2 in
            if v1.language == v2.language {
                return v1.name < v2.name
            }
            return v1.language < v2.language
        }
        // Default to a good English voice
        currentVoice = AVSpeechSynthesisVoice(language: "en-US")
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Audio session configuration is best-effort
        }
    }

    var voicesGroupedByLanguage: [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let grouped = Dictionary(grouping: availableVoices) { voice in
            Locale.current.localizedString(forLanguageCode: voice.language) ?? voice.language
        }
        return grouped.sorted { $0.key < $1.key }.map { (language: $0.key, voices: $0.value) }
    }

    // MARK: - Playback Control

    func play(text: String, fromCharacterOffset offset: Int = 0) {
        stop()
        fullText = text
        chunks = TextChunker.splitIntoSentences(text)

        guard !chunks.isEmpty else { return }

        let startIndex = TextChunker.chunkIndex(forCharacterOffset: offset, in: chunks) ?? 0
        currentUtteranceIndex = startIndex

        speakFromCurrentIndex()
    }

    func pause() {
        guard isPlaying else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isPlaying = false
        recordListeningTime()
    }

    func resume() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
        playbackStartTime = Date()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentWordRange = nil
        recordListeningTime()
    }

    func skipForward() {
        let newOffset: Int
        if let chunk = chunks[safe: currentUtteranceIndex] {
            newOffset = TextChunker.skipOffset(
                from: chunk.characterOffset,
                seconds: AppConstants.TTS.skipInterval,
                speed: speed,
                in: fullText
            )
        } else {
            return
        }

        if let newIndex = TextChunker.chunkIndex(forCharacterOffset: newOffset, in: chunks) {
            synthesizer.stopSpeaking(at: .immediate)
            currentUtteranceIndex = newIndex
            speakFromCurrentIndex()
        }
    }

    func skipBackward() {
        let newOffset: Int
        if let chunk = chunks[safe: currentUtteranceIndex] {
            newOffset = TextChunker.skipOffset(
                from: chunk.characterOffset,
                seconds: -AppConstants.TTS.skipInterval,
                speed: speed,
                in: fullText
            )
        } else {
            return
        }

        if let newIndex = TextChunker.chunkIndex(forCharacterOffset: newOffset, in: chunks) {
            synthesizer.stopSpeaking(at: .immediate)
            currentUtteranceIndex = newIndex
            speakFromCurrentIndex()
        }
    }

    func seekTo(characterOffset: Int) {
        guard let newIndex = TextChunker.chunkIndex(forCharacterOffset: characterOffset, in: chunks) else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentUtteranceIndex = newIndex
        speakFromCurrentIndex()
    }

    func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "Hello, this is a preview of the \(voice.name) voice.")
        utterance.voice = voice
        utterance.rate = AppConstants.TTS.utteranceRate(forSpeed: 1.0)
        utterance.pitchMultiplier = 1.0

        let previewSynth = AVSpeechSynthesizer()
        previewSynth.speak(utterance)
    }

    // MARK: - Callbacks

    func onWordSpoken(_ handler: @escaping (NSRange, Int) -> Void) {
        onWordSpoken = handler
    }

    func onUtteranceFinished(_ handler: @escaping (Int) -> Void) {
        onUtteranceFinished = handler
    }

    func onAllFinished(_ handler: @escaping () -> Void) {
        onAllFinished = handler
    }

    // MARK: - Progress

    var currentCharacterOffset: Int {
        guard let chunk = chunks[safe: currentUtteranceIndex] else { return 0 }
        return chunk.characterOffset
    }

    var totalCharacters: Int {
        fullText.count
    }

    // MARK: - Listening Time

    var sessionListeningTime: TimeInterval {
        var total = accumulatedListeningTime
        if isPlaying, let start = playbackStartTime {
            total += Date().timeIntervalSince(start)
        }
        return total
    }

    private func recordListeningTime() {
        if let start = playbackStartTime {
            accumulatedListeningTime += Date().timeIntervalSince(start)
            playbackStartTime = nil
        }
    }

    func resetListeningTime() {
        accumulatedListeningTime = 0
        playbackStartTime = isPlaying ? Date() : nil
    }

    // MARK: - Private

    private func speakFromCurrentIndex() {
        guard currentUtteranceIndex < chunks.count else {
            isPlaying = false
            isPaused = false
            currentWordRange = nil
            onAllFinished?()
            return
        }

        let chunk = chunks[currentUtteranceIndex]
        let utterance = AVSpeechUtterance(string: chunk.text)
        utterance.voice = currentVoice
        utterance.rate = AppConstants.TTS.utteranceRate(forSpeed: speed)
        utterance.pitchMultiplier = pitch

        isPlaying = true
        isPaused = false
        playbackStartTime = Date()
        updateProgress()

        synthesizer.speak(utterance)
    }

    private func updateProgress() {
        guard !chunks.isEmpty else {
            progress = 0
            return
        }
        progress = Double(currentUtteranceIndex) / Double(chunks.count)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Calculate the absolute range in the full text
        guard let chunk = chunks[safe: currentUtteranceIndex] else { return }
        let absoluteRange = NSRange(
            location: chunk.characterOffset + characterRange.location,
            length: characterRange.length
        )
        currentWordRange = absoluteRange
        onWordSpoken?(absoluteRange, currentUtteranceIndex)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finishedIndex = currentUtteranceIndex
        onUtteranceFinished?(finishedIndex)

        currentUtteranceIndex += 1
        currentWordRange = nil

        if currentUtteranceIndex < chunks.count {
            // Speak the next chunk
            speakFromCurrentIndex()
        } else {
            // All done
            isPlaying = false
            isPaused = false
            progress = 1.0
            recordListeningTime()
            onAllFinished?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Cancelled - do nothing, the caller handles state
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
