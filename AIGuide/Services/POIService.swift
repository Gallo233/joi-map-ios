// POI Service - Data Management

import Foundation
import CoreLocation

@MainActor
class POIService: ObservableObject {
    // MARK: - Published Properties
    @Published var allPOIs: [POI] = []
    @Published var nearbyPOIs: [POI] = []
    @Published var currentPOI: POI?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Configuration
    private let nearbyRadius: CLLocationDistance = 100 // 100 meters
    
    // MARK: - Initialization
    init() {
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Load POIs (mock for now, will connect to backend)
    func loadPOIs() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Replace with actual API call
        // For now, use mock data
        loadMockData()
    }
    
    /// Update nearby POIs based on current location
    func updateNearbyPOIs(location: CLLocation) {
        nearbyPOIs = allPOIs.filter { poi in
            let poiLocation = CLLocation(
                latitude: poi.coordinate.latitude,
                longitude: poi.coordinate.longitude
            )
            return location.distance(from: poiLocation) <= nearbyRadius
        }
    }
    
    /// Find POI by ID
    func findPOI(byId id: String) -> POI? {
        allPOIs.first { $0.id == id }
    }
    
    /// Get POIs for a specific route
    func getPOIsForRoute(_ route: Route) -> [POI] {
        route.stops.compactMap { stop in
            findPOI(byId: stop.poiId)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadMockData() {
        allPOIs = POI.seedList
        
        // Set initial nearby POIs (mock location at 太和殿)
        let mockLocation = CLLocation(latitude: 39.9163, longitude: 116.3972)
        updateNearbyPOIs(location: mockLocation)
    }
}

// MARK: - API Service (Future Implementation)
extension POIService {
    /// Future: Fetch POIs from backend
    private func fetchPOIsFromAPI() async throws -> [POI] {
        // TODO: Implement API call
        // GET /api/v1/pois
        // Headers: Authorization: Bearer <token>
        // Response: [POI]
        fatalError("Not implemented")
    }
    
    /// Future: Fetch POI details
    private func fetchPOIDetails(id: String) async throws -> POI {
        // TODO: Implement API call
        // GET /api/v1/pois/{id}
        fatalError("Not implemented")
    }
}
