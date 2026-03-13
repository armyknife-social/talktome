import Foundation

struct EPUBChapter {
    let title: String
    let content: String
    let order: Int
}

struct EPUBMetadata {
    var title: String = "Untitled"
    var author: String = ""
    var chapters: [EPUBChapter] = []
}

enum EPUBParserError: LocalizedError {
    case invalidArchive
    case missingContainer
    case missingContentOPF
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArchive: return "Invalid EPUB file"
        case .missingContainer: return "Missing container.xml in EPUB"
        case .missingContentOPF: return "Missing content.opf in EPUB"
        case .parsingFailed(let detail): return "EPUB parsing failed: \(detail)"
        }
    }
}

final class EPUBParser {

    /// Parses an EPUB file from data and returns metadata with extracted text
    func parse(data: Data) async throws -> EPUBMetadata {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let epubURL = tempDir.appendingPathComponent("book.epub")
        try data.write(to: epubURL)

        return try await parse(url: epubURL, extractionDir: tempDir)
    }

    /// Parses an EPUB file at the given URL
    func parse(url: URL) async throws -> EPUBMetadata {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        return try await parse(url: url, extractionDir: tempDir)
    }

    private func parse(url: URL, extractionDir: URL) async throws -> EPUBMetadata {
        // EPUB is a ZIP archive - extract it using Process or manual zip parsing
        let extractedDir = extractionDir.appendingPathComponent("extracted")
        try FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)

        // Use built-in zip extraction via NSFileCoordinator approach
        // For iOS, we'll manually parse the ZIP structure
        try extractZIP(from: url, to: extractedDir)

