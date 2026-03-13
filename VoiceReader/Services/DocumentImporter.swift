import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum ImportError: LocalizedError {
    case unsupportedFormat
    case pdfExtractionFailed
    case epubParsingFailed(String)
    case webExtractionFailed(String)
    case emptyDocument
    case fileReadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported file format"
        case .pdfExtractionFailed: return "Failed to extract text from PDF"
        case .epubParsingFailed(let detail): return "EPUB parsing failed: \(detail)"
        case .webExtractionFailed(let detail): return "Web extraction failed: \(detail)"
        case .emptyDocument: return "The document contains no readable text"
        case .fileReadFailed: return "Failed to read the file"
        }
    }
}

struct ImportResult {
    let title: String
    let author: String
    let fullText: String
    let sourceType: DocumentSourceType
    let thumbnailData: Data?
    let fileData: Data?
    let fileSize: Int64
    let sectionBoundaries: [Int]
    let sectionNames: [String]
    let sourceURL: String?
}

final class DocumentImporter {
    private let epubParser = EPUBParser()
    private let webExtractor = WebArticleExtractor()

    // MARK: - PDF Import

    func importPDF(url: URL) async throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else {
            throw ImportError.pdfExtractionFailed
        }

        var fullText = ""
        var pageBoundaries: [Int] = []
        var pageNames: [String] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            pageBoundaries.append(fullText.count)
            pageNames.append("Page \(pageIndex + 1)")

            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText += pageText.trimmingCharacters(in: .whitespacesAndNewlines)
                fullText += "\n\n"
            }
        }

        let text = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ImportError.emptyDocument
        }

        let title = url.deletingPathExtension().lastPathComponent
        let thumbnail = generatePDFThumbnail(document: document)
        let fileData = try? Data(contentsOf: url)
        let fileSize = Int64((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0)

        return ImportResult(
            title: title,
            author: extractPDFAuthor(document: document),
            fullText: text,
            sourceType: .pdf,
            thumbnailData: thumbnail,
            fileData: fileData,
            fileSize: fileSize,
            sectionBoundaries: pageBoundaries,
            sectionNames: pageNames,
            sourceURL: nil
        )
    }

    // MARK: - EPUB Import

    func importEPUB(url: URL) async throws -> ImportResult {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let fileData = try? Data(contentsOf: url) else {
            throw ImportError.fileReadFailed
        }

        do {
            let metadata = try await epubParser.parse(data: fileData)

            var fullText = ""
            var chapterBoundaries: [Int] = []
            var chapterNames: [String] = []

            for chapter in metadata.chapters {
                chapterBoundaries.append(fullText.count)
                chapterNames.append(chapter.title)
                fullText += chapter.content + "\n\n"
            }

            let text = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw ImportError.emptyDocument
            }

            let fileSize = Int64(fileData.count)

            return ImportResult(
                title: metadata.title,
                author: metadata.author,
                fullText: text,
                sourceType: .epub,
                thumbnailData: nil,
                fileData: fileData,
                fileSize: fileSize,
                sectionBoundaries: chapterBoundaries,
                sectionNames: chapterNames,
                sourceURL: nil
            )
        } catch {
            throw ImportError.epubParsingFailed(error.localizedDescription)
        }
    }

    // MARK: - Web Article Import

    func importWebArticle(urlString: String) async throws -> ImportResult {
        do {
            let article = try await webExtractor.extract(from: urlString)

            guard !article.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImportError.emptyDocument
            }

            return ImportResult(
                title: article.title,
                author: article.author,
                fullText: article.content,
                sourceType: .web,
                thumbnailData: nil,
                fileData: nil,
                fileSize: 0,
                sectionBoundaries: [],
                sectionNames: [],
                sourceURL: urlString
            )
        } catch let error as WebArticleExtractorError {
            throw ImportError.webExtractionFailed(error.localizedDescription)
        }
    }

    // MARK: - Plain Text Import

    func importPlainText(text: String, title: String) -> ImportResult {
        return ImportResult(
            title: title.isEmpty ? "Untitled" : title,
            author: "",
            fullText: text,
            sourceType: .text,
            thumbnailData: nil,
            fileData: nil,
            fileSize: Int64(text.utf8.count),
            sectionBoundaries: [],
            sectionNames: [],
            sourceURL: nil
        )
    }

    // MARK: - File Import (from URL, auto-detect type)

    func importFile(url: URL) async throws -> ImportResult {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return try await importPDF(url: url)
        case "epub":
            return try await importEPUB(url: url)
        case "txt", "text", "md", "markdown":
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw ImportError.fileReadFailed
            }
            let title = url.deletingPathExtension().lastPathComponent
            return importPlainText(text: text, title: title)
        default:
            throw ImportError.unsupportedFormat
        }
    }

    // MARK: - PDF Helpers

    private func generatePDFThumbnail(document: PDFDocument) -> Data? {
        guard let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 200.0 / max(bounds.width, bounds.height)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.jpegData(compressionQuality: 0.6)
    }

    private func extractPDFAuthor(document: PDFDocument) -> String {
        if let attributes = document.documentAttributes,
           let author = attributes[PDFDocumentAttribute.authorAttribute] as? String {
            return author
        }
        return ""
    }
}

// MARK: - Document Picker (UIViewControllerRepresentable)

struct DocumentPickerView: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
