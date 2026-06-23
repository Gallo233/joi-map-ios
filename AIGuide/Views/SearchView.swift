// Search View - Search POIs, Exhibitions, Facilities

import SwiftUI

struct SearchView: View {
    @StateObject private var searchService = SearchService.shared
    @State private var showResults = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content
                if searchService.searchText.isEmpty {
                    suggestionsContent
                } else if searchService.isSearching {
                    loadingView
                } else if searchService.searchResults.isEmpty {
                    emptyResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("搜索景点、展览、设施...", text: $searchService.searchText)
                    .focused($isSearchFocused)
                    .onChange(of: searchService.searchText) { _, newValue in
                        Task {
                            await searchService.search(newValue)
                        }
                    }
                
                if !searchService.searchText.isEmpty {
                    Button(action: { searchService.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Suggestions Content
    private var suggestionsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Recent searches
                if !searchService.recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                // Quick categories
                quickCategoriesSection
                
                // Popular searches
                popularSearchesSection
            }
            .padding()
        }
    }
    
    // MARK: - Recent Searches
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近搜索")
                    .font(.headline)
                
                Spacer()
                
                Button("清空") {
                    searchService.clearRecentSearches()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            ForEach(searchService.recentSearches, id: \.self) { search in
                Button(action: {
                    searchService.searchText = search
                    Task { await searchService.search(search) }
                }) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(search)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button(action: { searchService.removeRecentSearch(search) }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Quick Categories
    private var quickCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快速查找")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                categoryButton(icon: "building.2.fill", title: "宫殿", color: .red) {
                    searchService.searchText = "宫殿"
                    Task { await searchService.search("宫殿") }
                }
                
                categoryButton(icon: "paintbrush.fill", title: "展览", color: .purple) {
                    searchService.searchText = "展览"
                    Task { await searchService.search("展览") }
                }
                
                categoryButton(icon: "figure.stand", title: "卫生间", color: .blue) {
                    searchService.searchText = "卫生间"
                    Task { await searchService.search("卫生间") }
                }
                
                categoryButton(icon: "fork.knife", title: "餐厅", color: .orange) {
                    searchService.searchText = "餐厅"
                    Task { await searchService.search("餐厅") }
                }
                
                categoryButton(icon: "bag.fill", title: "商店", color: .green) {
                    searchService.searchText = "商店"
                    Task { await searchService.search("商店") }
                }
                
                categoryButton(icon: "map.fill", title: "路线", color: .cyan) {
                    searchService.searchText = "路线"
                    Task { await searchService.search("路线") }
                }
            }
        }
    }
    
    private func categoryButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding()
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - Popular Searches
    private var popularSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门搜索")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(["太和殿", "珍宝馆", "钟表馆", "御花园", "乾清宫", "午门", "中和殿", "保和殿"], id: \.self) { tag in
                    Button(action: {
                        searchService.searchText = tag
                        Task { await searchService.search(tag) }
                    }) {
                        Text(tag)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("搜索中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Empty Results
    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("未找到相关内容")
                .font(.headline)
            Text("试试其他关键词")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Search Results
    private var searchResultsList: some View {
        List {
            // Group by category
            ForEach(SearchService.SearchResult.SearchCategory.allCases, id: \.self) { category in
                let results = searchService.searchResults.filter { $0.category == category }
                if !results.isEmpty {
                    Section(category.rawValue) {
                        ForEach(results) { result in
                            SearchResultRow(result: result)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchService.SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(categoryColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: result.icon)
                    .foregroundStyle(categoryColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                
                Text(result.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Category badge
            Text(result.category.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(categoryColor.opacity(0.1))
                .foregroundStyle(categoryColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
    
    private var categoryColor: Color {
        switch result.category {
        case .poi: return .blue
        case .exhibition: return .purple
        case .facility: return .green
        case .tour: return .orange
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (CGSize(width: maxX - spacing, height: currentY + lineHeight), positions)
    }
}

// MARK: - Preview
#Preview {
    SearchView()
}
