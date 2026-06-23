// History Service - Visit Records & Local Cache

import Foundation

@MainActor
class HistoryService: ObservableObject {
    // MARK: - Published Properties
    @Published var visitRecords: [VisitRecord] = []
    @Published var favoritePOIs: [String] = []

    // MARK: - Types
    struct VisitRecord: Codable, Identifiable {
        let id: String
        let poiId: String
        let poiName: String
        let visitDate: Date
        let duration: TimeInterval
        let style: String
        let summary: String?
        let sourceName: String?

        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日 HH:mm"
            return formatter.string(from: visitDate)
        }

        var formattedDuration: String {
            let minutes = Int(duration) / 60
            if minutes < 1 {
                return "不到1分钟"
            }
            return "\(minutes)分钟"
        }
    }

    struct CacheData: Codable {
        var pois: [POI]
        var guides: [String: AudioGuide]
        var lastUpdated: Date
    }

    // MARK: - Private Properties
    private let recordsKey = "com.aiguide.visit.records"
    private let favoritesKey = "com.aiguide.favorites"
    private let cacheKey = "com.aiguide.cache"
    private let defaults = UserDefaults.standard

    // MARK: - Initialization
    init() {
        loadRecords()
        loadFavorites()
    }

    // MARK: - Visit Records

    /// Add a visit record
    func addVisit(
        poiId: String,
        poiName: String,
        duration: TimeInterval,
        style: GuideStyle,
        summary: String?,
        sourceName: String?
    ) {
        let record = VisitRecord(
            id: UUID().uuidString,
            poiId: poiId,
            poiName: poiName,
            visitDate: Date(),
            duration: duration,
            style: style.displayName,
            summary: summary,
            sourceName: sourceName
        )

        visitRecords.insert(record, at: 0)
        saveRecords()
    }

    /// Get visits for a specific POI
    func getVisits(for poiId: String) -> [VisitRecord] {
        visitRecords.filter { $0.poiId == poiId }
    }

    /// Get visit count for a POI
    func getVisitCount(for poiId: String) -> Int {
        visitRecords.filter { $0.poiId == poiId }.count
    }

    /// Clear all records
    func clearRecords() {
        visitRecords.removeAll()
        saveRecords()
    }

    // MARK: - Favorites

    /// Toggle favorite for a POI
    func toggleFavorite(poiId: String) {
        if favoritePOIs.contains(poiId) {
            favoritePOIs.removeAll { $0 == poiId }
        } else {
            favoritePOIs.append(poiId)
        }
        saveFavorites()
    }

    /// Check if POI is favorite
    func isFavorite(poiId: String) -> Bool {
        favoritePOIs.contains(poiId)
    }

    // MARK: - Cache

    /// Save POIs to cache
    func cachePOIs(_ pois: [POI]) {
        var cache = loadCache() ?? CacheData(pois: [], guides: [:], lastUpdated: Date())
        cache.pois = pois
        cache.lastUpdated = Date()
        saveCache(cache)
    }

    /// Load cached POIs
    func getCachedPOIs() -> [POI]? {
        guard let cache = loadCache() else { return nil }

        // Check if cache is still valid (24 hours)
        let hoursSinceUpdate = Date().timeIntervalSince(cache.lastUpdated) / 3600
        if hoursSinceUpdate > 24 {
            return nil
        }

        return cache.pois
    }

    /// Save guide to cache
    func cacheGuide(_ guide: AudioGuide, for key: String) {
        var cache = loadCache() ?? CacheData(pois: [], guides: [:], lastUpdated: Date())
        cache.guides[key] = guide
        saveCache(cache)
    }

    /// Load cached guide
    func getCachedGuide(for key: String) -> AudioGuide? {
        loadCache()?.guides[key]
    }

    // MARK: - Statistics

    /// Get total visit count
    var totalVisits: Int {
        visitRecords.count
    }

    /// Get unique POIs visited
    var uniquePOIsVisited: Int {
        Set(visitRecords.map { $0.poiId }).count
    }

    /// Get total time spent
    var totalTimeSpent: TimeInterval {
        visitRecords.reduce(0) { $0 + $1.duration }
    }

    /// Get most visited POI
    var mostVisitedPOI: String? {
        let counts = Dictionary(grouping: visitRecords, by: { $0.poiId })
        return counts.max(by: { $0.value.count < $1.value.count })?.value.first?.poiName
    }

    // MARK: - Private Methods

    private func loadRecords() {
        guard let data = defaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([VisitRecord].self, from: data) else {
            return
        }
        visitRecords = records
    }

    private func saveRecords() {
        guard let data = try? JSONEncoder().encode(visitRecords) else { return }
        defaults.set(data, forKey: recordsKey)
    }

    private func loadFavorites() {
        favoritePOIs = defaults.stringArray(forKey: favoritesKey) ?? []
    }

    private func saveFavorites() {
        defaults.set(favoritePOIs, forKey: favoritesKey)
    }

    private func loadCache() -> CacheData? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(CacheData.self, from: data)
    }

    private func saveCache(_ cache: CacheData) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}

// MARK: - Singleton
extension HistoryService {
    static let shared = HistoryService()
}
