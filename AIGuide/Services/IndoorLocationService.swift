// Indoor Location Service - Indoor Positioning

import Foundation
import CoreLocation
import CoreBluetooth

@MainActor
class IndoorLocationService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var currentFloor: Int = 1
    @Published var currentZone: String = ""
    @Published var nearbyBeacons: [BeaconInfo] = []
    @Published var isIndoorPositioningAvailable = false
    @Published var positioningAccuracy: PositioningAccuracy = .unavailable
    
    // MARK: - Types
    struct BeaconInfo: Identifiable {
        let id: String
        let uuid: UUID
        let major: Int
        let minor: Int
        let name: String
        let description: String
        let floor: Int
        let zone: String
        let distance: Double
        let rssi: Int
    }
    
    struct POISignal: Identifiable {
        let id = UUID()
        let poiId: String
        let confidence: Double
        let source: String
    }
    
    enum PositioningAccuracy: String {
        case high = "高精度"
        case medium = "中等精度"
        case low = "低精度"
        case unavailable = "不可用"

        var localizedName: String {
            switch self {
            case .high: return L10n.string("indoor.accuracy.high")
            case .medium: return L10n.string("indoor.accuracy.medium")
            case .low: return L10n.string("indoor.accuracy.low")
            case .unavailable: return L10n.string("indoor.accuracy.unavailable")
            }
        }
        
        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "blue"
            case .low: return "orange"
            case .unavailable: return "red"
            }
        }
    }
    
    struct FloorInfo: Identifiable {
        let id: Int
        let name: String
        let description: String
        let zones: [ZoneInfo]
    }
    
    struct ZoneInfo: Identifiable {
        let id: String
        let name: String
        let floor: Int
        let pois: [String]
    }
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var beaconConstraints: [CLBeaconIdentityConstraint] = []
    
    // MARK: - Demo Data
    private var demoFloors: [FloorInfo] {
        [
            FloorInfo(id: 1, name: "Main Level", description: "Entry, orientation, and nearby cultural anchors", zones: [
                ZoneInfo(id: "z1", name: "Orientation Hall", floor: 1, pois: [
                    "contemporary-jewish-museum-san-francisco",
                    "sfmoma"
                ]),
                ZoneInfo(id: "z2", name: "City Stories", floor: 1, pois: [
                    "union-square-sf"
                ]),
            ]),
            FloorInfo(id: 2, name: "Collections", description: "Major museum routes and permanent highlights", zones: [
                ZoneInfo(id: "z3", name: "World Museums", floor: 2, pois: [
                    "louvre-paris",
                    "met-museum-new-york",
                    "british-museum-london"
                ]),
            ]),
            FloorInfo(id: 3, name: "Special Exhibitions", description: "Rotating galleries and deep-dive stops", zones: [
                ZoneInfo(id: "z4", name: "Asia Galleries", floor: 3, pois: [
                    "tokyo-national-museum",
                    "national-palace-museum-taipei"
                ]),
            ]),
        ]
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        setupDemoBeacons()
    }
    
    // MARK: - Public Methods
    
    /// Request authorization
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start indoor positioning
    func startIndoorPositioning() {
        // Check if beacon ranging is available
        guard CLLocationManager.isRangingAvailable() else {
            positioningAccuracy = .unavailable
            return
        }
        
        // Start ranging beacons
        for constraint in beaconConstraints {
            locationManager.startRangingBeacons(satisfying: constraint)
        }
        
        isIndoorPositioningAvailable = true
    }
    
    /// Stop indoor positioning
    func stopIndoorPositioning() {
        for constraint in beaconConstraints {
            locationManager.stopRangingBeacons(satisfying: constraint)
        }
        
        isIndoorPositioningAvailable = false
    }
    
    /// Get floor by number
    func getFloor(_ floorNumber: Int) -> FloorInfo? {
        demoFloors.first { $0.id == floorNumber }
    }
    
    /// Get zones for floor
    func getZones(forFloor floor: Int) -> [ZoneInfo] {
        getFloor(floor)?.zones ?? []
    }
    
    /// Get POIs in zone
    func getPOIs(inZone zone: String) -> [String] {
        for floor in demoFloors {
            if let zoneInfo = floor.zones.first(where: { $0.id == zone }) {
                return zoneInfo.pois
            }
        }
        return []
    }
    
    /// Convert indoor signals into POI candidates for guide-context fusion.
    func currentPOISignals() -> [POISignal] {
        var scores: [String: POISignal] = [:]
        
        for beacon in nearbyBeacons {
            guard let poiId = poiId(forBeacon: beacon) else { continue }
            let confidence = beaconConfidence(beacon)
            let signal = POISignal(
                poiId: poiId,
                confidence: confidence,
                source: "室内信标"
            )
            
            if let existing = scores[poiId] {
                scores[poiId] = existing.confidence >= signal.confidence ? existing : signal
            } else {
                scores[poiId] = signal
            }
        }
        
        if let zone = zoneInfo(matching: currentZone) {
            let zoneConfidence: Double
            switch positioningAccuracy {
            case .high: zoneConfidence = 0.42
            case .medium: zoneConfidence = 0.34
            case .low: zoneConfidence = 0.24
            case .unavailable: zoneConfidence = 0.14
            }
            
            for poiId in zone.pois {
                let signal = POISignal(
                    poiId: poiId,
                    confidence: zoneConfidence,
                    source: "室内区域"
                )
                
                if let existing = scores[poiId] {
                    scores[poiId] = existing.confidence >= signal.confidence ? existing : signal
                } else {
                    scores[poiId] = signal
                }
            }
        }
        
        return scores.values.sorted { $0.confidence > $1.confidence }
    }
    
    /// Switch floor
    func switchFloor(_ floor: Int) {
        guard demoFloors.contains(where: { $0.id == floor }) else { return }
        currentFloor = floor
        
        // Update current zone
        if let floorInfo = getFloor(floor) {
            currentZone = floorInfo.zones.first?.name ?? ""
        }
    }
    
    /// Simulate indoor positioning (for demo)
    func simulateIndoorPositioning() {
        let profiles = simulatedBeaconProfiles()
        let zoneName = demoFloors.first?.zones.first?.name ?? ""

        currentFloor = 1
        currentZone = zoneName
        positioningAccuracy = .high

        nearbyBeacons = profiles.enumerated().map { index, profile in
            BeaconInfo(
                id: "b\(index + 1)",
                uuid: UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")!,
                major: 1,
                minor: index + 1,
                name: profile.name,
                description: profile.description,
                floor: 1,
                zone: zoneName,
                distance: simulatedBeaconDistance(at: index),
                rssi: simulatedBeaconRSSI(at: index)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDemoBeacons() {
        // Define one demo beacon namespace for indoor preview mode.
        let museumUUID = UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")!
        let constraint = CLBeaconIdentityConstraint(uuid: museumUUID)
        beaconConstraints.append(constraint)
    }
    
    private func poiId(forBeacon beacon: BeaconInfo) -> String? {
        if let profile = beaconProfile(forMinor: beacon.minor) {
            return profile.poiId
        }
        
        let normalizedName = beacon.name
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        
        return POI.seedList.first { poi in
            normalizedName.contains(poi.name.lowercased())
        }?.id
    }
    
    private func beaconConfidence(_ beacon: BeaconInfo) -> Double {
        let distanceScore = max(0.1, 1.0 - min(beacon.distance, 30) / 30)
        let rssiScore = max(0.1, min(1.0, Double(beacon.rssi + 100) / 45))
        return min(0.96, max(0.18, distanceScore * 0.72 + rssiScore * 0.28))
    }
    
    private func zoneInfo(matching zone: String) -> ZoneInfo? {
        guard !zone.isEmpty else { return nil }
        
        return demoFloors
            .flatMap(\.zones)
            .first { $0.id == zone || $0.name == zone }
    }
    
    private func beaconProfile(forMinor minor: Int) -> (poiId: String, name: String, description: String)? {
        let profiles = simulatedBeaconProfiles()
        guard profiles.indices.contains(minor - 1) else { return nil }
        return profiles[minor - 1]
    }

    private func simulatedBeaconProfiles() -> [(poiId: String, name: String, description: String)] {
        let primaryPOIIDs = demoFloors.first?.zones.first?.pois ?? []

        return primaryPOIIDs.compactMap { poiID in
            guard let poi = POI.seedList.first(where: { $0.id == poiID }) else { return nil }
            return (
                poiId: poi.id,
                name: "\(poi.name) beacon",
                description: "\(poi.name) nearby"
            )
        }
    }

    private func simulatedBeaconDistance(at index: Int) -> Double {
        switch index {
        case 0: return 2.5
        case 1: return 15.0
        case 2: return 25.0
        default: return 18.0
        }
    }

    private func simulatedBeaconRSSI(at index: Int) -> Int {
        switch index {
        case 0: return -65
        case 1: return -78
        case 2: return -85
        default: return -80
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension IndoorLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint) {
        Task { @MainActor in
            // Update nearby beacons
            nearbyBeacons = beacons.map { beacon in
                let profile = beaconProfile(forMinor: beacon.minor.intValue)
                return BeaconInfo(
                    id: "\(beacon.major)-\(beacon.minor)",
                    uuid: beacon.uuid,
                    major: beacon.major.intValue,
                    minor: beacon.minor.intValue,
                    name: profile?.name ?? "信标 \(beacon.major)-\(beacon.minor)",
                    description: profile?.description ?? "",
                    floor: beacon.major.intValue,
                    zone: profile?.poiId ?? "",
                    distance: beacon.accuracy,
                    rssi: beacon.rssi
                )
            }
            
            // Update positioning accuracy
            if let nearest = beacons.first {
                switch nearest.proximity {
                case .immediate:
                    positioningAccuracy = .high
                case .near:
                    positioningAccuracy = .medium
                case .far:
                    positioningAccuracy = .low
                default:
                    positioningAccuracy = .unavailable
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, rangingDidFailFor beaconConstraint: CLBeaconIdentityConstraint, error: Error) {
        Task { @MainActor in
            positioningAccuracy = .unavailable
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startIndoorPositioning()
            default:
                break
            }
        }
    }
}

// MARK: - Indoor Map View Model
@MainActor
class IndoorMapViewModel: ObservableObject {
    @Published var currentFloor = 1
    @Published var selectedZone: String?
    @Published var highlightedPOIs: [String] = []
    
    private let indoorService: IndoorLocationService
    
    init(indoorService: IndoorLocationService) {
        self.indoorService = indoorService
    }
    
    var floors: [IndoorLocationService.FloorInfo] {
        [1, 2, 3].compactMap { indoorService.getFloor($0) }
    }
    
    var currentFloorInfo: IndoorLocationService.FloorInfo? {
        indoorService.getFloor(currentFloor)
    }
    
    var zones: [IndoorLocationService.ZoneInfo] {
        indoorService.getZones(forFloor: currentFloor)
    }
    
    func selectZone(_ zone: String) {
        selectedZone = zone
        highlightedPOIs = indoorService.getPOIs(inZone: zone)
    }
    
    func switchFloor(_ floor: Int) {
        currentFloor = floor
        indoorService.switchFloor(floor)
        selectedZone = nil
        highlightedPOIs = []
    }
}
