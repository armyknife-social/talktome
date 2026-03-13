# VoiceReader — Speechify Clone for iOS

A full-featured text-to-speech reader app built with Swift 6, SwiftUI, and AVSpeechSynthesizer.

## Features

- **Document Import**: PDF, EPUB, web articles, plain text
- **High-Quality TTS**: Word-level highlighting, speed/pitch control, voice selection
- **iCloud Storage**: Original files synced via iCloud Documents; extracted text stays local
- **Reading Progress**: Bookmarks, highlights, resume from last position
- **Modern UI**: Dark/light mode, mini player, full player, library grid

## Xcode Setup Instructions

1. **Open Xcode** → File → New → Project
2. Select **iOS → App**
3. Set:
   - Product Name: `VoiceReader`
   - Team: (your team)
   - Organization Identifier: `com.voicereader`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **SwiftData**
4. Click **Create** and choose a location
5. **Delete** the auto-generated `ContentView.swift` and `Item.swift`
6. **Drag** all files from the `VoiceReader/` source directory into the Xcode project navigator (check "Copy items if needed")
7. **Add Entitlements**: Select the project target → Signing & Capabilities → + Capability → iCloud → check "iCloud Documents". The container should be `iCloud.com.voicereader.documents`.
8. Ensure the deployment target is **iOS 17.0+**
9. **Build and Run** on a simulator or device

## Architecture

- **MVVM** with `@Observable` view models
- **SwiftData** for persistence (`@Model`, `@Query`)
- **AVSpeechSynthesizer** for TTS with delegate-based word tracking
- **iCloud Documents** for cloud file storage with `NSFileCoordinator`

## Project Structure

```
VoiceReader/
├── VoiceReaderApp.swift         — App entry point with SwiftData container
├── Info.plist                   — App configuration with iCloud containers
├── VoiceReader.entitlements     — iCloud Documents entitlement
├── Models/
│   ├── Document.swift           — Main document model
│   ├── Bookmark.swift           — Bookmark model
│   ├── Highlight.swift          — Text highlight model
│   └── ReadingProgress.swift    — Reading progress tracking
├── Services/
│   ├── TTSEngine.swift          — AVSpeechSynthesizer wrapper
│   ├── DocumentImporter.swift   — Multi-format document importer
│   ├── EPUBParser.swift         — EPUB zip/XML parser
│   ├── WebArticleExtractor.swift — Web article text extraction
│   ├── TextChunker.swift        — Sentence splitting for TTS
│   └── CloudStorageManager.swift — iCloud Documents manager
├── ViewModels/
│   ├── LibraryViewModel.swift   — Library business logic
│   ├── ReaderViewModel.swift    — Reader business logic
│   └── PlayerViewModel.swift    — Playback control logic
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift        — Main library grid
│   │   ├── DocumentCardView.swift   — Document card component
│   │   └── ImportSheetView.swift    — Import options sheet
│   ├── Reader/
│   │   ├── ReaderView.swift             — Full reader view
│   │   ├── HighlightableTextView.swift  — Highlighted text display
│   │   └── TableOfContentsView.swift    — TOC sidebar
│   ├── Player/
│   │   ├── MiniPlayerView.swift     — Bottom bar mini player
│   │   ├── FullPlayerView.swift     — Expanded player controls
│   │   └── VoicePickerView.swift    — Voice selection view
│   └── Settings/
│       └── SettingsView.swift       — App settings
└── Utilities/
    ├── Extensions.swift         — Swift/SwiftUI extensions
    └── Constants.swift          — App-wide constants
```

## CI/CD — GitHub Actions

The project includes a GitHub Actions workflow (`.github/workflows/build.yml`) that builds the app on every push to `main`.

It uses:
- `macos-15` runner with Xcode pre-installed
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate `.xcodeproj` from `project.yml`
- Builds for iOS Simulator (no code signing needed)

To build locally with XcodeGen:
```bash
brew install xcodegen
xcodegen generate
open VoiceReader.xcodeproj
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- XcodeGen (for project generation)
- No third-party runtime dependencies
