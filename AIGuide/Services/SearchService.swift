// Search Service - Search POIs, Exhibitions, Facilities

import Foundation

@MainActor
class SearchService: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching = false
    
    // MARK: - Types
    struct SearchResult: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let category: SearchCategory
        let icon: String
        let poi: POI?
        
        enum SearchCategory: String, CaseIterable {
            case poi = "景点"
            case exhibition = "展览"
            case facility = "设施"
            case tour = "路线"
            
            var icon: String {
                switch self {
                case .poi: return "building.2.fill"
                case .exhibition: return "photo.fill"
                case .facility: return "mappin.circle.fill"
                case .tour: return "map.fill"
                }
            }
        }
    }
    
    // MARK: - Private Properties
    private let recentSearchesKey = "com.aiguide.recent.searches"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    
    /// Search with query
    func search(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        var results: [SearchResult] = []
        
        // Search POIs
        let poiResults = searchPOIs(query)
        results.append(contentsOf: poiResults)
        
        // Search exhibitions
        let exhibitionResults = searchExhibitions(query)
        results.append(contentsOf: exhibitionResults)
        
        // Search facilities
        let facilityResults = searchFacilities(query)
        results.append(contentsOf: facilityResults)
        
        // Search tours
        let tourResults = searchTours(query)
        results.append(contentsOf: tourResults)
        
        searchResults = results
        
        // Save to recent searches
        if !results.isEmpty {
            saveRecentSearch(query)
        }
    }
    
    /// Clear search
    func clearSearch() {
        searchText = ""
        searchResults = []
    }
    
    /// Clear recent searches
    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()
    }
    
    /// Remove specific recent search
    func removeRecentSearch(_ search: String) {
        recentSearches.removeAll { $0 == search }
        saveRecentSearches()
    }
    
    // MARK: - Private Methods - Search
    
    private func searchPOIs(_ query: String) -> [SearchResult] {
        let pois = POI.mockList
        let filtered = pois.filter { poi in
            poi.name.localizedCaseInsensitiveContains(query) ||
            poi.description.localizedCaseInsensitiveContains(query)
        }
        
        return filtered.map { poi in
            SearchResult(
                id: poi.id,
                title: poi.name,
                subtitle: poi.description,
                category: .poi,
                icon: "building.2.fill",
                poi: poi
            )
        }
    }
    
    private func searchExhibitions(_ query: String) -> [SearchResult] {
        // Mock exhibitions
        let exhibitions = [
            (id: "ex1", name: "故宫珍宝展", description: "清代宫廷珍宝文物"),
            (id: "ex2", name: "钟表馆", description: "清代宫廷钟表收藏"),
            (id: "ex3", name: "书画馆", description: "历代书画精品"),
            (id: "ex4", name: "陶瓷馆", description: "中国古代陶瓷"),
        ]
        
        let filtered = exhibitions.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
        
        return filtered.map { exhibition in
            SearchResult(
                id: exhibition.id,
                title: exhibition.name,
                subtitle: exhibition.description,
                category: .exhibition,
                icon: "photo.fill",
                poi: nil
            )
        }
    }
    
    private func searchFacilities(_ query: String) -> [SearchResult] {
        // Mock facilities
        let facilities = [
            (id: "f1", name: "卫生间", description: "太和殿东侧", icon: "figure.stand"),
            (id: "f2", name: "餐厅", description: "御膳房", icon: "fork.knife"),
            (id: "f3", name: "纪念品商店", description: "故宫商店", icon: "bag.fill"),
            (id: "f4", name: "饮水处", description: "各主要景点", icon: "drop.fill"),
            (id: "f5", name: "轮椅租赁", description: "午门入口", icon: "figure.roll"),
            (id: "f6", name: "母婴室", description: "乾清宫附近", icon: "figure.and.child.holdinghands"),
        ]
        
        let filtered = facilities.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
        
        return filtered.map { facility in
            SearchResult(
                id: facility.id,
                title: facility.name,
                subtitle: facility.description,
                category: .facility,
                icon: facility.icon,
                poi: nil
            )
        }
    }
    
    private func searchTours(_ query: String) -> [SearchResult] {
        // Mock tours
        let tours = [
            (id: "t1", name: "中轴线精华游", description: "太和殿-中和殿-保和殿"),
            (id: "t2", name: "后宫探秘", description: "乾清宫-坤宁宫-御花园"),
            (id: "t3", name: "珍宝之旅", description: "珍宝馆-钟表馆"),
            (id: "t4", name: "亲子路线", description: "适合带小朋友的轻松路线"),
        ]
        
        let filtered = tours.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.description.localizedCaseInsensitiveContains(query) }
        
        return filtered.map { tour in
            SearchResult(
                id: tour.id,
                title: tour.name,
                subtitle: tour.description,
                category: .tour,
                icon: "map.fill",
                poi: nil
            )
        }
    }
    
    // MARK: - Recent Searches
    
    private func loadRecentSearches() {
        recentSearches = defaults.stringArray(forKey: recentSearchesKey) ?? []
    }
    
    private func saveRecentSearch(_ search: String) {
        // Remove if exists
        recentSearches.removeAll { $0 == search }
        
        // Add to beginning
        recentSearches.insert(search, at: 0)
        
        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    private func saveRecentSearches() {
        defaults.set(recentSearches, forKey: recentSearchesKey)
    }
}

// MARK: - Singleton
extension SearchService {
    static let shared = SearchService()
}
