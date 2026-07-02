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
        let titleKey: String
        let subtitleKey: String
        let category: SearchCategory
        let icon: String
        let poi: POI?

        var title: String {
            L10n.string(titleKey)
        }

        var subtitle: String {
            L10n.string(subtitleKey)
        }
        
        enum SearchCategory: String, CaseIterable {
            case poi = "search.category.poi"
            case exhibition = "search.category.exhibition"
            case facility = "search.category.facility"
            case tour = "search.category.tour"

            var localizedName: String {
                L10n.string(rawValue)
            }
            
            var icon: String {
                switch self {
                case .poi: return "building.2.fill"
                case .exhibition: return "photo.fill"
                case .facility: return "mappin.circle.fill"
                case .tour: return "map.fill"
                }
            }

            var searchAliases: [String] {
                switch self {
                case .poi:
                    return ["景点", "地点", "参观", "places", "place", "landmarks", "landmark", "spots", "spot", "スポット", "名所", "명소", "장소"]
                case .exhibition:
                    return ["展览", "展品", "展厅", "exhibits", "exhibit", "exhibitions", "exhibition", "展示", "전시", "전시품"]
                case .facility:
                    return ["设施", "服务", "洗手间", "餐饮", "商店", "facilities", "facility", "services", "restrooms", "restroom", "amenities", "施設", "サービス", "시설", "편의시설"]
                case .tour:
                    return ["路线", "导览", "行程", "routes", "route", "tours", "tour", "paths", "ルート", "コース", "경로", "투어"]
                }
            }

            func matches(_ query: String) -> Bool {
                ([localizedName] + searchAliases).contains { value in
                    value.localizedCaseInsensitiveContains(query) ||
                    query.localizedCaseInsensitiveContains(value)
                }
            }
        }
    }

    private struct SearchRecord {
        let id: String
        let titleKey: String
        let subtitleKey: String
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
            titleKey: "search.record.poiEntrance.title",
            subtitleKey: "search.record.poiEntrance.subtitle",
            category: .poi,
            icon: "door.left.hand.open",
            keywords: ["入口", "出口", "检票", "闸机", "集合", "景点", "地点", "entrance", "exit", "gate", "ticket", "入口", "出口", "입구", "출구"]
        ),
        SearchRecord(
            id: "poi-main-hall",
            titleKey: "search.record.poiMainHall.title",
            subtitleKey: "search.record.poiMainHall.subtitle",
            category: .poi,
            icon: "building.columns.fill",
            keywords: ["主展厅", "展厅", "景点", "必看", "核心", "参观", "main hall", "hall", "highlights", "メインホール", "メイン展示室", "주 전시실"]
        ),
        SearchRecord(
            id: "poi-viewpoint",
            titleKey: "search.record.poiViewpoint.title",
            subtitleKey: "search.record.poiViewpoint.subtitle",
            category: .poi,
            icon: "camera.viewfinder",
            keywords: ["观景", "拍照", "打卡", "景点", "视野", "全景", "viewpoint", "photo", "panorama", "写真", "展望", "전망", "사진"]
        ),
        SearchRecord(
            id: "poi-garden",
            titleKey: "search.record.poiGarden.title",
            subtitleKey: "search.record.poiGarden.subtitle",
            category: .poi,
            icon: "leaf.fill",
            keywords: ["花园", "户外", "广场", "休息", "景点", "开放空间", "garden", "outdoor", "plaza", "rest", "庭園", "屋外", "정원", "야외"]
        ),
        SearchRecord(
            id: "exhibition-permanent",
            titleKey: "search.record.exhibitionPermanent.title",
            subtitleKey: "search.record.exhibitionPermanent.subtitle",
            category: .exhibition,
            icon: "photo.fill",
            keywords: ["常设展", "展览", "展品", "陈列", "展厅", "permanent", "exhibition", "gallery", "常設展", "상설전"]
        ),
        SearchRecord(
            id: "exhibition-temporary",
            titleKey: "search.record.exhibitionTemporary.title",
            subtitleKey: "search.record.exhibitionTemporary.subtitle",
            category: .exhibition,
            icon: "sparkles",
            keywords: ["临时展", "特展", "专题展", "展览", "限时", "temporary", "special", "limited", "企画展", "特別展", "기획전", "특별전"]
        ),
        SearchRecord(
            id: "exhibition-highlights",
            titleKey: "search.record.exhibitionHighlights.title",
            subtitleKey: "search.record.exhibitionHighlights.subtitle",
            category: .exhibition,
            icon: "star.fill",
            keywords: ["精选", "亮点", "展品", "必看", "推荐", "highlights", "must see", "featured", "見どころ", "おすすめ", "하이라이트", "추천"]
        ),
        SearchRecord(
            id: "exhibition-interactive",
            titleKey: "search.record.exhibitionInteractive.title",
            subtitleKey: "search.record.exhibitionInteractive.subtitle",
            category: .exhibition,
            icon: "hand.tap.fill",
            keywords: ["互动", "体验", "沉浸", "展览", "体验区", "interactive", "experience", "immersive", "体験", "インタラクティブ", "체험", "인터랙티브"]
        ),
        SearchRecord(
            id: "facility-visitor-center",
            titleKey: "search.record.facilityVisitorCenter.title",
            subtitleKey: "search.record.facilityVisitorCenter.subtitle",
            category: .facility,
            icon: "info.circle.fill",
            keywords: ["游客中心", "咨询", "票务", "寄存", "服务台", "服务", "visitor center", "information", "tickets", "locker", "案内", "チケット", "방문자 센터", "안내"]
        ),
        SearchRecord(
            id: "facility-restroom",
            titleKey: "search.record.facilityRestroom.title",
            subtitleKey: "search.record.facilityRestroom.subtitle",
            category: .facility,
            icon: "figure.stand",
            keywords: ["卫生间", "洗手间", "厕所", "无障碍卫生间", "设施", "restroom", "toilet", "bathroom", "accessible restroom", "トイレ", "化粧室", "화장실"]
        ),
        SearchRecord(
            id: "facility-food",
            titleKey: "search.record.facilityFood.title",
            subtitleKey: "search.record.facilityFood.subtitle",
            category: .facility,
            icon: "fork.knife",
            keywords: ["餐饮", "餐厅", "咖啡", "轻食", "吃饭", "饮品", "food", "dining", "restaurant", "cafe", "drink", "食事", "カフェ", "음식", "식당", "카페"]
        ),
        SearchRecord(
            id: "facility-shop",
            titleKey: "search.record.facilityShop.title",
            subtitleKey: "search.record.facilityShop.subtitle",
            category: .facility,
            icon: "bag.fill",
            keywords: ["商店", "纪念品", "文创", "购物", "周边", "shop", "store", "souvenir", "gift", "museum shop", "ショップ", "お土産", "상점", "기념품"]
        ),
        SearchRecord(
            id: "facility-water",
            titleKey: "search.record.facilityWater.title",
            subtitleKey: "search.record.facilityWater.subtitle",
            category: .facility,
            icon: "drop.fill",
            keywords: ["饮水", "水", "补水", "售卖", "设施", "water", "drinking water", "vending", "水飲み場", "給水", "식수", "물"]
        ),
        SearchRecord(
            id: "facility-accessibility",
            titleKey: "search.record.facilityAccessibility.title",
            subtitleKey: "search.record.facilityAccessibility.subtitle",
            category: .facility,
            icon: "figure.roll",
            keywords: ["无障碍", "轮椅", "坡道", "电梯", "辅助", "通行", "accessibility", "wheelchair", "ramp", "elevator", "バリアフリー", "車椅子", "접근성", "휠체어"]
        ),
        SearchRecord(
            id: "tour-recommended",
            titleKey: "search.record.tourRecommended.title",
            subtitleKey: "search.record.tourRecommended.subtitle",
            category: .tour,
            icon: "map.fill",
            keywords: ["路线", "推荐", "经典", "核心", "导览", "recommended", "classic", "route", "tour", "おすすめ", "定番", "추천", "클래식"]
        ),
        SearchRecord(
            id: "tour-family",
            titleKey: "search.record.tourFamily.title",
            subtitleKey: "search.record.tourFamily.subtitle",
            category: .tour,
            icon: "figure.2.and.child.holdinghands",
            keywords: ["亲子", "家庭", "孩子", "轻松", "路线", "family", "kids", "children", "relaxed", "ファミリー", "子ども", "가족", "아이"]
        ),
        SearchRecord(
            id: "tour-short",
            titleKey: "search.record.tourShort.title",
            subtitleKey: "search.record.tourShort.subtitle",
            category: .tour,
            icon: "clock.fill",
            keywords: ["快速", "半日", "精简", "短线", "路线", "quick", "short", "limited time", "half day", "短時間", "半日", "빠른", "짧은"]
        ),
        SearchRecord(
            id: "tour-accessible",
            titleKey: "search.record.tourAccessible.title",
            subtitleKey: "search.record.tourAccessible.subtitle",
            category: .tour,
            icon: "accessibility",
            keywords: ["无障碍", "轮椅", "电梯", "坡道", "路线", "accessible route", "wheelchair route", "elevator", "ramp", "バリアフリー", "휠체어 경로"]
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
        let categoryMatchesQuery = category.matches(query)

        return searchCatalog
            .filter { record in
                record.category == category && (categoryMatchesQuery || matches(record, query: query))
            }
            .map { record in
                SearchResult(
                    id: record.id,
                    titleKey: record.titleKey,
                    subtitleKey: record.subtitleKey,
                    category: record.category,
                    icon: record.icon,
                    poi: nil
                )
            }
    }

    private func matches(_ record: SearchRecord, query: String) -> Bool {
        let localizedValues = [
            L10n.string(record.titleKey),
            L10n.string(record.subtitleKey),
            record.category.localizedName
        ]

        return (localizedValues + record.keywords).contains { value in
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
