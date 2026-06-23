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
        case .network: return "请检查网络连接后重试"
        case .location: return "请在设置中开启定位权限"
        case .audio: return "请检查音量设置"
        case .vision: return "请确保拍摄清晰的照片"
        case .data: return "请稍后重试"
        case .permission: return "请在设置中授予相关权限"
        case .unknown: return "请稍后重试"
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
        case .noConnection: return "网络连接失败"
        case .timeout: return "请求超时"
        case .serverError(let code): return "服务器错误 (\(code))"
        case .invalidResponse: return "服务器响应无效"
        case .decodingError: return "数据解析失败"
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
        case .denied: return "定位权限被拒绝"
        case .restricted: return "定位服务受限"
        case .unavailable: return "定位服务不可用"
        case .timeout: return "定位超时"
        }
    }
}

// MARK: - Audio Errors
enum AudioError: LocalizedError {
    case playbackFailed
    case recordingFailed
    case fileNotFound
    case formatError
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed: return "播放失败"
        case .recordingFailed: return "录音失败"
        case .fileNotFound: return "音频文件不存在"
        case .formatError: return "音频格式不支持"
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
        case .loadFailed: return "数据加载失败"
        case .saveFailed: return "数据保存失败"
        case .corrupted: return "数据已损坏"
        case .notFound: return "数据不存在"
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
        case .location: return "需要定位权限"
        case .camera: return "需要相机权限"
        case .microphone: return "需要麦克风权限"
        case .photoLibrary: return "需要相册权限"
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
            case .decodingError:
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
                "出错了",
                isPresented: $errorHandler.showError,
                presenting: errorHandler.currentError
            ) { error in
                Button("确定") {
                    errorHandler.clearError()
                }
                
                if error.recoverySuggestion != nil {
                    Button("重试") {
                        // Retry logic can be added here
                        errorHandler.clearError()
                    }
                }
            } message: { error in
                VStack {
                    Text(error.errorDescription ?? "未知错误")
                    
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
                Text(error.errorDescription ?? "出错了")
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
                Button("重试") {
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
                Text(error.errorDescription ?? "出错了")
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
                    Label("重试", systemImage: "arrow.clockwise")
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
