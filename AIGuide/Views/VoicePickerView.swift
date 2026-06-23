// Voice Picker View - Select TTS Voice

import SwiftUI

struct VoicePickerView: View {
    @Binding var selectedVoice: EdgeVoice
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedGender = "All"
    @State private var selectedLocale = "All"
    
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
                    VoiceRow(voice: voice, isSelected: voice.id == selectedVoice.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVoice = voice
                            dismiss()
                        }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: Text("voice.search.placeholder"))
            }
            .navigationTitle("voice.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
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
            Button(action: {
                // TODO: Play sample audio
            }) {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    VoicePickerView(selectedVoice: .constant(.default))
}
