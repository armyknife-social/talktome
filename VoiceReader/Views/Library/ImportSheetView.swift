import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportSheetView: View {
    @Bindable var viewModel: LibraryViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // File Import Section
                Section {
                    Button {
                        dismiss()
                        viewModel.startFilePicker(for: [UTType.pdf])
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import PDF")
                                    .foregroundStyle(.primary)
                                Text("Extract text from PDF documents")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        dismiss()
                        viewModel.startFilePicker(for: [UTType(filenameExtension: "epub") ?? .data])
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import EPUB")
                                    .foregroundStyle(.primary)
                                Text("Extract text from EPUB books")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                } header: {
                    Text("From Files")
                }

                // Web Import Section
                Section {
                    Button {
                        viewModel.showURLInput = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import from URL")
                                    .foregroundStyle(.primary)
                                Text("Extract article text from a webpage")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Text("From Web")
                }

                // Text Input Section
                Section {
                    Button {
                        viewModel.showTextInput = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Paste Text")
                                    .foregroundStyle(.primary)
                                Text("Type or paste text directly")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                } header: {
                    Text("From Text")
                }
            }
            .navigationTitle("Import Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showURLInput) {
                urlInputSheet
            }
            .sheet(isPresented: $viewModel.showTextInput) {
                textInputSheet
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - URL Input Sheet

    private var urlInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/article", text: $viewModel.importURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                } header: {
                    Text("Article URL")
                } footer: {
                    Text("Enter the URL of a web article to extract its text")
                }
            }
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.showURLInput = false
                        viewModel.importURL = ""
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        Task {
                            await viewModel.importWebArticle(context: modelContext)
                            if !viewModel.showError {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.importURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Text Input Sheet

    private var textInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.importTextTitle)
                } header: {
                    Text("Title")
                }

                Section {
                    TextEditor(text: $viewModel.importTextContent)
                        .frame(minHeight: 200)
                } header: {
                    Text("Content")
                } footer: {
                    Text("Paste or type the text you want to listen to")
                }
            }
            .navigationTitle("Paste Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        viewModel.showTextInput = false
                        viewModel.importTextTitle = ""
                        viewModel.importTextContent = ""
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") {
                        viewModel.importPlainText(context: modelContext)
                        if !viewModel.showError {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.importTextContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