        // Parse container.xml to find content.opf path
        let containerURL = extractedDir.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBParserError.missingContainer
        }

        let containerXML = try String(contentsOf: containerURL, encoding: .utf8)
        let opfPath = parseContainerForOPFPath(containerXML)
        guard let opfPath = opfPath else {
            throw EPUBParserError.missingContentOPF
        }

        let opfURL = extractedDir.appendingPathComponent(opfPath)
        let opfDir = opfURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBParserError.missingContentOPF
        }

        let opfXML = try String(contentsOf: opfURL, encoding: .utf8)

        var metadata = EPUBMetadata()
        metadata.title = extractOPFMetadata(opfXML, tag: "dc:title") ?? extractOPFMetadata(opfXML, tag: "title") ?? "Untitled"
        metadata.author = extractOPFMetadata(opfXML, tag: "dc:creator") ?? extractOPFMetadata(opfXML, tag: "creator") ?? ""

        // Extract spine items (reading order)
        let manifestItems = parseManifest(opfXML)
        let spineOrder = parseSpine(opfXML)

        var chapters: [EPUBChapter] = []
        for (order, idref) in spineOrder.enumerated() {
            guard let href = manifestItems[idref] else { continue }
            let contentURL = opfDir.appendingPathComponent(href)
            guard FileManager.default.fileExists(atPath: contentURL.path) else { continue }

            do {
                let html = try String(contentsOf: contentURL, encoding: .utf8)
                let text = stripHTML(html)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                let chapterTitle = extractHTMLTitle(html) ?? "Chapter \(order + 1)"
                chapters.append(EPUBChapter(title: chapterTitle, content: trimmed, order: order))
            } catch {
                continue
            }
        }

        metadata.chapters = chapters
        return metadata
    }

    // MARK: - ZIP Extraction (simplified for EPUB)

    private func extractZIP(from zipURL: URL, to destinationURL: URL) throws {
        // Use Foundation's built-in decompression
        // EPUBs are ZIP files - we can use a simple approach
        guard let archive = try? Data(contentsOf: zipURL) else {
            throw EPUBParserError.invalidArchive
        }

        // Simple ZIP parser for EPUB files
        try SimpleZIPExtractor.extract(data: archive, to: destinationURL)
    }

    // MARK: - XML Parsing Helpers

    private func parseContainerForOPFPath(_ xml: String) -> String? {
        // Look for <rootfile full-path="..." />
        guard let range = xml.range(of: "full-path=\"") else { return nil }
        let afterAttr = xml[range.upperBound...]
        guard let endQuote = afterAttr.firstIndex(of: "\"") else { return nil }
        return String(afterAttr[afterAttr.startIndex..<endQuote])
    }

    private func extractOPFMetadata(_ xml: String, tag: String) -> String? {
        let openTag = "<\(tag)"
        guard let openRange = xml.range(of: openTag) else { return nil }
        let afterOpen = xml[openRange.upperBound...]
        guard let closeBracket = afterOpen.firstIndex(of: ">") else { return nil }
        let contentStart = afterOpen.index(after: closeBracket)
        let closeTag = "</\(tag)>"
        guard let closeRange = xml[contentStart...].range(of: closeTag) else { return nil }
        let content = String(xml[contentStart..<closeRange.lowerBound])
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseManifest(_ xml: String) -> [String: String] {
        // Extract <item id="..." href="..." /> entries from <manifest>
        var items: [String: String] = [:]
        var searchRange = xml.startIndex..<xml.endIndex

        while let itemRange = xml.range(of: "<item ", range: searchRange) {
            let afterItem = xml[itemRange.upperBound...]
            guard let endTag = afterItem.range(of: "/>") ?? afterItem.range(of: ">") else { break }
            let attributes = String(xml[itemRange.upperBound..<endTag.lowerBound])

            if let id = extractAttribute("id", from: attributes),
               let href = extractAttribute("href", from: attributes) {
                // Only include HTML/XHTML content files
                let mediaType = extractAttribute("media-type", from: attributes) ?? ""
                if mediaType.contains("html") || mediaType.isEmpty {
                    items[id] = href.removingPercentEncoding ?? href
                }
            }

            searchRange = endTag.upperBound..<xml.endIndex
        }

        return items
    }

    private func parseSpine(_ xml: String) -> [String] {
        var order: [String] = []
        var searchRange = xml.startIndex..<xml.endIndex

        while let itemRange = xml.range(of: "<itemref ", range: searchRange) {
            let afterItem = xml[itemRange.upperBound...]
            guard let endTag = afterItem.range(of: "/>") ?? afterItem.range(of: ">") else { break }
            let attributes = String(xml[itemRange.upperBound..<endTag.lowerBound])

            if let idref = extractAttribute("idref", from: attributes) {
                order.append(idref)
            }

            searchRange = endTag.upperBound..<xml.endIndex
        }

        return order
    }

    private func extractAttribute(_ name: String, from attributes: String) -> String? {
        let pattern = "\(name)=\""
        guard let range = attributes.range(of: pattern) else { return nil }
        let afterAttr = attributes[range.upperBound...]
        guard let endQuote = afterAttr.firstIndex(of: "\"") else { return nil }
        return String(afterAttr[afterAttr.startIndex..<endQuote])
    }

    private func extractHTMLTitle(_ html: String) -> String? {
        // Try to find <title> or first <h1>/<h2>
        for tag in ["<title>", "<h1>", "<h1 ", "<h2>", "<h2 "] {
            if let range = html.range(of: tag, options: .caseInsensitive) {
                let afterTag: Substring
                if tag.last == " " {
                    // Find closing >
                    let rest = html[range.upperBound...]
                    guard let closeBracket = rest.firstIndex(of: ">") else { continue }
                    afterTag = rest[rest.index(after: closeBracket)...]
                } else {
                    afterTag = html[range.upperBound...]
                }
                let closeTag = "</\(tag.dropFirst().prefix(while: { $0 != ">" && $0 != " " }))>"
                if let closeRange = afterTag.range(of: closeTag, options: .caseInsensitive) {
                    let text = stripHTML(String(afterTag[afterTag.startIndex..<closeRange.lowerBound]))
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        var result = html
        // Remove script and style blocks
        let blockPatterns = ["<script[^>]*>.*?</script>", "<style[^>]*>.*?</style>"]
        for pattern in blockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        // Replace block-level tags with newlines
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            result = result.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        // Strip remaining tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&#160;", with: " ")

        // Collapse multiple newlines and spaces
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Simple ZIP Extractor

enum SimpleZIPExtractor {
    struct LocalFileHeader {
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let fileNameLength: UInt16
        let extraFieldLength: UInt16
        let fileName: String
        let compressionMethod: UInt16
        let fileData: Data
    }

    static func extract(data: Data, to destinationURL: URL) throws {
        var offset = 0
        let bytes = [UInt8](data)

        while offset + 30 <= bytes.count {
            // Check for local file header signature: 0x04034b50
            guard bytes[offset] == 0x50 && bytes[offset+1] == 0x4B &&
                  bytes[offset+2] == 0x03 && bytes[offset+3] == 0x04 else {
                break
            }

            let compressionMethod = UInt16(bytes[offset+8]) | (UInt16(bytes[offset+9]) << 8)
            let compressedSize = UInt32(bytes[offset+18]) | (UInt32(bytes[offset+19]) << 8) |
                                (UInt32(bytes[offset+20]) << 16) | (UInt32(bytes[offset+21]) << 24)
            let uncompressedSize = UInt32(bytes[offset+22]) | (UInt32(bytes[offset+23]) << 8) |
                                  (UInt32(bytes[offset+24]) << 16) | (UInt32(bytes[offset+25]) << 24)
            let fileNameLength = UInt16(bytes[offset+26]) | (UInt16(bytes[offset+27]) << 8)
            let extraFieldLength = UInt16(bytes[offset+28]) | (UInt16(bytes[offset+29]) << 8)

            let nameStart = offset + 30
            let nameEnd = nameStart + Int(fileNameLength)
            guard nameEnd <= bytes.count else { break }

            let fileNameData = Data(bytes[nameStart..<nameEnd])
            let fileName = String(data: fileNameData, encoding: .utf8) ?? ""

            let dataStart = nameEnd + Int(extraFieldLength)
            let dataSize = Int(compressedSize > 0 ? compressedSize : uncompressedSize)
            let dataEnd = dataStart + dataSize
            guard dataEnd <= bytes.count else { break }

            if !fileName.isEmpty && !fileName.hasSuffix("/") {
                let fileURL = destinationURL.appendingPathComponent(fileName)
                let fileDir = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)

                let fileData = Data(bytes[dataStart..<dataEnd])

                if compressionMethod == 0 {
                    // Stored (no compression)
                    try fileData.write(to: fileURL)
                } else if compressionMethod == 8 {
                    // Deflate - use NSData decompression
                    let nsData = fileData as NSData
                    if let decompressed = try? nsData.decompressed(using: .zlib) {
                        try (decompressed as Data).write(to: fileURL)
                    } else {
                        // Try raw deflate without zlib header
                        try fileData.write(to: fileURL)
                    }
                } else {
                    try fileData.write(to: fileURL)
                }
            }

            offset = dataEnd
        }
    }
}
