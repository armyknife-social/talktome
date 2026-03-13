import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    @Bindable var playerViewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var groupedVoices: [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let groups = playerViewModel.ttsEngine.voicesGroupedByLanguage
        if searchText.isEmpty {
            return groups
        }
        let query = searchText.lowercased()
        return groups.compactMap { group in
            let filteredVoices = group.voices.filter {
                $0.name.lowercased().contains(query) ||
                $0.language.lowercased().contains(query) ||
                group.language.lowercased().contains(query)
            }
            if filteredVoices.isEmpty { return nil }
            return (language: group.language, voices: filteredVoices)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedVoices, id: \.language) { group in
                    Section(group.language) {
                        ForEach(group.voices, id: \.identifier) { voice in
                            voiceRow(voice)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search voices")
            .navigationTitle("Choose Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .font(.body)

                    qualityBadge(for: voice)
                }

                Text(voice.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Preview button
            Button {
                playerViewModel.ttsEngine.previewVoice(voice)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            // Selection indicator
            if playerViewModel.ttsEngine.currentVoice?.identifier == voice.identifier {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playerViewModel.selectVoice(voice)
        }
    }

    @ViewBuilder
    private func qualityBadge(for voice: AVSpeechSynthesisVoice) -> some View {
        let quality = voice.quality
        switch quality {
        case .premium:
            Text("Premium")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.yellow.opacity(0.2)))
                .foregroundStyle(.orange)
        case .enhanced:
            Text("Enhanced")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.2)))
                .foregroundStyle(.blue)
        default:
            EmptyView()
        }
    }
}
