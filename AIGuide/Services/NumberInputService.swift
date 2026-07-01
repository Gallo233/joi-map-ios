// Number Input Service - Place Code Lookup

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

    struct LookupSuggestion: Identifiable {
        let code: String
        let poi: POI

        var id: String { code }
    }
    
    // MARK: - Private Properties
    private let recentLookupsKey = "com.aiguide.recent.lookups"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadRecentLookups()
    }

    var suggestedLookups: [LookupSuggestion] {
        let curatedIDs = Set(POI.curatedWorldList.map(\.id))
        let primarySuggestions = primaryLookupSuggestions
        let curated = primarySuggestions.filter { curatedIDs.contains($0.poi.id) }
        let remaining = primarySuggestions.filter { !curatedIDs.contains($0.poi.id) }

        return Array((curated + remaining).prefix(8))
    }
    
    // MARK: - Public Methods
    
    /// Look up a place or exhibit by a short code.
    func lookup(_ number: String) async {
        let normalizedCode = normalizeLookupCode(number)

        guard !normalizedCode.isEmpty else {
            matchedPOI = nil
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if let match = findPOI(byCode: normalizedCode) {
            matchedPOI = match.poi
            inputNumber = match.code
            saveLookup(number: match.code, poiName: match.poi.name)
        } else {
            matchedPOI = nil
            showError = true
            errorMessage = L10n.format("number.lookup.error.notFound.format", normalizedCode)
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
    
    private var lookupSuggestions: [LookupSuggestion] {
        primaryLookupSuggestions + numericLookupSuggestions
    }

    private var primaryLookupSuggestions: [LookupSuggestion] {
        var prefixCounts: [String: Int] = [:]

        return POI.seedList.map { poi in
            let prefix = codePrefix(for: poi)
            let index = (prefixCounts[prefix] ?? 0) + 1
            prefixCounts[prefix] = index
            let sequence = String(format: "%03d", index)
            return LookupSuggestion(code: "\(prefix)-\(sequence)", poi: poi)
        }
    }

    private var numericLookupSuggestions: [LookupSuggestion] {
        POI.seedList.enumerated().map { index, poi in
            LookupSuggestion(code: String(format: "%03d", index + 1), poi: poi)
        }
    }

    private func findPOI(byCode code: String) -> LookupSuggestion? {
        let normalizedCode = normalizeLookupCode(code)

        if let exact = lookupSuggestions.first(where: { normalizeLookupCode($0.code) == normalizedCode }) {
            return exact
        }

        if normalizedCode.count <= 3,
           let numericMatch = lookupSuggestions.first(where: { suggestion in
               normalizeLookupCode(suggestion.code).hasSuffix(normalizedCode)
           }) {
            return numericMatch
        }

        if let slugMatch = POI.seedList.first(where: { poi in
            normalizeLookupCode(poi.id).contains(normalizedCode)
        }) {
            return LookupSuggestion(code: primaryCode(for: slugMatch), poi: slugMatch)
        }

        return nil
    }

    private func primaryCode(for poi: POI) -> String {
        primaryLookupSuggestions.first(where: { $0.poi.id == poi.id })?.code ?? "\(codePrefix(for: poi))-001"
    }

    private func codePrefix(for poi: POI) -> String {
        let latitude = poi.coordinate.latitude
        let longitude = poi.coordinate.longitude

        if (39...41).contains(latitude), (115...117).contains(longitude) { return "BJS" }
        if (48...49).contains(latitude), (2...3).contains(longitude) { return "PAR" }
        if (40...41).contains(latitude), (-74.0 ... -73.0).contains(longitude) { return "NYC" }
        if (51...52).contains(latitude), (-1.0 ... 1.0).contains(longitude) { return "LON" }
        if (35...36).contains(latitude), (139...140).contains(longitude) { return "TKY" }
        if (25...26).contains(latitude), (121...122).contains(longitude) { return "TPE" }
        if (37...38).contains(latitude), (-123.0 ... -122.0).contains(longitude) { return "SFO" }

        return "JOI"
    }

    private func normalizeLookupCode(_ code: String) -> String {
        code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "-")
            .uppercased()
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
