import SwiftUI
import SwiftData

struct ReaderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReaderViewModel()
    @Bindable var playerViewModel: PlayerViewModel

    let document: Document

    var body: some View {
        NavigationStack {
            ZStack {
                viewModel.readerBackground.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Main reader content
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            HighlightableTextView(
                                text: document.fullText,
                                fontSize: viewModel.fontSize,
                                textColor: viewModel.readerBackground.textColor,
                                highlights: viewModel.highlights,
                                currentWordRange: playerViewModel.ttsEngine.currentWordRange,
                                currentDocument: playerViewModel.currentDocument,
                                document: document,
                                onTapWord: { offset in
                                    // Start playing from tapped word
                                    playerViewModel.play(document: document, fromOffset: offset)
                                    viewModel.updateProgress(characterOffset: offset)
                                },
                                onHighlightRequest: { start, end in
                                    viewModel.highlightStart = start
                                    viewModel.highlightEnd = end
                                    viewModel.showHighlightPicker = true
                                }
                            )
                            .padding()
                            .padding(.bottom, playerViewModel.isActive ? AppConstants.UI.miniPlayerHeight + 60 : 60)
                        }
                        .onChange(of: playerViewModel.ttsEngine.currentUtteranceIndex) { _, _ in
                            viewModel.updateProgress(characterOffset: playerViewModel.ttsEngine.currentCharacterOffset)
                        }
                    }

                    // Bottom controls
                    if !playerViewModel.isActive {
                        playButton
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(document.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        let offset = playerViewModel.ttsEngine.currentCharacterOffset
                        if viewModel.isBookmarked(at: offset) {
                            if let bookmark = viewModel.bookmarks.first(where: { abs($0.characterOffset - offset) < 50 }) {
                                viewModel.removeBookmark(bookmark)
                            }
                        } else {
                            viewModel.addBookmark(at: offset)
                        }
                    } label: {
                        Image(systemName: viewModel.isBookmarked(at: playerViewModel.ttsEngine.currentCharacterOffset) ? "bookmark.fill" : "bookmark")
                    }

                    Menu {
                        Button {
                            viewModel.showBookmarks = true
                        } label: {
                            Label("Bookmarks", systemImage: "bookmark")
                        }

                        if !viewModel.tableOfContents.isEmpty {
                            Button {
                                viewModel.showTableOfContents = true
                            } label: {
                                Label("Table of Contents", systemImage: "list.bullet")
                            }
                        }

                        Divider()

                        Button {
                            viewModel.showSettings = true
                        } label: {
                            Label("Display Settings", systemImage: "textformat.size")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showTableOfContents) {
                TableOfContentsView(
                    sections: viewModel.tableOfContents,
                    onSelect: { offset in
                        playerViewModel.play(document: document, fromOffset: offset)
                        viewModel.showTableOfContents = false
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showBookmarks) {
                bookmarksSheet
            }
            .sheet(isPresented: $viewModel.showSettings) {
                readerSettingsSheet
            }
            .sheet(isPresented: $viewModel.showHighlightPicker) {
                highlightColorPicker
            }
            .onAppear {
                viewModel.configure(document: document, context: modelContext)
            }
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            playerViewModel.play(document: document, fromOffset: viewModel.currentOffset)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Listen")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Capsule().fill(Color.accentColor))
            .shadow(color: .accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Bookmarks Sheet

    private var bookmarksSheet: some View {
        NavigationStack {
            List {
                if viewModel.bookmarks.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Tap the bookmark icon to save your place")
                    )
                } else {
                    ForEach(viewModel.bookmarks) { bookmark in
                        Button {
                            playerViewModel.play(document: document, fromOffset: bookmark.characterOffset)
                            viewModel.showBookmarks = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(bookmark.previewText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(bookmark.dateCreated.relativeDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.removeBookmark(viewModel.bookmarks[index])
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showBookmarks = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Reader Settings Sheet

    private var readerSettingsSheet: some View {
        NavigationStack {
            Form {
                Section("Font Size") {
                    HStack {
                        Button {
                            viewModel.decreaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("\(Int(viewModel.fontSize)) pt")
                            .font(.headline)
                            .monospacedDigit()

                        Spacer()

                        Button {
                            viewModel.increaseFontSize()
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }

                Section("Background") {
                    HStack(spacing: 16) {
                        ForEach(ReaderBackground.allCases, id: \.self) { bg in
                            Button {
                                viewModel.setBackground(bg)
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(bg.backgroundColor)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    viewModel.readerBackground == bg ? Color.accentColor : Color.secondary.opacity(0.3),
                                                    lineWidth: viewModel.readerBackground == bg ? 3 : 1
                                                )
                                        )
                                    Text(bg.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(viewModel.readerBackground == bg ? .primary : .secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Display Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.showSettings = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Highlight Color Picker

    private var highlightColorPicker: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Choose Highlight Color")
                    .font(.headline)

                HStack(spacing: 20) {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        Button {
                            if let start = viewModel.highlightStart,
                               let end = viewModel.highlightEnd {
                                viewModel.addHighlight(
                                    startOffset: start,
                                    endOffset: end,
                                    color: color
                                )
                            }
                            viewModel.showHighlightPicker = false
                        } label: {
                            Circle()
                                .fill(Color.solidHighlightColor(for: color))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }

                Button("Cancel") {
                    viewModel.showHighlightPicker = false
                }
                .foregroundStyle(.secondary)
            }
            .padding(32)
        }
        .presentationDetents([.height(200)])
    }
}
