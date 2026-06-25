// Search View - Search POIs, Exhibitions, Facilities

import SwiftUI

struct SearchView: View {
    @StateObject private var searchService = SearchService.shared
    @State private var showResults = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    private let quickSearchItems: [QuickSearchItem] = [
        QuickSearchItem(icon: "mappin.and.ellipse", title: "景点", query: "景点", color: .red),
        QuickSearchItem(icon: "paintbrush.fill", title: "展品", query: "展品", color: .purple),
        QuickSearchItem(icon: "figure.stand", title: "卫生间", query: "卫生间", color: .blue),
        QuickSearchItem(icon: "fork.knife", title: "餐饮", query: "餐饮", color: .orange),
        QuickSearchItem(icon: "bag.fill", title: "商店", query: "商店", color: .green),
        QuickSearchItem(icon: "map.fill", title: "路线", query: "路线", color: .cyan)
    ]
    private let popularSearchTags = ["入口", "游客中心", "主展厅", "临时展", "卫生间", "餐饮", "纪念品", "无障碍"]
    
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
                ForEach(quickSearchItems) { item in
                    categoryButton(icon: item.icon, title: item.title, color: item.color) {
                        runSearch(item.query)
                    }
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
                ForEach(popularSearchTags, id: \.self) { tag in
                    Button(action: {
                        runSearch(tag)
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

    private func runSearch(_ query: String) {
        searchService.searchText = query
        Task { await searchService.search(query) }
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

private struct QuickSearchItem: Identifiable {
    var id: String { query }
    let icon: String
    let title: String
    let query: String
    let color: Color
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
