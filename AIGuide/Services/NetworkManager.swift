// Network Manager - Request Retry & Offline Support

import Foundation
import Network

// MARK: - Network Manager
@MainActor
class NetworkManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    // MARK: - Types
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
        
        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown: return "network"
            case .none: return "wifi.slash"
            }
        }
    }
    
    // MARK: - Singleton
    static let shared = NetworkManager()
    
    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Initialization
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start network monitoring
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Stop network monitoring
    func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Execute request with retry
    func executeWithRetry<T>(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry if not connected
                if !isConnected {
                    throw NetworkError.noConnection
                }
                
                // Wait before retry
                if attempt < maxRetries - 1 {
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.noConnection
    }
    
    // MARK: - Private Methods
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else if path.status == .satisfied {
            return .unknown
        } else {
            return .none
        }
    }
}

// MARK: - Offline Manager
@MainActor
class OfflineManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isOfflineMode = false
    @Published var pendingActions: [PendingAction] = []
    
    // MARK: - Types
    struct PendingAction: Identifiable, Codable {
        let id: String
        let type: ActionType
        let data: [String: String]
        let timestamp: Date
        
        enum ActionType: String, Codable {
            case feedback
            case favorite
            case search
            case visit
        }
    }
    
    // MARK: - Singleton
    static let shared = OfflineManager()
    
    // MARK: - Private Properties
    private let storageKey = "com.aiguide.offline.pending"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadPendingActions()
    }
    
    // MARK: - Public Methods
    
    /// Queue action for later sync
    func queueAction(type: PendingAction.ActionType, data: [String: String]) {
        let action = PendingAction(
            id: UUID().uuidString,
            type: type,
            data: data,
            timestamp: Date()
        )
        
        pendingActions.append(action)
        savePendingActions()
    }
    
    /// Sync pending actions
    func syncPendingActions() async {
        guard !pendingActions.isEmpty else { return }
        
        // TODO: Implement actual sync logic
        // For now, just clear pending actions
        pendingActions.removeAll()
        savePendingActions()
    }
    
    /// Clear all pending actions
    func clearPendingActions() {
        pendingActions.removeAll()
        savePendingActions()
    }
    
    // MARK: - Private Methods
    
    private func loadPendingActions() {
        if let data = defaults.data(forKey: storageKey),
           let actions = try? JSONDecoder().decode([PendingAction].self, from: data) {
            pendingActions = actions
        }
    }
    
    private func savePendingActions() {
        if let data = try? JSONEncoder().encode(pendingActions) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
