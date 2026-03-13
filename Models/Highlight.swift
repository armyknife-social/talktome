import Foundation
import SwiftData

enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case orange

    var displayName: String {
        rawValue.capitalized
    }
}

@Model
final class Highlight {
    var id: UUID
    var startOffset: Int
    var endOffset: Int
    var color: HighlightColor
    var note: String
    var dateCreated: Date
    var document: Document?

    var highlightedText: String {
        guard let doc = document else { return "" }
        let text = doc.fullText
        let safeStart = min(startOffset, text.count)
        let safeEnd = min(endOffset, text.count)
        guard safeStart < safeEnd else { return "" }
        let startIdx = text.index(text.startIndex, offsetBy: safeStart)
        let endIdx = text.index(text.startIndex, offsetBy: safeEnd)
        return String(text[startIdx..<endIdx])
    }

    init(
        startOffset: Int,
        endOffset: Int,
        color: HighlightColor = .yellow,
        note: String = "",
        document: Document? = nil
    ) {
        self.id = UUID()
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.color = color
        self.note = note
        self.dateCreated = Date()
        self.document = document
    }
}
