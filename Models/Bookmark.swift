import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var characterOffset: Int
    var label: String
    var dateCreated: Date
    var document: Document?

    var previewText: String {
        guard let doc = document else { return "" }
        let text = doc.fullText
        let startIndex = text.index(text.startIndex, offsetBy: min(characterOffset, text.count))
        let endIndex = text.index(startIndex, offsetBy: min(80, text.distance(from: startIndex, to: text.endIndex)))
        return String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(characterOffset: Int, label: String = "", document: Document? = nil) {
        self.id = UUID()
        self.characterOffset = characterOffset
        self.label = label
        self.dateCreated = Date()
        self.document = document
    }
}
