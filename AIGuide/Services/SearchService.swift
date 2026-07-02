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

    private struct SearchRecord {
        let id: String
        let title: String
        let subtitle: String
        let category: SearchResult.SearchCategory
        let icon: String
        let keywords: [String]
    }
    
    // MARK: - Private Properties
    private let recentSearchesKey = "com.aiguide.recent.searches"
    private let defaults = UserDefaults.standard
    private var activeSearchToken = 0
    private let searchDelayNanoseconds: UInt64 = 180_000_000
    private let searchCatalog: [SearchRecord] = [
        SearchRecord(
            id: "poi-entrance",
            title: "入口/出口",
            subtitle: "入园、离园、检票和集合位置",
            category: .poi,
            icon: "door.left.hand.open",
            keywords: ["入口", "出口", "检票", "闸机", "集合", "景点", "地点"]
        ),
        SearchRecord(
            id: "poi-main-hall",
            title: "主展厅",
            subtitle: "当前场馆的核心参观点",
            category: .poi,
            icon: "building.columns.fill",
            keywords: ["主展厅", "展厅", "景点", "必看", "核心", "参观"]
        ),
        SearchRecord(
            id: "poi-viewpoint",
            title: "观景点",
            subtitle: "适合停留、拍照和观察全景的位置",
            category: .poi,
            icon: "camera.viewfinder",
            keywords: ["观景", "拍照", "打卡", "景点", "视野", "全景"]
        ),
        SearchRecord(
            id: "poi-garden",
            title: "花园/户外区",
            subtitle: "适合休息和慢速游览的开放空间",
            category: .poi,
            icon: "leaf.fill",
            keywords: ["花园", "户外", "广场", "休息", "景点", "开放空间"]
        ),
        SearchRecord(
            id: "exhibition-permanent",
            title: "常设展",
            subtitle: "长期开放的主题陈列",
            category: .exhibition,
            icon: "photo.fill",
            keywords: ["常设展", "展览", "展品", "陈列", "展厅"]
        ),
        SearchRecord(
            id: "exhibition-temporary",
            title: "临时展",
            subtitle: "限时开放的专题展览",
            category: .exhibition,
            icon: "sparkles",
            keywords: ["临时展", "特展", "专题展", "展览", "限时"]
        ),
        SearchRecord(
            id: "exhibition-highlights",
            title: "精选展品",
            subtitle: "适合快速了解亮点内容",
            category: .exhibition,
            icon: "star.fill",
            keywords: ["精选", "亮点", "展品", "必看", "推荐"]
        ),
        SearchRecord(
            id: "exhibition-interactive",
            title: "互动体验",
            subtitle: "可参与的沉浸式展示或体验区",
            category: .exhibition,
            icon: "hand.tap.fill",
            keywords: ["互动", "体验", "沉浸", "展览", "体验区"]
        ),
        SearchRecord(
            id: "facility-visitor-center",
            title: "游客中心",
            subtitle: "咨询、票务、寄存和服务台",
            category: .facility,
            icon: "info.circle.fill",
            keywords: ["游客中心", "咨询", "票务", "寄存", "服务台", "服务"]
        ),
        SearchRecord(
            id: "facility-restroom",
            title: "卫生间",
            subtitle: "附近公共卫生间和无障碍卫生间",
            category: .facility,
            icon: "figure.stand",
            keywords: ["卫生间", "洗手间", "厕所", "无障碍卫生间", "设施"]
        ),
        SearchRecord(
            id: "facility-food",
            title: "餐饮",
            subtitle: "餐厅、咖啡、轻食和休息补给点",
            category: .facility,
            icon: "fork.knife",
            keywords: ["餐饮", "餐厅", "咖啡", "轻食", "吃饭", "饮品"]
        ),
        SearchRecord(
            id: "facility-shop",
            title: "纪念品商店",
            subtitle: "文创、纪念品和导览周边",
            category: .facility,
            icon: "bag.fill",
            keywords: ["商店", "纪念品", "文创", "购物", "周边"]
        ),
        SearchRecord(
            id: "facility-water",
            title: "饮水处",
            subtitle: "直饮水、补水和自动售卖点",
            category: .facility,
            icon: "drop.fill",
            keywords: ["饮水", "水", "补水", "售卖", "设施"]
        ),
        SearchRecord(
            id: "facility-accessibility",
            title: "无障碍服务",
            subtitle: "轮椅、坡道、电梯和辅助通行信息",
            category: .facility,
            icon: "figure.roll",
            keywords: ["无障碍", "轮椅", "坡道", "电梯", "辅助", "通行"]
        ),
        SearchRecord(
            id: "tour-recommended",
            title: "推荐路线",
            subtitle: "覆盖核心景点和展览的经典游览动线",
            category: .tour,
            icon: "map.fill",
            keywords: ["路线", "推荐", "经典", "核心", "导览"]
        ),
        SearchRecord(
            id: "tour-family",
            title: "亲子路线",
            subtitle: "节奏轻松、适合家庭同行的路线",
            category: .tour,
            icon: "figure.2.and.child.holdinghands",
            keywords: ["亲子", "家庭", "孩子", "轻松", "路线"]
        ),
        SearchRecord(
            id: "tour-short",
            title: "快速游览",
            subtitle: "时间有限时优先参观的精简路线",
            category: .tour,
            icon: "clock.fill",
            keywords: ["快速", "半日", "精简", "短线", "路线"]
        ),
        SearchRecord(
            id: "tour-accessible",
            title: "无障碍路线",
            subtitle: "优先经过坡道、电梯和便捷服务点",
            category: .tour,
            icon: "accessibility",
            keywords: ["无障碍", "轮椅", "电梯", "坡道", "路线"]
        )
    ]
    
    // MARK: - Initialization
    init() {
        loadRecentSearches()
    }
    
    // MARK: - Public Methods
    
    /// Search with query
    func search(_ query: String) async {
        activeSearchToken += 1
        let searchToken = activeSearchToken
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        do {
            try await Task.sleep(nanoseconds: searchDelayNanoseconds)
        } catch {
            completeSearchIfCurrent(searchToken)
            return
        }

        guard isCurrentSearch(searchToken) else { return }
        
        var results: [SearchResult] = []
        
        // Search POIs
        let poiResults = searchPOIs(trimmedQuery)
        results.append(contentsOf: poiResults)
        
        // Search exhibitions
        let exhibitionResults = searchExhibitions(trimmedQuery)
        results.append(contentsOf: exhibitionResults)
        
        // Search facilities
        let facilityResults = searchFacilities(trimmedQuery)
        results.append(contentsOf: facilityResults)
        
        // Search tours
        let tourResults = searchTours(trimmedQuery)
        results.append(contentsOf: tourResults)

        guard isCurrentSearch(searchToken) else { return }
        searchResults = results
        isSearching = false
        
        // Save to recent searches
        if !results.isEmpty {
            saveRecentSearch(trimmedQuery)
        }
    }
    
    /// Clear search
    func clearSearch() {
        activeSearchToken += 1
        searchText = ""
        searchResults = []
        isSearching = false
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
        searchRecords(query, in: .poi)
    }
    
    private func searchExhibitions(_ query: String) -> [SearchResult] {
        searchRecords(query, in: .exhibition)
    }
    
    private func searchFacilities(_ query: String) -> [SearchResult] {
        searchRecords(query, in: .facility)
    }
    
    private func searchTours(_ query: String) -> [SearchResult] {
        searchRecords(query, in: .tour)
    }

    private func searchRecords(_ query: String, in category: SearchResult.SearchCategory) -> [SearchResult] {
        searchCatalog
            .filter { record in
                record.category == category && matches(record, query: query)
            }
            .map { record in
                SearchResult(
                    id: record.id,
                    title: record.title,
                    subtitle: record.subtitle,
                    category: record.category,
                    icon: record.icon,
                    poi: nil
                )
            }
    }

    private func matches(_ record: SearchRecord, query: String) -> Bool {
        ([record.title, record.subtitle] + record.keywords).contains { value in
            value.localizedCaseInsensitiveContains(query) ||
            query.localizedCaseInsensitiveContains(value)
        }
    }

    private func isCurrentSearch(_ token: Int) -> Bool {
        token == activeSearchToken
    }

    private func completeSearchIfCurrent(_ token: Int) {
        guard isCurrentSearch(token) else { return }
        isSearching = false
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
