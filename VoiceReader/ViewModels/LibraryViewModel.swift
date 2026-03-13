import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class LibraryViewModel {
    var searchText: String = ""
    var sortOption: SortOption = .recentlyAdded
    var isImporting: Bool = false
    var showImportSheet: Bool = false
    var showDocumentPicker: Bool = false
    var showURLInput: Bool = false
    var showTextInput: Bool = false
    var importURL: String = ""
    var importTextTitle: String = ""
    var importTextContent: String = ""
    var errorMessage: String?
    var showError: Bool = false
    var isLoading: Bool = false
    var documentPickerTypes: [UTType] = []

    private let importer = DocumentImporter()
    private let cloudStorage = CloudStorageManager.shared

    // MARK: - Filtering & Sorting

    func filteredDocuments(_ documents: [Document]) -> [Document] {
        var result = documents

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.author.lowercased().contains(query)
            }
        }

        switch sortOption {
        case .recentlyAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
        case .recentlyOpened:
            result.sort { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .author:
            result.sort { $0.author.localizedCompare($1.author) == .orderedAscending }
        }

        return result
    }

    // MARK: - Import Actions

    func startFilePicker(for types: [UTType]) {
        documentPickerTypes = types
        showDocumentPicker = true
    }

    func importFile(url: URL, context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await importer.importFile(url: url)
            let document = createDocument(from: result)

            // Save original file to cloud if it has file data
            if let fileData = result.fileData {
                let cloudFileName = "\(document.id.uuidString).\(url.pathExtension)"
                Task {
                    do {
                        let _ = try await cloudStorage.save(fileData: fileData, fileName: cloudFileName)
                        await MainActor.run {
                            document.cloudFileName = cloudFileName
                            document.cloudStatus = .uploaded
                        }
                    } catch {
                        // Cloud save failed; document still works with extracted text
                    }
                }
            }

            context.insert(document)

            // Create initial reading progress
            let progress = ReadingProgress(document: document)
            context.insert(progress)

            try context.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func importWebArticle(context: ModelContext) async {
        guard !importURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a URL"
            showError = true
            return
        }

        var urlString = importURL.trimmingCharacters(in: .whitespaces)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await importer.importWebArticle(urlString: urlString)
            let document = createDocument(from: result)
            context.insert(document)

            let progress = ReadingProgress(document: document)
            context.insert(progress)

            try context.save()
            importURL = ""
            showURLInput = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func importPlainText(context: ModelContext) {
        guard !importTextContent.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter some text"
            showError = true
            return
        }

        let result = importer.importPlainText(
            text: importTextContent,
            title: importTextTitle
        )
        let document = createDocument(from: result)
        context.insert(document)

        let progress = ReadingProgress(document: document)
        context.insert(progress)

        try? context.save()
        importTextTitle = ""
        importTextContent = ""
        showTextInput = false
    }

    func deleteDocument(_ document: Document, context: ModelContext) {
        // Delete cloud file if exists
        if let cloudFileName = document.cloudFileName {
            Task {
                try? await cloudStorage.deleteFromCloud(fileName: cloudFileName)
            }
        }
        context.delete(document)
        try? context.save()
    }

    // MARK: - Helpers

    private func createDocument(from result: ImportResult) -> Document {
        let document = Document(
            title: result.title,
            author: result.author,
            sourceType: result.sourceType,
            fullText: result.fullText,
            thumbnailData: result.thumbnailData,
            fileSize: result.fileSize,
            sourceURL: result.sourceURL
        )
        document.sectionBoundaries = result.sectionBoundaries
        document.sectionNames = result.sectionNames
        return document
    }
}
