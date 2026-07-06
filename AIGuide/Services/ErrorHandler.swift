// Error Handler - Centralized Error Management

import Foundation
import SwiftUI

// MARK: - App Error Types
enum AppError: LocalizedError, Identifiable {
    case network(NetworkError)
    case location(LocationError)
    case audio(AudioError)
    case vision(VisionError)
    case data(DataError)
    case permission(PermissionError)
    case unknown(Error)
    
    var id: String {
        errorDescription ?? "unknown"
    }
    
    var errorDescription: String? {
        switch self {
        case .network(let error): return error.localizedDescription
        case .location(let error): return error.localizedDescription
        case .audio(let error): return error.localizedDescription
        case .vision(let error): return error.localizedDescription
        case .data(let error): return error.localizedDescription
        case .permission(let error): return error.localizedDescription
        case .unknown(let error): return error.localizedDescription
        }
    }
    
    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .location: return "location.slash"
        case .audio: return "speaker.slash"
        case .vision: return "eye.slash"
        case .data: return "externaldrive.badge.xmark"
        case .permission: return "lock.shield"
        case .unknown: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .network: return .orange
        case .location: return .blue
        case .audio: return .purple
        case .vision: return .green
        case .data: return .red
        case .permission: return .yellow
        case .unknown: return .gray
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .network: return L10n.string("error.recovery.network")
        case .location: return L10n.string("error.recovery.location")
        case .audio: return L10n.string("error.recovery.audio")
        case .vision: return L10n.string("error.recovery.vision")
        case .data: return L10n.string("error.recovery.data")
        case .permission: return L10n.string("error.recovery.permission")
        case .unknown: return L10n.string("error.recovery.unknown")
        }
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(Int)
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .noConnection: return L10n.string("error.network.noConnection")
        case .timeout: return L10n.string("error.network.timeout")
        case .serverError(let code): return L10n.format("error.network.server.format", code)
        case .invalidResponse: return L10n.string("error.network.invalidResponse")
        case .decodingError: return L10n.string("error.network.decoding")
        }
    }
}

// MARK: - Location Errors
enum LocationError: LocalizedError {
    case denied
    case restricted
    case unavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .denied: return L10n.string("error.location.denied")
        case .restricted: return L10n.string("error.location.restricted")
        case .unavailable: return L10n.string("error.location.unavailable")
        case .timeout: return L10n.string("error.location.timeout")
        }
    }
}

// MARK: - Audio Errors
enum AudioError: LocalizedError {
    case playbackFailed
    case recordingFailed
    case fileNotFound
    case formatError
    case ttsUnavailable
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed: return L10n.string("error.audio.playbackFailed")
        case .recordingFailed: return L10n.string("error.audio.recordingFailed")
        case .fileNotFound: return L10n.string("error.audio.fileNotFound")
        case .formatError: return L10n.string("error.audio.formatError")
        case .ttsUnavailable: return L10n.string("error.audio.ttsUnavailable")
        }
    }
}

// MARK: - Data Errors
enum DataError: LocalizedError {
    case loadFailed
    case saveFailed
    case corrupted
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .loadFailed: return L10n.string("error.data.loadFailed")
        case .saveFailed: return L10n.string("error.data.saveFailed")
        case .corrupted: return L10n.string("error.data.corrupted")
        case .notFound: return L10n.string("error.data.notFound")
        }
    }
}

// MARK: - Permission Errors
enum PermissionError: LocalizedError {
    case location
    case camera
    case microphone
    case photoLibrary
    
    var errorDescription: String? {
        switch self {
        case .location: return L10n.string("error.permission.location")
        case .camera: return L10n.string("error.permission.camera")
        case .microphone: return L10n.string("error.permission.microphone")
        case .photoLibrary: return L10n.string("error.permission.photoLibrary")
        }
    }
}

// MARK: - Error Handler
@MainActor
class ErrorHandler: ObservableObject {
    // MARK: - Published Properties
    @Published var currentError: AppError?
    @Published var showError = false
    @Published var errorHistory: [AppError] = []
    
    // MARK: - Singleton
    static let shared = ErrorHandler()
    
    // MARK: - Public Methods
    
    /// Handle error
    func handle(_ error: Error) {
        let appError = mapError(error)
        currentError = appError
        showError = true
        errorHistory.append(appError)
        
        // Log error
        logError(appError)
    }
    
    /// Handle specific error type
    func handle(_ appError: AppError) {
        currentError = appError
        showError = true
        errorHistory.append(appError)
        
        // Log error
        logError(appError)
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        showError = false
    }
    
    /// Clear error history
    func clearHistory() {
        errorHistory = []
    }
    
    // MARK: - Private Methods
    
    private func mapError(_ error: Error) -> AppError {
        // Map common errors to AppError
        if let networkError = error as? URLError {
            switch networkError.code {
            case .notConnectedToInternet:
                return .network(.noConnection)
            case .timedOut:
                return .network(.timeout)
            default:
                return .network(.serverError(networkError.code.rawValue))
            }
        }
        
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL, .invalidResponse:
                return .network(.invalidResponse)
            case .httpError(let code, _):
                return .network(.serverError(code))
            case .encodingError, .decodingError:
                return .network(.decodingError)
            case .networkError:
                return .network(.noConnection)
            }
        }
        
        return .unknown(error)
    }
    
    private func logError(_ error: AppError) {
        #if DEBUG
        print("🔴 Error: \(error.errorDescription ?? "Unknown")")
        if let recovery = error.recoverySuggestion {
            print("💡 Recovery: \(recovery)")
        }
        #endif
    }
}

// MARK: - Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                L10n.string("common.error.generic"),
                isPresented: $errorHandler.showError,
                presenting: errorHandler.currentError
            ) { error in
                Button(L10n.string("common.ok")) {
                    errorHandler.clearError()
                }
                
                if error.recoverySuggestion != nil {
                    Button(L10n.string("common.retry")) {
                        // Retry logic can be added here
                        errorHandler.clearError()
                    }
                }
            } message: { error in
                VStack {
                    Text(error.errorDescription ?? L10n.string("error.unknown"))
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func withErrorHandler() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Error View
struct ErrorBannerView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: error.icon)
                .font(.title2)
                .foregroundStyle(error.color)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.errorDescription ?? L10n.string("common.error.generic"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Actions
            if let onRetry = onRetry {
                Button(L10n.string("common.retry")) {
                    onRetry()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(error.color.opacity(0.1))
                .foregroundStyle(error.color)
                .clipShape(Capsule())
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: error.color.opacity(0.2), radius: 4, y: 2)
    }
}

// MARK: - Error State View
struct ErrorStateView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    
    init(error: AppError, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(error.color.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: error.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(error.color)
            }
            
            // Message
            VStack(spacing: 8) {
                Text(error.errorDescription ?? L10n.string("common.error.generic"))
                    .font(.headline)
                
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Retry button
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label(L10n.string("common.retry"), systemImage: "arrow.clockwise")
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(error.color)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding()
    }
}
