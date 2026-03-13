import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.dateAdded, order: .reverse) private var documents: [Document]
    @State private var viewModel = LibraryViewModel()
    @Bindable var playerViewModel: PlayerViewModel
    @State private var selectedDocument: Document?
    @State private var showReader: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: AppConstants.UI.gridSpacing),
        GridItem(.flexible(), spacing: AppConstants.UI.gridSpacing)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                if documents.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    documentGridView
                }

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        importFAB
                    }
                }
                .padding()
                .padding(.bottom, playerViewModel.isActive ? AppConstants.UI.miniPlayerHeight : 0)
            }
            .navigationTitle("Your Library")
            .searchable(text: $viewModel.searchText, prompt: "Search documents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    sortMenu
                }
            }
            .sheet(isPresented: $viewModel.showImportSheet) {
                ImportSheetView(viewModel: viewModel, modelContext: modelContext)
            }
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPickerView(
                    contentTypes: viewModel.documentPickerTypes,
                    onPick: { url in
                        viewModel.showDocumentPicker = false
                        Task {
                            await viewModel.importFile(url: url, context: modelContext)
                        }
                    },
                    onCancel: {
                        viewModel.showDocumentPicker = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showReader) {
                if let document = selectedDocument {
                    ReaderView(playerViewModel: playerViewModel, document: document)
                        .environment(\.modelContext, modelContext)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { viewModel.showError = false }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
    }

    // MARK: - Document Grid

    private var documentGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppConstants.UI.gridSpacing) {
                ForEach(viewModel.filteredDocuments(documents)) { document in
                    DocumentCardView(document: document)
                        .onTapGesture {
                            selectedDocument = document
                            showReader = true
                        }
                        .contextMenu {
                            Button {
                                selectedDocument = document
                                showReader = true
                            } label: {
                                Label("Open", systemImage: "book")
                            }

                            Button {
                                playerViewModel.play(document: document)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }

                            Divider()

                            Button(role: .destructive) {
                                viewModel.deleteDocument(document, context: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
            .padding(.bottom, playerViewModel.isActive ? AppConstants.UI.miniPlayerHeight + 16 : 0)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "books.vertical")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("Your Library is Empty")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import a PDF, EPUB, web article, or paste text to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.showImportSheet = true
            } label: {
                Label("Import Your First Document", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - FAB

    private var importFAB: some View {
        Button {
            viewModel.showImportSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Importing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
