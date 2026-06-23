// Location Service - Core Location Integration

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLHeading?
    @Published var locationError: Error?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    // MARK: - Initialization
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
    }
    
    // MARK: - Public Methods
    
    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start continuous location updates
    func startUpdating() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    /// Stop location updates
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    /// Get single location update
    func requestLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
    
    /// Calculate distance to a POI
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    /// Find nearest POI from a list
    func findNearestPOI(from pois: [POI]) -> (poi: POI, distance: CLLocationDistance)? {
        guard let currentLocation = currentLocation else { return nil }
        
        var nearest: (poi: POI, distance: CLLocationDistance)?
        
        for poi in pois {
            let targetLocation = CLLocation(latitude: poi.coordinate.latitude, longitude: poi.coordinate.longitude)
            let distance = currentLocation.distance(from: targetLocation)
            
            if nearest == nil || distance < nearest!.distance {
                nearest = (poi, distance)
            }
        }
        
        return nearest
    }
    
    /// Calculate confidence based on distance
    func calculateConfidence(distance: CLLocationDistance) -> Double {
        // Within 10 meters: 95%+
        // Within 30 meters: 80-95%
        // Within 50 meters: 60-80%
        // Beyond 50 meters: decreasing
        
        switch distance {
        case 0..<10:
            return 0.95 + (10 - distance) / 100
        case 10..<30:
            return 0.80 + (30 - distance) / 100
        case 30..<50:
            return 0.60 + (50 - distance) / 100
        case 50..<100:
            return 0.40 + (100 - distance) / 200
        default:
            return max(0.1, 1.0 - distance / 1000)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            self.locationError = nil
            
            // Resume continuation if waiting
            if let continuation = self.locationContinuation {
                continuation.resume(returning: location)
                self.locationContinuation = nil
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            self.heading = newHeading
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationError = error
            
            // Resume continuation with error if waiting
            if let continuation = self.locationContinuation {
                continuation.resume(throwing: error)
                self.locationContinuation = nil
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            // Auto-start updates if authorized
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startUpdating()
            default:
                break
            }
        }
    }
}

// MARK: - Location Permission Helper
extension LocationService {
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var permissionStatusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知"
        }
    }
}
