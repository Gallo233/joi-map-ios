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
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
            ?? AVSpeechSynthesisVoice(language: speechLanguage(for: voice.locale))
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

    private func speechLanguage(for locale: String) -> String {
        switch locale {
        case "zh-HK":
            return "zh-HK"
        case "zh-TW":
            return "zh-TW"
        default:
            return "zh-CN"
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
    @State private var searchText = ""
    @State private var selectedGender = "All"
    @State private var selectedLocale = "All"

    init(
        selectedVoice: Binding<EdgeVoice>,
        onVoiceSelected: @escaping () -> Void = {}
    ) {
        self._selectedVoice = selectedVoice
        self.onVoiceSelected = onVoiceSelected
    }
    
    let genders = ["All", "Female", "Male"]
    let locales = ["All", "zh-CN", "zh-HK", "zh-TW", "zh-CN-SC"]
    
    var filteredVoices: [EdgeVoice] {
        EdgeVoice.chineseVoices.filter { voice in
            let matchesGender = selectedGender == "All" || voice.gender == selectedGender
            let matchesLocale = selectedLocale == "All" || voice.locale == selectedLocale
            let matchesSearch = searchText.isEmpty || 
                voice.displayName.localizedCaseInsensitiveContains(searchText) ||
                voice.localizedDescription.localizedCaseInsensitiveContains(searchText) ||
                voice.name.localizedCaseInsensitiveContains(searchText)
            return matchesGender && matchesLocale && matchesSearch
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Gender filter
                        ForEach(genders, id: \.self) { gender in
                            Button(action: { selectedGender = gender }) {
                                Text(genderDisplayName(gender))
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedGender == gender ? .blue : .gray.opacity(0.15))
                                    .foregroundStyle(selectedGender == gender ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Divider()
                            .frame(height: 20)
                        
                        // Locale filter
                        ForEach(locales, id: \.self) { locale in
                            Button(action: { selectedLocale = locale }) {
                                Text(localeDisplayName(locale))
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedLocale == locale ? .blue : .gray.opacity(0.15))
                                    .foregroundStyle(selectedLocale == locale ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(.ultraThinMaterial)
                
                // Voice list
                List(filteredVoices) { voice in
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
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: Text(L10n.string("voice.search.placeholder")))
            }
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

    private func genderDisplayName(_ gender: String) -> String {
        switch gender {
        case "Female": return L10n.string("voice.gender.female")
        case "Male": return L10n.string("voice.gender.male")
        default: return L10n.string("voice.gender.all")
        }
    }
    
    private func localeDisplayName(_ locale: String) -> String {
        switch locale {
        case "zh-CN": return L10n.string("voice.locale.mandarin")
        case "zh-HK": return L10n.string("voice.locale.cantonese")
        case "zh-TW": return L10n.string("voice.locale.taiwan")
        case "zh-CN-SC": return L10n.string("voice.locale.sichuan")
        default: return L10n.string("voice.gender.all")
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
            // Gender icon
            Image(systemName: voice.gender == "Female" ? "person.fill" : "person")
                .font(.title2)
                .foregroundStyle(voice.gender == "Female" ? .pink : .blue)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(voice.displayName)
                        .font(.headline)
                    
                    Text(voice.locale)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.2))
                        .clipShape(Capsule())
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                
                Text(voice.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Play sample button
            Button(action: onPreview) {
                Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle")
                    .font(.title2)
                    .foregroundStyle(isPreviewing ? .orange : .blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    VoicePickerView(selectedVoice: .constant(.default))
}
