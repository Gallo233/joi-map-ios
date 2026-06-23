// Number Input Service - Museum Exhibit Lookup

import Foundation

@MainActor
class NumberInputService: ObservableObject {
    // MARK: - Published Properties
    @Published var inputNumber = ""
    @Published var matchedPOI: POI?
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var recentLookups: [LookupRecord] = []
    
    // MARK: - Types
    struct LookupRecord: Codable, Identifiable {
        let id: String
        let number: String
        let poiName: String
        let timestamp: Date
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: timestamp)
        }
    }
    
    // MARK: - Private Properties
    private let recentLookupsKey = "com.aiguide.recent.lookups"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadRecentLookups()
    }
    
    // MARK: - Public Methods
    
    /// Look up exhibit by number
    func lookup(_ number: String) async {
        guard !number.isEmpty else {
            matchedPOI = nil
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Search in mock data
        if let poi = findPOI(byNumber: number) {
            matchedPOI = poi
            saveLookup(number: number, poiName: poi.name)
        } else {
            matchedPOI = nil
            showError = true
            errorMessage = "未找到编号为 \(number) 的展品"
        }
    }
    
    /// Clear input
    func clearInput() {
        inputNumber = ""
        matchedPOI = nil
    }
    
    /// Clear recent lookups
    func clearRecentLookups() {
        recentLookups = []
        saveRecentLookups()
    }
    
    /// Remove specific lookup
    func removeLookup(_ lookup: LookupRecord) {
        recentLookups.removeAll { $0.id == lookup.id }
        saveRecentLookups()
    }
    
    // MARK: - Private Methods
    
    private func findPOI(byNumber number: String) -> POI? {
        // Mock number mapping
        let numberMap: [String: String] = [
            "001": "taihedian",
            "002": "zhonghedian",
            "003": "baohedian",
            "004": "qianqinggong",
            "005": "wumen",
            "006": "taihemen",
            "007": "yuhuayuan",
            "008": "kunninggong",
            "100": "taihedian",
            "101": "zhonghedian",
            "102": "baohedian",
            "200": "qianqinggong",
            "201": "kunninggong",
            "202": "yuhuayuan",
        ]
        
        // Try exact match
        if let poiId = numberMap[number] {
            return POI.mockList.first { $0.id == poiId }
        }
        
        // Try partial match
        for (key, poiId) in numberMap {
            if key.hasSuffix(number) || number.hasSuffix(key) {
                return POI.mockList.first { $0.id == poiId }
            }
        }
        
        return nil
    }
    
    private func saveLookup(number: String, poiName: String) {
        let record = LookupRecord(
            id: UUID().uuidString,
            number: number,
            poiName: poiName,
            timestamp: Date()
        )
        
        recentLookups.insert(record, at: 0)
        
        // Keep only last 20
        if recentLookups.count > 20 {
            recentLookups = Array(recentLookups.prefix(20))
        }
        
        saveRecentLookups()
    }
    
    private func loadRecentLookups() {
        if let data = defaults.data(forKey: recentLookupsKey),
           let lookups = try? JSONDecoder().decode([LookupRecord].self, from: data) {
            recentLookups = lookups
        }
    }
    
    private func saveRecentLookups() {
        if let data = try? JSONEncoder().encode(recentLookups) {
            defaults.set(data, forKey: recentLookupsKey)
        }
    }
}

// MARK: - Singleton
extension NumberInputService {
    static let shared = NumberInputService()
}
