// Search View - Search POIs, Exhibitions, Facilities

import SwiftUI

struct SearchView: View {
    @StateObject private var searchService = SearchService.shared
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let forest = Color(red: 0.12, green: 0.40, blue: 0.24)
    private let paper = Color(.systemGroupedBackground)
    private let surface = Color(.systemBackground)

    private let quickSearchItems: [QuickSearchItem] = [
        QuickSearchItem(icon: "mappin.and.ellipse", titleKey: "search.quick.poi", queryKey: "search.category.poi", color: Color(red: 0.86, green: 0.23, blue: 0.10)),
        QuickSearchItem(icon: "sparkles", titleKey: "search.quick.exhibition", queryKey: "search.category.exhibition", color: Color(red: 0.49, green: 0.34, blue: 0.93)),
        QuickSearchItem(icon: "figure.stand", titleKey: "search.quick.restroom", queryKey: "search.record.facilityRestroom.title", color: Color(red: 0.08, green: 0.45, blue: 0.94)),
        QuickSearchItem(icon: "fork.knife", titleKey: "search.quick.food", queryKey: "search.quick.food", color: Color(red: 0.94, green: 0.48, blue: 0.12)),
        QuickSearchItem(icon: "bag.fill", titleKey: "search.quick.shop", queryKey: "search.quick.shop", color: Color(red: 0.13, green: 0.60, blue: 0.32)),
        QuickSearchItem(icon: "map.fill", titleKey: "search.quick.route", queryKey: "search.category.tour", color: Color(red: 0.05, green: 0.62, blue: 0.70))
    ]
    private let popularSearchTags: [PopularSearchTag] = [
        PopularSearchTag(titleKey: "search.popular.entrance", queryKey: "search.popular.entrance"),
        PopularSearchTag(titleKey: "search.popular.visitorCenter", queryKey: "search.record.facilityVisitorCenter.title"),
        PopularSearchTag(titleKey: "search.popular.mainHall", queryKey: "search.record.poiMainHall.title"),
        PopularSearchTag(titleKey: "search.popular.temporaryExhibition", queryKey: "search.record.exhibitionTemporary.title"),
        PopularSearchTag(titleKey: "search.popular.restroom", queryKey: "search.record.facilityRestroom.title"),
        PopularSearchTag(titleKey: "search.popular.food", queryKey: "search.quick.food"),
        PopularSearchTag(titleKey: "search.popular.souvenir", queryKey: "search.popular.souvenir"),
        PopularSearchTag(titleKey: "search.popular.accessibility", queryKey: "search.popular.accessibility")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                paper
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar

                    Group {
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
                }
            }
            .navigationTitle(L10n.string("搜索"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.string("取消")) { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(forest)

                TextField(L10n.string("搜索景点、展览、设施..."), text: $searchService.searchText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
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
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(forest.opacity(isSearchFocused ? 0.45 : 0.12), lineWidth: 1.2)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(.regularMaterial)
    }
    
    // MARK: - Suggestions Content
    private var suggestionsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                if !searchService.recentSearches.isEmpty {
                    recentSearchesSection
                }

                quickCategoriesSection
                popularSearchesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
    }
    
    // MARK: - Recent Searches
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("最近搜索"))
                    .font(.headline)

                Spacer()

                Button(L10n.string("清空")) {
                    searchService.clearRecentSearches()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            ForEach(searchService.recentSearches, id: \.self) { search in
                Button(action: {
                    runSearch(search)
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
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Quick Categories
    private var quickCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("快速查找"))
                .font(.title3.weight(.bold))

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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.14))
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color)
                }
                .frame(width: 38, height: 38)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.72))
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
            .background(surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Popular Searches
    private var popularSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("热门搜索"))
                .font(.title3.weight(.bold))

            FlowLayout(spacing: 8) {
                ForEach(popularSearchTags, id: \.self) { tag in
                    Button(action: {
                        runSearch(tag.query)
                    }) {
                        Text(tag.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(forest)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(forest.opacity(0.09))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(forest.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func runSearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        if searchService.searchText == trimmedQuery {
            Task { await searchService.search(trimmedQuery) }
        } else {
            searchService.searchText = trimmedQuery
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(forest)
            Text(L10n.string("搜索中..."))
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
                .foregroundStyle(forest.opacity(0.45))
            Text(L10n.string("未找到相关内容"))
                .font(.headline)
            Text(L10n.string("试试其他关键词"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Search Results
    private var searchResultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(SearchService.SearchResult.SearchCategory.allCases, id: \.self) { category in
                    let results = searchService.searchResults.filter { $0.category == category }
                    if !results.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.localizedName)
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(results) { result in
                                SearchResultRow(result: result)
                                    .padding(.horizontal, 12)
                                    .frame(height: 72)
                                    .background(surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(.black.opacity(0.06), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
    }
}

private struct QuickSearchItem: Identifiable {
    var id: String { titleKey }
    let icon: String
    let titleKey: String
    let queryKey: String
    let color: Color

    var title: String {
        L10n.string(titleKey)
    }

    var query: String {
        L10n.string(queryKey)
    }
}

private struct PopularSearchTag: Hashable {
    let titleKey: String
    let queryKey: String

    var title: String {
        L10n.string(titleKey)
    }

    var query: String {
        L10n.string(queryKey)
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
            Text(result.category.localizedName)
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
