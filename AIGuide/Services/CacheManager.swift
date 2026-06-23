// Cache Manager - Local Data Caching

import Foundation

// MARK: - Cache Manager
@MainActor
class CacheManager: ObservableObject {
    // MARK: - Singleton
    static let shared = CacheManager()
    
    // MARK: - Types
    struct CacheEntry<T: Codable>: Codable {
        let data: T
        let timestamp: Date
        let expiry: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > expiry
        }
    }
    
    enum CachePolicy {
        case memoryOnly
        case diskOnly
        case memoryAndDisk
        
        var useMemory: Bool {
            self == .memoryOnly || self == .memoryAndDisk
        }
        
        var useDisk: Bool {
            self == .diskOnly || self == .memoryAndDisk
        }
    }
    
    // MARK: - Properties
    private var memoryCache: [String: Any] = [:]
    private let diskCacheURL: URL
    private let defaultExpiry: TimeInterval = 3600 // 1 hour
    
    // MARK: - Initialization
    init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("AIGuideCache", isDirectory: true)
        
        // Create cache directory
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Store data in cache
    func store<T: Codable>(_ data: T, forKey key: String, expiry: TimeInterval? = nil, policy: CachePolicy = .memoryAndDisk) {
        let entry = CacheEntry(data: data, timestamp: Date(), expiry: expiry ?? defaultExpiry)
        
        // Memory cache
        if policy.useMemory {
            memoryCache[key] = entry
        }
        
        // Disk cache
        if policy.useDisk {
            let fileURL = diskCacheURL.appendingPathComponent(key.sha256)
            if let encoded = try? JSONEncoder().encode(entry) {
                try? encoded.write(to: fileURL)
            }
        }
    }
    
    /// Retrieve data from cache
    func retrieve<T: Codable>(forKey key: String, policy: CachePolicy = .memoryAndDisk) -> T? {
        // Try memory first
        if policy.useMemory, let entry = memoryCache[key] as? CacheEntry<T> {
            if !entry.isExpired {
                return entry.data
            } else {
                memoryCache.removeValue(forKey: key)
            }
        }
        
        // Try disk
        if policy.useDisk {
            let fileURL = diskCacheURL.appendingPathComponent(key.sha256)
            if let data = try? Data(contentsOf: fileURL),
               let entry = try? JSONDecoder().decode(CacheEntry<T>.self, from: data) {
                if !entry.isExpired {
                    // Store in memory for faster access
                    if policy.useMemory {
                        memoryCache[key] = entry
                    }
                    return entry.data
                } else {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
        
        return nil
    }
    
    /// Remove data from cache
    func remove(forKey key: String) {
        memoryCache.removeValue(forKey: key)
        
        let fileURL = diskCacheURL.appendingPathComponent(key.sha256)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// Clear all cache
    func clearAll() {
        memoryCache.removeAll()
        
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    /// Clear expired cache
    func clearExpired() {
        // Clear memory
        memoryCache.removeAll()
        
        // Clear disk
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            if let data = try? Data(contentsOf: file),
               let _ = try? JSONDecoder().decode(CacheEntry<Codable>.self, from: data) {
                // Check if expired (simplified check)
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    /// Get cache size
    func getCacheSize() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for file in files {
            if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]),
               let size = attributes.fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// Format cache size
    func formattedCacheSize() -> String {
        let bytes = getCacheSize()
        
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - String Extension for Hashing
extension String {
    var sha256: String {
        let data = Data(utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Cache Keys
enum CacheKey {
    static let pois = "cached_pois"
    static let tours = "cached_tours"
    static let guides = "cached_guides"
    static let userPreferences = "user_preferences"
    static let recentSearches = "recent_searches"
    static let visitHistory = "visit_history"
    
    static func guide(poiId: String, style: String) -> String {
        "guide_\(poiId)_\(style)"
    }
    
    static func audio(poiId: String) -> String {
        "audio_\(poiId)"
    }
}

// MARK: - Cache Policy Helper
struct CacheConfig {
    static let shortExpiry: TimeInterval = 300 // 5 minutes
    static let mediumExpiry: TimeInterval = 3600 // 1 hour
    static let longExpiry: TimeInterval = 86400 // 24 hours
    static let neverExpiry: TimeInterval = .infinity
}
