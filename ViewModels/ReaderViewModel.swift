import Foundation
import SwiftData
import SwiftUI

@Observable
final class ReaderViewModel {
    var document: Document?
    var fontSize: CGFloat = AppConstants.Reader.defaultFontSize
    var readerBackground: ReaderBackground = .white
    var showTableOfContents: Bool = false
    var showSettings: Bool = false
    var showHighlightPicker: Bool = false
    var showBookmarks: Bool = false
    var selectedTextRange: NSRange?
    var scrollToOffset: Int?
    var errorMessage: String?
    var showError: Bool = false

    // Highlight creation state
    var highlightStart: Int?
    var highlightEnd: Int?
    var pendingHighlightColor: HighlightColor = .yellow

    private var modelContext: ModelContext?

    func configure(document: Document, context: ModelContext) {
        self.document = document
        self.modelContext = context

        // Load saved preferences
        fontSize = CGFloat(UserDefaults.standard.float(forKey: "readerFontSize"))
        if fontSize < AppConstants.Reader.minFontSize {
            fontSize = AppConstants.Reader.defaultFontSize
        }

        if let bgRaw = UserDefaults.standard.string(forKey: "readerBackground"),
           let bg = ReaderBackground(rawValue: bgRaw) {
            readerBackground = bg
        }

        // Mark as opened
        document.lastOpened = Date()
        try? context.save()
    }

    // MARK: - Font Size

    func increaseFontSize() {
        fontSize = min(fontSize + 2, AppConstants.Reader.maxFontSize)
        saveFontSize()
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 2, AppConstants.Reader.minFontSize)
        saveFontSize()
    }

    func setFontSize(_ size: CGFloat) {
        fontSize = max(AppConstants.Reader.minFontSize, min(size, AppConstants.Reader.maxFontSize))
        saveFontSize()
    }

    private func saveFontSize() {
        UserDefaults.standard.set(Float(fontSize), forKey: "readerFontSize")
    }

    // MARK: - Background

    func setBackground(_ background: ReaderBackground) {
        readerBackground = background
        UserDefaults.standard.set(background.rawValue, forKey: "readerBackground")
    }

    // MARK: - Bookmarks

    var bookmarks: [Bookmark] {
        document?.bookmarks?.sorted { $0.characterOffset < $1.characterOffset } ?? []
    }

    func addBookmark(at offset: Int, label: String = "") {
        guard let document = document, let context = modelContext else { return }
        let bookmark = Bookmark(
            characterOffset: offset,
            label: label.isEmpty ? "Bookmark at \(formatOffset(offset))" : label,
            document: document
        )
        context.insert(bookmark)
        try? context.save()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        guard let context = modelContext else { return }
        context.delete(bookmark)
        try? context.save()
    }

    func isBookmarked(at offset: Int) -> Bool {
        bookmarks.contains { abs($0.characterOffset - offset) < 50 }
    }

    // MARK: - Highlights

    var highlights: [Highlight] {
        document?.highlights?.sorted { $0.startOffset < $1.startOffset } ?? []
    }

    func addHighlight(startOffset: Int, endOffset: Int, color: HighlightColor) {
        guard let document = document, let context = modelContext else { return }
        let highlight = Highlight(
            startOffset: startOffset,
            endOffset: endOffset,
            color: color,
            document: document
        )
        context.insert(highlight)
        try? context.save()
    }

    func removeHighlight(_ highlight: Highlight) {
        guard let context = modelContext else { return }
        context.delete(highlight)
        try? context.save()
    }

    func highlightAt(offset: Int) -> Highlight? {
        highlights.first { offset >= $0.startOffset && offset < $0.endOffset }
    }

    // MARK: - Reading Progress

    func updateProgress(characterOffset: Int) {
        guard let document = document, let context = modelContext else { return }
        if let progress = document.readingProgress {
            progress.characterOffset = characterOffset
            progress.lastUpdated = Date()
        } else {
            let progress = ReadingProgress(characterOffset: characterOffset, document: document)
            context.insert(progress)
        }
        try? context.save()
    }

    func updateListeningTime(_ time: TimeInterval) {
        guard let document = document, let context = modelContext else { return }
        document.totalListeningTime += time
        if let progress = document.readingProgress {
            progress.totalListeningTime += time
        }
        try? context.save()
    }

    var currentOffset: Int {
        document?.readingProgress?.characterOffset ?? 0
    }

    // MARK: - Table of Contents

    var tableOfContents: [(name: String, offset: Int)] {
        guard let document = document else { return [] }
        let boundaries = document.sectionBoundaries
        let names = document.sectionNames
        var result: [(name: String, offset: Int)] = []
        for (index, offset) in boundaries.enumerated() {
            let name = index < names.count ? names[index] : "Section \(index + 1)"
            result.append((name: name, offset: offset))
        }
        return result
    }

    // MARK: - Helpers

    private func formatOffset(_ offset: Int) -> String {
        guard let document = document, !document.fullText.isEmpty else { return "0%" }
        let percentage = Int((Double(offset) / Double(document.fullText.count)) * 100)
        return "\(percentage)%"
    }
}
