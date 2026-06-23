// API Client - Backend Communication

import Foundation

// MARK: - API Configuration
struct APIConfig {
    static let apiVersionPath = "/api/v1"

    /// Override with `AIGUIDE_API_BASE_URL` in the scheme environment or an
    /// `AIGuideAPIBaseURL` Info.plist value when running on a physical device.
    static var baseURL: String {
        if let value = ProcessInfo.processInfo.environment["AIGUIDE_API_BASE_URL"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "AIGuideAPIBaseURL") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return "http://127.0.0.1:8000\(apiVersionPath)"
    }

    static var serverURL: String {
        guard baseURL.hasSuffix(apiVersionPath) else { return baseURL }
        return String(baseURL.dropLast(apiVersionPath.count))
    }

    static let timeout: TimeInterval = 30

    // Endpoints
    enum Endpoints {
        static let contextResolve = "/context/resolve"
        static let guideNarrate = "/guide/narrate"
        static let qaAsk = "/qa/ask"
        static let visionIdentify = "/vision/identify"
        static let feedbackReport = "/feedback/report"
        static let tripPlan = "/trip/plan"
        static let pois = "/context/pois"
        static let routes = "/routes"
    }
}

// MARK: - API Client
@MainActor
class APIClient: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var lastError: APIError?

    // MARK: - Private Properties
    private let session: URLSession
    private var authToken: String?

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic GET Request
    func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            lastError = .invalidURL
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AIGuideLocalization.current.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            lastError = .networkError(error)
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            lastError = .invalidResponse
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let error = APIError.httpError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
            lastError = error
            throw error
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            let apiError = APIError.decodingError(error)
            lastError = apiError
            throw apiError
        }
    }

    // MARK: - Generic POST Request
    func post<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            lastError = .invalidURL
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AIGuideLocalization.current.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            lastError = .networkError(error)
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            lastError = .invalidResponse
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let error = APIError.httpError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8))
            lastError = error
            throw error
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            let apiError = APIError.decodingError(error)
            lastError = apiError
            throw apiError
        }
    }

    // MARK: - Health Check
    func checkHealth() async -> Bool {
        guard let url = URL(string: APIConfig.serverURL + "/health") else {
            lastError = .invalidURL
            return false
        }

        do {
            let (_, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }

        return false
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code, let message):
            return "HTTP 错误 \(code): \(message ?? "未知错误")"
        case .decodingError(let error):
            return "解码错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
