import SwiftUI

// MARK: - Color Extensions

extension Color {
    static func highlightColor(for highlightColor: HighlightColor) -> Color {
        switch highlightColor {
        case .yellow: return Color.yellow.opacity(0.4)
        case .green: return Color.green.opacity(0.4)
        case .blue: return Color.blue.opacity(0.4)
        case .pink: return Color.pink.opacity(0.4)
        case .orange: return Color.orange.opacity(0.4)
        }
    }

    static func solidHighlightColor(for highlightColor: HighlightColor) -> Color {
        switch highlightColor {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .orange: return .orange
        }
    }
}

// MARK: - String Extensions

extension String {
    func sentenceRanges() -> [(range: Range<String.Index>, text: String)] {
        var results: [(range: Range<String.Index>, text: String)] = []
        let nsString = self as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        nsString.enumerateSubstrings(in: fullRange, options: .bySentences) { substring, substringRange, _, _ in
            guard let substring = substring,
                  let range = Range(substringRange, in: self) else { return }
            results.append((range: range, text: substring))
        }

        if results.isEmpty && !self.isEmpty {
            results.append((range: self.startIndex..<self.endIndex, text: self))
        }

        return results
    }

    func truncated(to maxLength: Int) -> String {
        if self.count <= maxLength { return self }
        return String(self.prefix(maxLength)) + "…"
    }

    var wordCount: Int {
        self.split(separator: " ").count
    }
}

// MARK: - Date Extensions

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var shortDuration: String {
        let minutes = Int(self) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)m"
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cardCornerRadius))
            .shadow(color: .black.opacity(0.1), radius: AppConstants.UI.cardShadowRadius, x: 0, y: 2)
    }
}

// MARK: - Int64 Extensions

extension Int64 {
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
