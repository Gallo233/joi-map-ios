// Data Persistence Manager

import Foundation

// MARK: - Persistence Manager
@MainActor
class PersistenceManager: ObservableObject {
    // MARK: - Singleton
    static let shared = PersistenceManager()
    
    // MARK: - Types
    enum StorageKey: String {
        case visitHistory
        case favoritePOIs
        case recentSearches
        case userSettings
        case cachedPOIs
        case cachedTours
        case lastSyncDate
    }
    
    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    init() {
        setupEncoder()
    }
    
    // MARK: - Public Methods
    
    /// Save codable object
    func save<T: Codable>(_ object: T, forKey key: StorageKey) {
        do {
            let data = try encoder.encode(object)
            defaults.set(data, forKey: key.rawValue)
        } catch {
            print("Failed to save \(key.rawValue): \(error)")
        }
    }
    
    /// Load codable object
    func load<T: Codable>(forKey key: StorageKey) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else {
            return nil
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Failed to load \(key.rawValue): \(error)")
            return nil
        }
    }
    
    /// Save primitive value
    func saveValue(_ value: Any, forKey key: StorageKey) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    /// Load primitive value
    func loadValue(forKey key: StorageKey) -> Any? {
        defaults.value(forKey: key.rawValue)
    }
    
    /// Remove value
    func remove(forKey key: StorageKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
    
    /// Clear all data
    func clearAll() {
        StorageKey.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
        }
    }
    
    /// Check if key exists
    func exists(forKey key: StorageKey) -> Bool {
        defaults.object(forKey: key.rawValue) != nil
    }
    
    /// Get storage size
    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0
        
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier) ?? [:]
        
        for (_, value) in domain {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: false) {
                totalSize += Int64(data.count)
            }
        }
        
        return totalSize
    }
    
    /// Format storage size
    func formattedStorageSize() -> String {
        let bytes = getStorageSize()
        
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEncoder() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
}

// MARK: - Storage Key Extension
extension PersistenceManager.StorageKey: CaseIterable {}

// MARK: - Data Migration
extension PersistenceManager {
    /// Migrate data from old version
    func migrateDataIfNeeded() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let lastVersion = defaults.string(forKey: "lastAppVersion") ?? "0"
        
        if currentVersion != lastVersion {
            performMigration(from: lastVersion, to: currentVersion)
            defaults.set(currentVersion, forKey: "lastAppVersion")
        }
    }
    
    private func performMigration(from oldVersion: String, to newVersion: String) {
        print("Migrating data from \(oldVersion) to \(newVersion)")
        
        // Add migration logic here as needed
        // Example:
        // if oldVersion < "2" {
        //     // Migrate v1 to v2
        // }
    }
}
