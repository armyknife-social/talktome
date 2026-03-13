import SwiftUI

struct DocumentCardView: View {
    let document: Document

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail / Icon area
            thumbnailView
                .frame(height: 160)
                .clipped()

            // Info area
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(document.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if document.isCloudBacked {
                        cloudStatusIcon
                    }
                }

                if !document.author.isEmpty {
                    Text(document.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack {
                    Label(document.sourceType.rawValue, systemImage: document.sourceType.iconName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(document.formattedDuration)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                progressBar
            }
            .padding(12)
        }
        .cardStyle()
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailData = document.thumbnailData,
           let uiImage = UIImage(data: thumbnailData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                LinearGradient(
                    colors: gradientColors(for: document.sourceType),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: document.sourceType.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.9))

                    Text(document.title.prefix(30))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Cloud Status Icon

    @ViewBuilder
    private var cloudStatusIcon: some View {
        switch document.cloudStatus {
        case .local:
            EmptyView()
        case .uploading:
            Image(systemName: "icloud.and.arrow.up")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .uploaded:
            Image(systemName: "checkmark.icloud")
                .font(.caption2)
                .foregroundStyle(.green)
        case .downloading:
            Image(systemName: "icloud.and.arrow.down")
                .font(.caption2)
                .foregroundStyle(.blue)
        case .evicted:
            Image(systemName: "icloud")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * document.progressPercentage, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Helpers

    private func gradientColors(for type: DocumentSourceType) -> [Color] {
        switch type {
        case .pdf: return [Color.red.opacity(0.7), Color.red.opacity(0.4)]
        case .epub: return [Color.purple.opacity(0.7), Color.purple.opacity(0.4)]
        case .web: return [Color.blue.opacity(0.7), Color.blue.opacity(0.4)]
        case .text: return [Color.gray.opacity(0.7), Color.gray.opacity(0.4)]
        }
    }
}
