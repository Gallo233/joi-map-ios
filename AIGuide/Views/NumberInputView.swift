// Number Input View - Museum Exhibit Lookup

import SwiftUI

struct NumberInputView: View {
    @StateObject private var numberService = NumberInputService.shared
    @State private var showResult = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
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
                
                Spacer()
            }
            .padding()
            .navigationTitle("编号查询")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("查询失败", isPresented: $numberService.showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(numberService.errorMessage)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "number.square")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("输入展品编号")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("在展品旁边的标签上找到编号，输入即可查看讲解")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 16) {
            // Number input field
            HStack {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                
                TextField("输入编号", text: $numberService.inputNumber)
                    .keyboardType(.numberPad)
                    .font(.title2)
                    .focused($isInputFocused)
                    .onChange(of: numberService.inputNumber) { _, newValue in
                        // Auto-lookup after 3 digits
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
                    
                    Text("查询")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(numberService.inputNumber.isEmpty ? .gray : .blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(numberService.inputNumber.isEmpty || numberService.isSearching)
            
            // Quick numbers
            VStack(alignment: .leading, spacing: 8) {
                Text("常用编号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["001", "002", "003", "100", "101", "200"], id: \.self) { number in
                            Button(action: {
                                numberService.inputNumber = number
                                Task {
                                    await numberService.lookup(number)
                                }
                            }) {
                                Text(number)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
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
                Text("找到展品")
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
                        .foregroundStyle(.blue)
                }
                
                Divider()
                
                Text(poi.description)
                    .font(.body)
                
                // Source
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.secondary)
                    Text("来源：\(poi.source.name)")
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
                    Label("开始讲解", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button(action: {
                    // View on map
                }) {
                    Label("地图定位", systemImage: "map")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
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
                
                Button("清空") {
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
