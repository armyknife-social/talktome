import SwiftUI

struct TableOfContentsView: View {
    let sections: [(name: String, offset: Int)]
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if sections.isEmpty {
                    ContentUnavailableView(
                        "No Table of Contents",
                        systemImage: "list.bullet",
                        description: Text("This document doesn't have a table of contents")
                    )
                } else {
                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        Button {
                            onSelect(section.offset)
                            dismiss()
                        } label: {
                            HStack {
                                Text(section.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            }
            .navigationTitle("Table of Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
