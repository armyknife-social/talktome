import SwiftUI

struct MiniPlayerView: View {
    @Bindable var playerViewModel: PlayerViewModel
    @State private var showFullPlayer: Bool = false

    var body: some View {
        if playerViewModel.isActive {
            VStack(spacing: 0) {
                // Progress bar at top
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * playerViewModel.progress, height: 2)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Document icon
                    documentIcon

                    // Title and position
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playerViewModel.currentDocument?.title ?? "")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(playerViewModel.currentPositionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Play/Pause button
                    Button {
                        playerViewModel.playPause()
                    } label: {
                        Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }

                    // Close button
                    Button {
                        playerViewModel.stop()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(height: AppConstants.UI.miniPlayerHeight)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
            .contentShape(Rectangle())
            .onTapGesture {
                showFullPlayer = true
            }
            .sheet(isPresented: $showFullPlayer) {
                FullPlayerView(playerViewModel: playerViewModel)
            }
        }
    }

    private var documentIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)

            Image(systemName: playerViewModel.currentDocument?.sourceType.iconName ?? "doc.fill")
                .foregroundStyle(Color.accentColor)
        }
    }
}
