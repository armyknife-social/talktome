import Foundation
import SwiftData

enum DocumentSourceType: String, Codable, CaseIterable {
    case pdf = "PDF"
    case epub = "EPUB"
    case web = "Web Article"
    case text = "Plain Text"

    var iconName: String {
        switch self {
        case .pdf: return "doc.fill"
        case .epub: return "book.fill"
        case .web: return "globe"
        case .text: return "doc.text.fill"
        }
    }
}

enum CloudFileStatus: String, Codable {
    case local
    case uploading
    case uploaded
    case downloading
    case evicted
}

@Model
final class Document {
    var id: UUID
    var title: String
    var author: String
    var sourceType: DocumentSourceType
    var fullText: String
    var dateAdded: Date
    var lastOpened: Date?
    var thumbnailData: Data?
    var cloudFileName: String?
    var fileSize: Int64
    var cloudStatus: CloudFileStatus
    var totalListeningTime: TimeInterval
    var isCompleted: Bool
    var sourceURL: String?

    // Chapter/page boundaries stored as JSON array of character offsets
    var sectionBoundariesData: Data?

    var sectionNames: [String] {
        get {
            guard let data = sectionNamesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            sectionNamesData = try? JSONEncoder().encode(newValue)
        }
    }
    var sectionNamesData: Data?

    var sectionBoundaries: [Int] {
        get {
            guard let data = sectionBoundariesData else { return [] }
            return (try? JSONDecoder().decode([Int].self, from: data)) ?? []
        }
        set {
            sectionBoundariesData = try? JSONEncoder().encode(newValue)
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.document)
    var bookmarks: [Bookmark]? = []

    @Relationship(deleteRule: .cascade, inverse: \Highlight.document)
    var highlights: [Highlight]? = []

    @Relationship(deleteRule: .cascade, inverse: \ReadingProgress.document)
    var readingProgress: ReadingProgress?

    var isCloudBacked: Bool {
        cloudFileName != nil
    }

    var estimatedDuration: TimeInterval {
        // Average reading speed for TTS: ~150 words per minute at 1x
        let wordCount = Double(fullText.split(separator: " ").count)
        return (wordCount / 150.0) * 60.0
    }

    var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    var progressPercentage: Double {
        guard let progress = readingProgress else { return 0 }
        guard !fullText.isEmpty else { return 0 }
        return Double(progress.characterOffset) / Double(fullText.count)
    }

    init(
        title: String,
        author: String = "",
        sourceType: DocumentSourceType,
        fullText: String,
        thumbnailData: Data? = nil,
        cloudFileName: String? = nil,
        fileSize: Int64 = 0,
        sourceURL: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.sourceType = sourceType
        self.fullText = fullText
        self.dateAdded = Date()
        self.thumbnailData = thumbnailData
        self.cloudFileName = cloudFileName
        self.fileSize = fileSize
        self.cloudStatus = cloudFileName != nil ? .uploaded : .local
        self.totalListeningTime = 0
        self.isCompleted = false
        self.sourceURL = sourceURL
    }
}
