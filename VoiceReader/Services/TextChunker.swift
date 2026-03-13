import Foundation

struct TextChunk: Identifiable, Equatable {
    let id: Int
    let text: String
    let range: Range<String.Index>
    let characterOffset: Int

    static func == (lhs: TextChunk, rhs: TextChunk) -> Bool {
        lhs.id == rhs.id && lhs.characterOffset == rhs.characterOffset
    }
}

enum TextChunker {
    /// Splits text into sentence-level chunks for sequential TTS playback
    static func splitIntoSentences(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var index = 0

        nsString.enumerateSubstrings(in: fullRange, options: .bySentences) { substring, substringRange, _, _ in
            guard let substring = substring,
                  !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let range = Range(substringRange, in: text) else { return }

            chunks.append(TextChunk(
                id: index,
                text: substring,
                range: range,
                characterOffset: substringRange.location
            ))
            index += 1
        }

        // If no sentences were found, treat the whole text as one chunk
        if chunks.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(TextChunk(
                id: 0,
                text: text,
                range: text.startIndex..<text.endIndex,
                characterOffset: 0
            ))
        }

        return chunks
    }

    /// Splits text into paragraph-level chunks
    static func splitIntoParagraphs(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        var currentOffset = 0
        var index = 0

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                currentOffset += paragraph.count + 2
                continue
            }

            let startIndex = text.index(text.startIndex, offsetBy: min(currentOffset, text.count))
            let endOffset = min(currentOffset + paragraph.count, text.count)
            let endIndex = text.index(text.startIndex, offsetBy: endOffset)

            chunks.append(TextChunk(
                id: index,
                text: trimmed,
                range: startIndex..<endIndex,
                characterOffset: currentOffset
            ))

            currentOffset += paragraph.count + 2
            index += 1
        }

        return chunks
    }

    /// Finds the sentence chunk containing the given character offset
    static func chunkIndex(forCharacterOffset offset: Int, in chunks: [TextChunk]) -> Int? {
        for (index, chunk) in chunks.enumerated() {
            let chunkEnd = chunk.characterOffset + chunk.text.count
            if offset >= chunk.characterOffset && offset < chunkEnd {
                return index
            }
        }
        // If offset is at the very end, return last chunk
        if let last = chunks.last, offset >= last.characterOffset {
            return chunks.count - 1
        }
        return chunks.isEmpty ? nil : 0
    }

    /// Calculates the character offset for a skip forward/backward in seconds
    static func skipOffset(from currentOffset: Int, seconds: TimeInterval, speed: Float, in text: String) -> Int {
        // Estimate characters per second based on average TTS speed
        // At 1x speed, roughly 2.5 words/second, ~15 chars/second
        let charsPerSecond = 15.0 * Double(speed)
        let charDelta = Int(seconds * charsPerSecond)
        let newOffset = currentOffset + charDelta
        return max(0, min(newOffset, text.count))
    }
}
