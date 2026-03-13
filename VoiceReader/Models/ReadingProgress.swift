import Foundation
import SwiftData

@Model
final class ReadingProgress {
    var id: UUID
    var characterOffset: Int
    var lastUpdated: Date
    var totalListeningTime: TimeInterval
    var document: Document?

    var progressDescription: String {
        guard let doc = document else { return "" }
        guard !doc.fullText.isEmpty else { return "0%" }
        let percentage = Int((Double(characterOffset) / Double(doc.fullText.count)) * 100)
        return "\(min(percentage, 100))%"
    }

    init(characterOffset: Int = 0, document: Document? = nil) {
        self.id = UUID()
        self.characterOffset = characterOffset
        self.lastUpdated = Date()
        self.totalListeningTime = 0
        self.document = document
    }
}
