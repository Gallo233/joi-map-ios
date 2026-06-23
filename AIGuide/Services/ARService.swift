// AR Service - Augmented Reality Features

import Foundation
import SwiftUI
import ARKit
import RealityKit
import CoreLocation

@MainActor
class ARService: ObservableObject {
    // MARK: - Published Properties
    @Published var isARAvailable = false
    @Published var detectedPOIs: [ARPOI] = []
    @Published var currentHeading: Double = 0
    
    // MARK: - Types
    struct ARPOI: Identifiable {
        let id: String
        let name: String
        let description: String
        let distance: Double // meters
        let bearing: Double // degrees from north
        let coordinate: CLLocationCoordinate2D
        let category: String
    }
    
    struct CompassPoint {
        let name: String
        let bearing: Double
        let distance: Double
    }
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    
    // MARK: - Initialization
    init() {
        checkARAvailability()
    }
    
    // MARK: - Public Methods
    
    /// Check if AR is available on device
    func checkARAvailability() {
        isARAvailable = ARWorldTrackingConfiguration.isSupported
    }
    
    /// Get POIs in view direction
    func getPOIsInView(heading: Double, fov: Double = 60) -> [ARPOI] {
        let minBearing = heading - fov / 2
        let maxBearing = heading + fov / 2
        
        return detectedPOIs.filter { poi in
            let bearing = poi.bearing
            if minBearing < 0 {
                return bearing >= (360 + minBearing) || bearing <= maxBearing
            } else if maxBearing > 360 {
                return bearing >= minBearing || bearing <= (maxBearing - 360)
            } else {
                return bearing >= minBearing && bearing <= maxBearing
            }
        }
    }
    
    /// Calculate bearing between two coordinates
    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }
        
        return bearing
    }
    
    /// Calculate distance between two coordinates
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// Update POIs based on current location
    func updatePOIs(userLocation: CLLocationCoordinate2D, pois: [POI]) {
        detectedPOIs = pois.map { poi in
            let bearing = calculateBearing(from: userLocation, to: poi.coordinate)
            let distance = calculateDistance(from: userLocation, to: poi.coordinate)
            
            return ARPOI(
                id: poi.id,
                name: poi.name,
                description: poi.description,
                distance: distance,
                bearing: bearing,
                coordinate: poi.coordinate,
                category: poi.category.rawValue
            )
        }
        .sorted { $0.distance < $1.distance }
    }
    
    /// Format distance for display
    func formatDistance(_ distance: Double) -> String {
        if distance < 100 {
            return "\(Int(distance))米"
        } else if distance < 1000 {
            return "\(Int(distance / 10) * 10)米"
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
    
    /// Get compass direction name
    func getCompassDirection(_ bearing: Double) -> String {
        switch bearing {
        case 0..<22.5, 337.5..<360: return "北"
        case 22.5..<67.5: return "东北"
        case 67.5..<112.5: return "东"
        case 112.5..<157.5: return "东南"
        case 157.5..<202.5: return "南"
        case 202.5..<247.5: return "西南"
        case 247.5..<292.5: return "西"
        case 292.5..<337.5: return "西北"
        default: return ""
        }
    }
}

