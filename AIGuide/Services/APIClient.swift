// API Client - Backend Communication

import Foundation

// MARK: - API Configuration
struct APIConfig {
    static let apiVersionPath = "/api/v1"
    private static let defaultServerURL = "http://127.0.0.1:8000"

    /// Override with `AIGUIDE_API_BASE_URL` for a full API root, or
    /// `AIGUIDE_SERVER_URL` for a server root that should receive `/api/v1`.
    static var baseURL: String {
        if let value = configuredValue(environmentKey: "AIGUIDE_API_BASE_URL", plistKey: "AIGuideAPIBaseURL") {
            return normalizedURLString(value)
        }

        if let value = configuredValue(environmentKey: "AIGUIDE_SERVER_URL", plistKey: "AIGuideServerURL") {
            return normalizedURLString(value, appendingAPIVersion: true)
        }

        return normalizedURLString(defaultServerURL, appendingAPIVersion: true)
    }

    static var serverURL: String {
        let normalizedBaseURL = normalizedURLString(baseURL)
        guard normalizedBaseURL.hasSuffix(apiVersionPath) else { return normalizedBaseURL }
        return String(normalizedBaseURL.dropLast(apiVersionPath.count))
    }

    static var healthURL: URL? {
        URL(string: "\(serverURL)/health")
    }

    static func url(for endpoint: String) -> URL? {
        let normalizedEndpoint = endpoint.hasPrefix("/") ? endpoint : "/\(endpoint)"
        return URL(string: "\(baseURL)\(normalizedEndpoint)")
    }

    static let timeout: TimeInterval = 30
    static let healthTimeout: TimeInterval = 8
    static let maxRetryCount = 2
    static let retryBaseDelay: TimeInterval = 0.8

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

    private static func configuredValue(environmentKey: String, plistKey: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[environmentKey],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        return nil
    }

    private static func normalizedURLString(
        _ value: String,
        appendingAPIVersion: Bool = false
    ) -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        guard !normalized.isEmpty else {
            return normalizedURLString(defaultServerURL, appendingAPIVersion: appendingAPIVersion)
        }

        if appendingAPIVersion && !normalized.hasSuffix(apiVersionPath) {
            normalized += apiVersionPath
        }

        return normalized
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

    // MARK: - Language Context

    static func languageContextPayload() -> [String: Any] {
        let language = AIGuideLocalization.current
        return [
            "language": language.backendLanguage,
            "locale": language.identifier,
            "region": language.userRegion,
            "response_instruction": language.llmResponseInstruction
        ]
    }

    static func localizedBody(_ body: [String: Any]) -> [String: Any] {
        var localizedBody = body
        for (key, value) in languageContextPayload() where localizedBody[key] == nil {
            localizedBody[key] = value
        }

        if var context = localizedBody["context"] as? [String: Any],
           context["response_instruction"] == nil,
           let instruction = localizedBody["response_instruction"] {
            context["response_instruction"] = instruction
            localizedBody["context"] = context
        }

        return localizedBody
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    // MARK: - Generic GET Request
    func get<T: Decodable>(endpoint: String) async throws -> T {
        try await request(endpoint: endpoint, method: "GET")
    }

    // MARK: - Generic POST Request
    func post<T: Decodable>(
        endpoint: String,
        body: [String: Any],
        includeLanguageContext: Bool = true
    ) async throws -> T {
        try await request(
            endpoint: endpoint,
            method: "POST",
            body: includeLanguageContext ? Self.localizedBody(body) : body
        )
    }

    // MARK: - Health Check
    func checkHealth() async -> Bool {
        guard let url = APIConfig.healthURL else {
            lastError = .invalidURL
            isConnected = false
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.healthTimeout
        applyDefaultHeaders(to: &request, hasBody: false)

        do {
            let (_, response) = try await send(request)
            isConnected = (200...299).contains(response.statusCode)
            return isConnected
        } catch {
            lastError = apiError(from: error)
            isConnected = false
            return false
        }
    }

    // MARK: - Private Request Pipeline

    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = APIConfig.url(for: endpoint) else {
            lastError = .invalidURL
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        applyDefaultHeaders(to: &request, hasBody: body != nil)

        if let body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                let apiError = APIError.encodingError(error)
                lastError = apiError
                throw apiError
            }
        }

        let data: Data
        do {
            let result = try await send(request)
            data = result.data
        } catch {
            let apiError = apiError(from: error)
            lastError = apiError
            throw apiError
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(T.self, from: data)
            lastError = nil
            return decoded
        } catch {
            let apiError = APIError.decodingError(error)
            lastError = apiError
            throw apiError
        }
    }

    private func applyDefaultHeaders(to request: inout URLRequest, hasBody: Bool) {
        let language = AIGuideLocalization.current
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(language.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        request.setValue(language.identifier, forHTTPHeaderField: "X-AIGuide-Locale")
        request.setValue(language.userRegion, forHTTPHeaderField: "X-AIGuide-Region")

        if hasBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        var lastRequestError: APIError?

        for attempt in 0...APIConfig.maxRetryCount {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw APIError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: Self.errorMessage(from: data)
                    )
                }

                isConnected = true
                return (data, httpResponse)
            } catch {
                let apiError = apiError(from: error)
                lastRequestError = apiError
                lastError = apiError

                guard shouldRetry(apiError), attempt < APIConfig.maxRetryCount else {
                    if case .networkError = apiError {
                        isConnected = false
                    }
                    throw apiError
                }

                let delay = APIConfig.retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastRequestError ?? APIError.invalidResponse
    }

    private func apiError(from error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        return .networkError(error)
    }

    private func shouldRetry(_ error: APIError) -> Bool {
        if Task.isCancelled {
            return false
        }

        switch error {
        case .httpError(let statusCode, _):
            return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
        case .networkError(let error):
            guard let urlError = error as? URLError else { return true }
            switch urlError.code {
            case .cancelled, .notConnectedToInternet, .userAuthenticationRequired:
                return false
            default:
                return true
            }
        case .invalidResponse:
            return true
        case .invalidURL, .encodingError, .decodingError:
            return false
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let dictionary = jsonObject as? [String: Any] {
            for key in ["message", "error", "detail"] {
                if let message = dictionary[key] as? String {
                    return message
                }

                if let value = dictionary[key] {
                    return String(describing: value)
                }
            }
        }

        return String(data: data, encoding: .utf8)
    }
}

// MARK: - API Error
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case encodingError(Error)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.string("api.error.invalidURL")
        case .invalidResponse:
            return L10n.string("api.error.invalidResponse")
        case .httpError(let code, let message):
            if code == 429 {
                return Self.messageWithBackendDetail("api.error.rateLimited", detail: message)
            }
            if code == 408 {
                return Self.messageWithBackendDetail("api.error.timeout", detail: message)
            }
            if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return L10n.format("api.error.httpWithMessage.format", code, message)
            }
            return L10n.format("api.error.http.format", code)
        case .encodingError(let error):
            return L10n.format("api.error.encoding.format", error.localizedDescription)
        case .decodingError(let error):
            return L10n.format("api.error.decoding.format", error.localizedDescription)
        case .networkError(let error):
            return L10n.format("api.error.network.format", error.localizedDescription)
        }
    }

    private static func messageWithBackendDetail(_ key: String, detail: String?) -> String {
        let base = L10n.string(key)
        guard let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines),
              !detail.isEmpty else {
            return base
        }
        return "\(base) \(detail)"
    }
}
