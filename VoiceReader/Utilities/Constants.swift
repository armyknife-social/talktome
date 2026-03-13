import SwiftUI

enum AppConstants {
    static let appName = "VoiceReader"
    static let iCloudContainerID = "iCloud.com.voicereader.documents"

    enum TTS {
        static let minSpeed: Float = 0.5
        static let maxSpeed: Float = 4.0
        static let defaultSpeed: Float = 1.0
        static let minPitch: Float = 0.5
        static let maxPitch: Float = 2.0
        static let defaultPitch: Float = 1.0
        static let skipInterval: TimeInterval = 15.0

        static let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]

        // AVSpeechUtterance rate mapping: 0.0 (slowest) to 1.0 (fastest)
        // Normal rate is ~0.5, but that's actually quite fast
        static func utteranceRate(forSpeed speed: Float) -> Float {
            // Map 0.5x-4.0x to AVSpeechUtterance rate range
            // 0.5x → 0.05, 1.0x → 0.15, 2.0x → 0.35, 4.0x → 0.55
            let minRate: Float = 0.05
            let maxRate: Float = 0.55
            let normalized = (speed - minSpeed) / (maxSpeed - minSpeed)
            return minRate + normalized * (maxRate - minRate)
        }
    }

    enum Reader {
        static let minFontSize: CGFloat = 12
        static let maxFontSize: CGFloat = 36
        static let defaultFontSize: CGFloat = 18
    }

    enum UI {
        static let cardCornerRadius: CGFloat = 12
        static let miniPlayerHeight: CGFloat = 64
        static let gridSpacing: CGFloat = 16
        static let cardShadowRadius: CGFloat = 4
    }
}

enum ReaderBackground: String, CaseIterable {
    case white
    case sepia
    case dark

    var backgroundColor: Color {
        switch self {
        case .white: return .white
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.87)
        case .dark: return Color(red: 0.15, green: 0.15, blue: 0.15)
        }
    }

    var textColor: Color {
        switch self {
        case .white: return .black
        case .sepia: return Color(red: 0.3, green: 0.25, blue: 0.2)
        case .dark: return .white
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

    var iconColor: Color {
        switch self {
        case .white: return .gray
        case .sepia: return Color(red: 0.7, green: 0.6, blue: 0.4)
        case .dark: return .primary
        }
    }
}

enum SortOption: String, CaseIterable {
    case recentlyAdded = "Recently Added"
    case recentlyOpened = "Recently Opened"
    case title = "Title"
    case author = "Author"
}
