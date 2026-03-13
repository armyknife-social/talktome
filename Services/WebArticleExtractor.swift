import Foundation

struct ExtractedArticle {
    let title: String
    let author: String
    let content: String
    let sourceURL: String
}

enum WebArticleExtractorError: LocalizedError {
    case invalidURL
    case fetchFailed(String)
    case noContentFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .fetchFailed(let reason): return "Failed to fetch article: \(reason)"
        case .noContentFound: return "No article content found at this URL"
        }
    }
}

final class WebArticleExtractor {

    /// Extracts article text from a given URL
    func extract(from urlString: String) async throws -> ExtractedArticle {
        guard let url = URL(string: urlString) else {
            throw WebArticleExtractorError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WebArticleExtractorError.fetchFailed("Server returned an error")
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            throw WebArticleExtractorError.fetchFailed("Could not decode response")
        }

        let title = extractTitle(from: html)
        let author = extractAuthor(from: html)
        let content = extractContent(from: html)

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WebArticleExtractorError.noContentFound
        }

        return ExtractedArticle(
            title: title,
            author: author,
            content: content,
            sourceURL: urlString
        )
    }

    // MARK: - Title Extraction

    private func extractTitle(from html: String) -> String {
        // Try <title> tag first
        if let title = extractTagContent(html, tag: "title") {
            // Clean up common title suffixes like " - Site Name" or " | Site Name"
            let separators = [" | ", " - ", " — ", " – "]
            for sep in separators {
                if let range = title.range(of: sep) {
                    let prefix = String(title[title.startIndex..<range.lowerBound])
                    if prefix.count > 5 { return prefix.trimmingCharacters(in: .whitespaces) }
                }
            }
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try og:title meta tag
        if let ogTitle = extractMetaContent(html, property: "og:title") {
            return ogTitle
        }

        return "Web Article"
    }

    // MARK: - Author Extraction

    private func extractAuthor(from html: String) -> String {
        // Try meta author tag
        if let author = extractMetaContent(html, name: "author") {
            return author
        }
        if let author = extractMetaContent(html, property: "article:author") {
            return author
        }
        return ""
    }

    // MARK: - Content Extraction

    private func extractContent(from html: String) -> String {
        // Strategy: Find the best content container and extract text from it

        // 1. Try <article> tag
        if let articleContent = extractElementContent(html, tag: "article") {
            let text = stripHTML(articleContent)
            if text.count > 200 { return cleanupText(text) }
        }

        // 2. Try <main> tag
        if let mainContent = extractElementContent(html, tag: "main") {
            let text = stripHTML(mainContent)
            if text.count > 200 { return cleanupText(text) }
        }

        // 3. Try common article class/id patterns
        let contentPatterns = [
            "class=\"article-body\"", "class=\"article-content\"", "class=\"post-content\"",
            "class=\"entry-content\"", "class=\"story-body\"", "class=\"content-body\"",
            "id=\"article-body\"", "id=\"article-content\"", "id=\"content\""
        ]

        for pattern in contentPatterns {
            if let content = extractDivWithAttribute(html, attribute: pattern) {
                let text = stripHTML(content)
                if text.count > 200 { return cleanupText(text) }
            }
        }

        // 4. Fallback: find the largest text block by extracting all <p> tags
        let paragraphs = extractAllParagraphs(html)
        let combined = paragraphs.joined(separator: "\n\n")
        if !combined.isEmpty { return cleanupText(combined) }

        // 5. Last resort: strip all HTML
        return cleanupText(stripHTML(html))
    }

    // MARK: - HTML Parsing Helpers

    private func extractTagContent(_ html: String, tag: String) -> String? {
        let openTag = "<\(tag)"
        guard let openRange = html.range(of: openTag, options: .caseInsensitive) else { return nil }
        let afterOpen = html[openRange.upperBound...]
        guard let closeBracket = afterOpen.firstIndex(of: ">") else { return nil }
        let contentStart = afterOpen.index(after: closeBracket)
        let closeTag = "</\(tag)>"
        guard let closeRange = html[contentStart...].range(of: closeTag, options: .caseInsensitive) else { return nil }
        return String(html[contentStart..<closeRange.lowerBound])
    }

    private func extractMetaContent(_ html: String, property: String) -> String? {
        let patterns = [
            "property=\"\(property)\"",
            "name=\"\(property)\""
        ]
        for pattern in patterns {
            guard let range = html.range(of: pattern, options: .caseInsensitive) else { continue }
            // Look for content attribute nearby
            let searchStart = html.index(range.lowerBound, offsetBy: -200, limitedBy: html.startIndex) ?? html.startIndex
            let searchEnd = html.index(range.upperBound, offsetBy: 200, limitedBy: html.endIndex) ?? html.endIndex
            let snippet = String(html[searchStart..<searchEnd])
            if let contentRange = snippet.range(of: "content=\"", options: .caseInsensitive) {
                let afterContent = snippet[contentRange.upperBound...]
                if let endQuote = afterContent.firstIndex(of: "\"") {
                    return String(afterContent[afterContent.startIndex..<endQuote])
                }
            }
        }
        return nil
    }

    private func extractMetaContent(_ html: String, name: String) -> String? {
        return extractMetaContent(html, property: name)
    }

    private func extractElementContent(_ html: String, tag: String) -> String? {
        let openTag = "<\(tag)"
        guard let openRange = html.range(of: openTag, options: .caseInsensitive) else { return nil }
        let afterOpen = html[openRange.upperBound...]
        guard let closeBracket = afterOpen.firstIndex(of: ">") else { return nil }
        let contentStart = afterOpen.index(after: closeBracket)
        let closeTag = "</\(tag)>"
        guard let closeRange = html[contentStart...].range(of: closeTag, options: .caseInsensitive) else { return nil }
        return String(html[contentStart..<closeRange.lowerBound])
    }

    private func extractDivWithAttribute(_ html: String, attribute: String) -> String? {
        guard let attrRange = html.range(of: attribute, options: .caseInsensitive) else { return nil }
        // Find the opening < before this attribute
        let beforeAttr = html[html.startIndex..<attrRange.lowerBound]
        guard let openBracket = beforeAttr.lastIndex(of: "<") else { return nil }
        // Find closing >
        let afterAttr = html[attrRange.upperBound...]
        guard let closeBracket = afterAttr.firstIndex(of: ">") else { return nil }
        let contentStart = html.index(after: closeBracket)
        // Determine the tag name
        let tagContent = html[html.index(after: openBracket)..<attrRange.lowerBound]
        let tagName = String(tagContent.prefix(while: { !$0.isWhitespace }))
        let closeTag = "</\(tagName)>"
        // Find matching close tag (simplified - finds first occurrence)
        guard let closeRange = html[contentStart...].range(of: closeTag, options: .caseInsensitive) else { return nil }
        return String(html[contentStart..<closeRange.lowerBound])
    }

    private func extractAllParagraphs(_ html: String) -> [String] {
        var paragraphs: [String] = []
        var searchRange = html.startIndex..<html.endIndex

        while let openRange = html.range(of: "<p", options: .caseInsensitive, range: searchRange) {
            let afterOpen = html[openRange.upperBound...]
            guard let closeBracket = afterOpen.firstIndex(of: ">") else { break }
            let contentStart = html.index(after: closeBracket)
            if let closeRange = html[contentStart...].range(of: "</p>", options: .caseInsensitive) {
                let pContent = String(html[contentStart..<closeRange.lowerBound])
                let text = stripHTML(pContent).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 20 {
                    paragraphs.append(text)
                }
                searchRange = closeRange.upperBound..<html.endIndex
            } else {
                break
            }
        }

        return paragraphs
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
        // Replace block tags with newlines
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "</li>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            result = result.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        // Strip all HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&#160;", with: " ")
        result = result.replacingOccurrences(of: "&#8217;", with: "'")
        result = result.replacingOccurrences(of: "&#8216;", with: "'")
        result = result.replacingOccurrences(of: "&#8220;", with: "\"")
        result = result.replacingOccurrences(of: "&#8221;", with: "\"")

        return result
    }

    private func cleanupText(_ text: String) -> String {
        var result = text
        // Collapse multiple spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
