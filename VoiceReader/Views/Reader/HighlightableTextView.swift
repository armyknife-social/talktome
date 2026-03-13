import SwiftUI

struct HighlightableTextView: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let highlights: [Highlight]
    let currentWordRange: NSRange?
    let currentDocument: Document?
    let document: Document
    let onTapWord: (Int) -> Void
    let onHighlightRequest: (Int, Int) -> Void

    @State private var textSelection: String = ""

    var body: some View {
        if text.isEmpty {
            ContentUnavailableView(
                "No Content",
                systemImage: "doc.text",
                description: Text("This document has no readable text")
            )
        } else {
            textContent
        }
    }

    private var textContent: some View {
        // Build an attributed text view with highlights and current word
        VStack(alignment: .leading, spacing: 0) {
            HighlightedTextLayout(
                text: text,
                fontSize: fontSize,
                textColor: textColor,
                highlights: highlights,
                currentWordRange: isCurrentDocument ? currentWordRange : nil,
                onTapWord: onTapWord
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isCurrentDocument: Bool {
        currentDocument?.id == document.id
    }
}

// MARK: - Highlighted Text Layout

struct HighlightedTextLayout: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let highlights: [Highlight]
    let currentWordRange: NSRange?
    let onTapWord: (Int) -> Void

    // Split into paragraphs for layout
    // Falls back to single \n if no \n\n separators exist, and chunks very long
    // paragraphs to avoid LazyVStack rendering issues with massive Text views
    private var paragraphs: [(text: String, offset: Int)] {
        var result: [(text: String, offset: Int)] = []

        // Try splitting by \n\n first
        let doubleNewlineParts = text.components(separatedBy: "\n\n")
        let useDoubleNewline = doubleNewlineParts.count > 1

        if useDoubleNewline {
            var currentOffset = 0
            for part in doubleNewlineParts {
                let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append((text: trimmed, offset: currentOffset))
                }
                currentOffset += part.count + 2 // +2 for \n\n
            }
        } else {
            // Fallback: split by single \n
            let singleNewlineParts = text.components(separatedBy: "\n")
            let useSingleNewline = singleNewlineParts.count > 1

            if useSingleNewline {
                var currentOffset = 0
                for part in singleNewlineParts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        result.append((text: trimmed, offset: currentOffset))
                    }
                    currentOffset += part.count + 1 // +1 for \n
                }
            } else {
                // No newlines at all — chunk into ~1000 char paragraphs at word boundaries
                let maxChunkSize = 1000
                if text.count <= maxChunkSize {
                    result.append((text: text, offset: 0))
                } else {
                    var currentOffset = 0
                    var remaining = text[...]
                    while !remaining.isEmpty {
                        if remaining.count <= maxChunkSize {
                            let chunk = String(remaining)
                            let trimmed = chunk.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                result.append((text: trimmed, offset: currentOffset))
                            }
                            break
                        }
                        // Find last space within maxChunkSize
                        let searchEnd = remaining.index(remaining.startIndex, offsetBy: maxChunkSize)
                        let searchRange = remaining.startIndex..<searchEnd
                        let breakPoint: String.Index
                        if let spaceIndex = remaining[searchRange].lastIndex(of: " ") {
                            breakPoint = remaining.index(after: spaceIndex)
                        } else {
                            breakPoint = searchEnd
                        }
                        let chunk = String(remaining[remaining.startIndex..<breakPoint])
                        let trimmed = chunk.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            result.append((text: trimmed, offset: currentOffset))
                        }
                        currentOffset += chunk.count
                        remaining = remaining[breakPoint...]
                    }
                }
            }
        }

        return result
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                buildParagraphView(text: paragraph.text, baseOffset: paragraph.offset)
            }
        }
    }

    @ViewBuilder
    private func buildParagraphView(text: String, baseOffset: Int) -> some View {
        let attributedString = buildAttributedString(for: text, baseOffset: baseOffset)
        Text(attributedString)
            .font(.system(size: fontSize, design: .serif))
            .lineSpacing(fontSize * 0.4)
            .onTapGesture { location in
                // Approximate character offset from tap
                // This is a rough estimate - in production, use UITextView for precise hit testing
                let estimatedCharsPerLine = Int(UIScreen.main.bounds.width / (fontSize * 0.55))
                let estimatedLine = Int(location.y / (fontSize * 1.6))
                let charOffset = baseOffset + estimatedLine * estimatedCharsPerLine + Int(location.x / (fontSize * 0.55))
                let clampedOffset = min(max(charOffset, baseOffset), baseOffset + text.count)
                onTapWord(clampedOffset)
            }
    }

    private func buildAttributedString(for text: String, baseOffset: Int) -> AttributedString {
        var attrString = AttributedString(text)
        attrString.foregroundColor = textColor

        // Apply highlights
        for highlight in highlights {
            let relativeStart = highlight.startOffset - baseOffset
            let relativeEnd = highlight.endOffset - baseOffset

            guard relativeStart < text.count && relativeEnd > 0 else { continue }

            let safeStart = max(0, relativeStart)
            let safeEnd = min(text.count, relativeEnd)
            guard safeStart < safeEnd else { continue }

            let startIdx = attrString.index(attrString.startIndex, offsetByCharacters: safeStart)
            let endIdx = attrString.index(attrString.startIndex, offsetByCharacters: safeEnd)

            attrString[startIdx..<endIdx].backgroundColor = Color.highlightColor(for: highlight.color)
        }

        // Apply current word highlighting
        if let wordRange = currentWordRange {
            let relativeStart = wordRange.location - baseOffset
            let relativeEnd = wordRange.location + wordRange.length - baseOffset

            if relativeStart < text.count && relativeEnd > 0 {
                let safeStart = max(0, relativeStart)
                let safeEnd = min(text.count, relativeEnd)

                if safeStart < safeEnd {
                    let startIdx = attrString.index(attrString.startIndex, offsetByCharacters: safeStart)
                    let endIdx = attrString.index(attrString.startIndex, offsetByCharacters: safeEnd)

                    attrString[startIdx..<endIdx].backgroundColor = Color.accentColor.opacity(0.3)
                    attrString[startIdx..<endIdx].foregroundColor = .primary
                    attrString[startIdx..<endIdx].font = .system(size: fontSize, weight: .semibold, design: .serif)
                }
            }
        }

        return attrString
    }
}
