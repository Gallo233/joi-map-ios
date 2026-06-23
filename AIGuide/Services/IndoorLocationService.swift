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
    
    // MARK: - Mock Data
    private let mockFloors: [FloorInfo] = [
        FloorInfo(id: 1, name: "一层", description: "外朝三大殿", zones: [
            ZoneInfo(id: "z1", name: "太和殿区域", floor: 1, pois: ["taihedian", "zhonghedian", "baohedian"]),
            ZoneInfo(id: "z2", name: "太和门区域", floor: 1, pois: ["taihemen", "wumen"]),
        ]),
        FloorInfo(id: 2, name: "二层", description: "内廷后三宫", zones: [
            ZoneInfo(id: "z3", name: "乾清宫区域", floor: 2, pois: ["qianqinggong", "jiaotaidian", "kunninggong"]),
        ]),
        FloorInfo(id: 3, name: "三层", description: "御花园", zones: [
            ZoneInfo(id: "z4", name: "御花园区", floor: 3, pois: ["yuhuayuan"]),
        ]),
    ]
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        setupMockBeacons()
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
        mockFloors.first { $0.id == floorNumber }
    }
    
    /// Get zones for floor
    func getZones(forFloor floor: Int) -> [ZoneInfo] {
        getFloor(floor)?.zones ?? []
    }
    
    /// Get POIs in zone
    func getPOIs(inZone zone: String) -> [String] {
        for floor in mockFloors {
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
        guard floor >= 1 && floor <= mockFloors.count else { return }
        currentFloor = floor
        
        // Update current zone
        if let floorInfo = getFloor(floor) {
            currentZone = floorInfo.zones.first?.name ?? ""
        }
    }
    
    /// Simulate indoor positioning (for demo)
    func simulateIndoorPositioning() {
        // Simulate being on floor 1, in Taihe Hall area
        currentFloor = 1
        currentZone = "太和殿区域"
        positioningAccuracy = .high
        
        // Add mock beacons
        nearbyBeacons = [
            BeaconInfo(
                id: "b1",
                uuid: UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")!,
                major: 1,
                minor: 1,
                name: "太和殿信标",
                description: "太和殿正前方",
                floor: 1,
                zone: "太和殿区域",
                distance: 2.5,
                rssi: -65
            ),
            BeaconInfo(
                id: "b2",
                uuid: UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")!,
                major: 1,
                minor: 2,
                name: "中和殿信标",
                description: "中和殿入口",
                floor: 1,
                zone: "太和殿区域",
                distance: 15.0,
                rssi: -78
            ),
            BeaconInfo(
                id: "b3",
                uuid: UUID(uuidString: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825")!,
                major: 1,
                minor: 3,
                name: "保和殿信标",
                description: "保和殿入口",
                floor: 1,
                zone: "太和殿区域",
                distance: 25.0,
                rssi: -85
            ),
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupMockBeacons() {
        // Define beacon UUIDs for the museum
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
        
        return POI.mockList.first { poi in
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
        
        return mockFloors
            .flatMap(\.zones)
            .first { $0.id == zone || $0.name == zone }
    }
    
    private func beaconProfile(forMinor minor: Int) -> (poiId: String, name: String, description: String)? {
        switch minor {
        case 1:
            return ("taihedian", "太和殿信标", "太和殿正前方")
        case 2:
            return ("zhonghedian", "中和殿信标", "中和殿入口")
        case 3:
            return ("baohedian", "保和殿信标", "保和殿入口")
        case 4:
            return ("qianqinggong", "乾清宫信标", "乾清宫入口")
        default:
            return nil
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
