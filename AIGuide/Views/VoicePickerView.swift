import SwiftUI
import AVFoundation

private final class VoicePreviewPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var playingVoiceID: String?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func preview(_ voice: EdgeVoice) {
        if playingVoiceID == voice.id, synthesizer.isSpeaking {
            stop()
            return
        }

        stop()

        let utterance = AVSpeechUtterance(string: sampleText(for: voice.locale))
        utterance.voice = SpeechVoiceResolver.systemVoice(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = voice.gender == "Female" ? 1.04 : 0.98
        utterance.volume = 0.9

        playingVoiceID = voice.id
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        playingVoiceID = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playingVoiceID = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playingVoiceID = nil
        }
    }

    private func sampleText(for locale: String) -> String {
        switch locale {
        case "zh-HK":
            return "你好，我係 Joi Map，正為你講解附近嘅故事。"
        case "zh-TW":
            return "你好，我是 Joi Map，正在為你講解附近的故事。"
        case "zh-CN-SC":
            return "你好，我是 Joi Map，正在给你讲附近的故事。"
        default:
            return "你好，我是 Joi Map，正在为你讲解附近的故事。"
        }
    }
}

struct VoicePickerView: View {
    @Binding var selectedVoice: EdgeVoice
    let onVoiceSelected: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var previewPlayer = VoicePreviewPlayer()

    init(
        selectedVoice: Binding<EdgeVoice>,
        onVoiceSelected: @escaping () -> Void = {}
    ) {
        self._selectedVoice = selectedVoice
        self.onVoiceSelected = onVoiceSelected
    }

    private var displayVoices: [EdgeVoice] {
        var voices = EdgeVoice.recommendedGuideVoices
        if !voices.contains(where: { $0.id == selectedVoice.id }) {
            voices.insert(selectedVoice, at: 0)
        }
        return voices
    }

    private var voiceGroups: [(title: String, voices: [EdgeVoice])] {
        [
            (L10n.string("voice.locale.mandarin"), displayVoices.filter { $0.locale == "zh-CN" }),
            (L10n.string("voice.locale.cantonese"), displayVoices.filter { $0.locale == "zh-HK" }),
            (L10n.string("voice.locale.taiwan"), displayVoices.filter { $0.locale == "zh-TW" }),
            (L10n.string("voice.locale.sichuan"), displayVoices.filter { $0.locale == "zh-CN-SC" })
        ].filter { !$0.voices.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(voiceGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.voices) { voice in
                            VoiceRow(
                                voice: voice,
                                isSelected: voice.id == selectedVoice.id,
                                isPreviewing: previewPlayer.playingVoiceID == voice.id,
                                onPreview: {
                                    previewPlayer.preview(voice)
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                previewPlayer.stop()
                                selectedVoice = voice
                                onVoiceSelected()
                                dismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.string("voice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("common.done")) {
                        previewPlayer.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                previewPlayer.stop()
            }
        }
    }
}

struct VoiceRow: View {
    let voice: EdgeVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let onPreview: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(rowTint)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(voice.displayName)
                        .font(.headline)
                    
                    Text(voice.locale)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(rowTint.opacity(0.12))
                        .foregroundStyle(rowTint)
                        .clipShape(Capsule())
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                Text(voice.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(isPreviewing ? .orange : rowTint)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.string(isPreviewing ? "trip.player.pause" : "trip.player.play"))
        }
        .padding(.vertical, 4)
    }

    private var rowTint: Color {
        switch voice.locale {
        case "zh-HK":
            return .purple
        case "zh-TW":
            return .teal
        case "zh-CN-SC":
            return .orange
        default:
            return voice.gender == "Female" ? .pink : .blue
        }
    }
}

// MARK: - Preview
#Preview {
    VoicePickerView(selectedVoice: .constant(.default))
}
