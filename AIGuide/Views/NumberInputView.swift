// Number Input View - Place Code Lookup

import SwiftUI

struct NumberInputView: View {
    @StateObject private var numberService = NumberInputService.shared
    @State private var showResult = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    private let accent = Color(red: 0.12, green: 0.40, blue: 0.24)
    private let warmAccent = Color(red: 0.88, green: 0.33, blue: 0.13)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    headerSection

                    // Number input
                    inputSection

                    // Result
                    if let poi = numberService.matchedPOI {
                        resultSection(poi)
                    }

                    // Recent lookups
                    if !numberService.recentLookups.isEmpty {
                        recentSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.string("number.lookup.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
            }
            .alert(L10n.string("number.lookup.error.title"), isPresented: $numberService.showError) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            } message: {
                Text(numberService.errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 9) {
            Image(systemName: "number.square")
                .font(.system(size: 42))
                .foregroundStyle(accent)
            
            Text(L10n.string("number.lookup.heading"))
                .font(.title2)
                .fontWeight(.bold)
            
            Text(L10n.string("number.lookup.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 12) {
            // Number input field
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                
                TextField(L10n.string("number.lookup.placeholder"), text: $numberService.inputNumber)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.title2)
                    .focused($isInputFocused)
                    .onChange(of: numberService.inputNumber) { _, newValue in
                        if newValue.count >= 3 {
                            Task {
                                await numberService.lookup(newValue)
                            }
                        }
                    }
                
                if !numberService.inputNumber.isEmpty {
                    Button(action: { numberService.clearInput() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Lookup button
            Button(action: {
                Task {
                    await numberService.lookup(numberService.inputNumber)
                }
            }) {
                HStack {
                    if numberService.isSearching {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    Text(L10n.string("查询"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(numberService.inputNumber.isEmpty ? .gray : accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(numberService.inputNumber.isEmpty || numberService.isSearching)
            
            // Quick numbers
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.string("number.lookup.suggestions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(numberService.suggestedLookups) { suggestion in
                            Button(action: {
                                numberService.inputNumber = suggestion.code
                                Task {
                                    await numberService.lookup(suggestion.code)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.code)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text(suggestion.poi.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .frame(maxWidth: 128, alignment: .leading)
                                .background(accent.opacity(0.1))
                                .foregroundStyle(accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Result Section
    private func resultSection(_ poi: POI) -> some View {
        VStack(spacing: 16) {
            // Success header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(L10n.string("number.lookup.found"))
                    .font(.headline)
                Spacer()
            }
            
            // POI card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(poi.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(poi.category.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: categoryIcon(poi.category))
                        .font(.system(size: 40))
                        .foregroundStyle(accent)
                }
                
                Divider()
                
                Text(poi.description)
                    .font(.body)
                
                // Source
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.secondary)
                    Text(L10n.format("来源：%@", poi.source.name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Start guide
                }) {
                    Label(L10n.string("开始讲解"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: {
                    // View on map
                }) {
                    Label(L10n.string("地图定位"), systemImage: "map")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(warmAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Recent Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近查询")
                    .font(.headline)
                
                Spacer()
                
                Button(L10n.string("清空")) {
                    numberService.clearRecentLookups()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            ForEach(numberService.recentLookups.prefix(5)) { lookup in
                Button(action: {
                    numberService.inputNumber = lookup.number
                    Task {
                        await numberService.lookup(lookup.number)
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("#\(lookup.number)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(lookup.poiName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(lookup.formattedTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button(action: { numberService.removeLookup(lookup) }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Helper
    private func categoryIcon(_ category: POICategory) -> String {
        switch category {
        case .palace: return "building.2.fill"
        case .temple: return "building.columns.fill"
        case .garden: return "leaf.fill"
        case .museum: return "books.vertical.fill"
        case .exhibit: return "photo.fill"
        case .building: return "building.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    NumberInputView()
}
