// POI Service - Data Management

import Foundation
import CoreLocation

private enum POIServiceError: LocalizedError {
    case apiUnavailable
    case notFound

    var errorDescription: String? {
        switch self {
        case .apiUnavailable:
            return L10n.string("error.data.loadFailed")
        case .notFound:
            return L10n.string("error.data.notFound")
        }
    }
}

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
        loadSeedData()
    }
    
    // MARK: - Public Methods
    
    /// Load POIs from the bundled seed catalog until backend content is available.
    func loadPOIs() async {
        isLoading = true
        defer { isLoading = false }

        loadSeedData()
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
    
    private func loadSeedData() {
        allPOIs = POI.seedList

        if let firstSeed = POI.curatedWorldList.first {
            let seedLocation = CLLocation(
                latitude: firstSeed.coordinate.latitude,
                longitude: firstSeed.coordinate.longitude
            )
            updateNearbyPOIs(location: seedLocation)
        } else {
            nearbyPOIs = Array(allPOIs.prefix(3))
        }
    }
}

// MARK: - API Service (Future Implementation)
extension POIService {
    /// Future: Fetch POIs from backend
    private func fetchPOIsFromAPI() async throws -> [POI] {
        throw POIServiceError.apiUnavailable
    }
    
    /// Future: Fetch POI details
    private func fetchPOIDetails(id: String) async throws -> POI {
        guard let poi = findPOI(byId: id) else {
            throw POIServiceError.notFound
        }

        return poi
    }
}
