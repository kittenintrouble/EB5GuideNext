import Foundation

enum NewsAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid news API URL."
        case .invalidResponse:
            return "The news server returned an unexpected response."
        case .statusCode(let code):
            return "The news server returned status code \(code)."
        }
    }
}

final class NewsAPISessionDelegate: NSObject, URLSessionDelegate {
    static let shared = NewsAPISessionDelegate()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        if host == "news-service.replit.app" || host == "eb-5.app" || host == "api.eb-5.app" {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

private actor NewsEndpointHealth {
    private var primaryBackoffUntil: Date?
    private let backoffInterval: TimeInterval = 300 // 5 minutes

    func shouldUsePrimary() -> Bool {
        guard let until = primaryBackoffUntil else { return true }
        return Date() >= until
    }

    func registerPrimarySuccess() {
        primaryBackoffUntil = nil
    }

    func registerPrimaryFailure() {
        primaryBackoffUntil = Date().addingTimeInterval(backoffInterval)
    }
}

final class NewsAPIService {
    private static let health = NewsEndpointHealth()
    private let primaryBaseURL = URL(string: "https://api.eb-5.app")!
    private let fallbackBaseURL = URL(string: "https://news-service.replit.app")!
    private let session: URLSession
    private let sessionDelegate: NewsAPISessionDelegate?

    init(session: URLSession? = nil) {
        if let providedSession = session {
            self.session = providedSession
            self.sessionDelegate = nil
        } else {
            let delegate = NewsAPISessionDelegate.shared
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = true
            self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            self.sessionDelegate = delegate
        }
    }

    func fetchNews(language: String? = nil) async throws -> NewsListResponse {
        let lang = resolveLanguage(language)
        return try await fetchWithFallback(path: "/news", language: lang)
    }

    func fetchNewsDetail(id: String, language: String? = nil) async throws -> NewsArticleDetail {
        let lang = resolveLanguage(language)
        return try await fetchWithFallback(path: "/news/\(id)", language: lang)
    }

    private func fetchWithFallback<T: Decodable>(path: String, language: String) async throws -> T {
        var firstError: Error?

        if await NewsAPIService.health.shouldUsePrimary() {
            do {
                let value: T = try await fetch(from: primaryBaseURL, path: path, language: language)
                await NewsAPIService.health.registerPrimarySuccess()
                return value
            } catch {
                firstError = error
                await NewsAPIService.health.registerPrimaryFailure()
            }
        }

        do {
            return try await fetch(from: fallbackBaseURL, path: path, language: language)
        } catch {
            throw firstError ?? error
        }
    }

    private func fetch<T: Decodable>(from baseURL: URL, path: String, language: String) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NewsAPIError.invalidURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "lang", value: language))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw NewsAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NewsAPIError.invalidResponse
        }

        guard 200..<300 ~= http.statusCode else {
            throw NewsAPIError.statusCode(http.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func resolveLanguage(_ code: String?) -> String {
        guard var normalized = code?.lowercased(), !normalized.isEmpty else {
            return "en"
        }

        if let hyphenIndex = normalized.firstIndex(of: "-") {
            normalized = String(normalized[..<hyphenIndex])
        }

        switch normalized {
        case "zh":
            return "zh"
        case "vi":
            return "vi"
        case "ko":
            return "ko"
        default:
            return "en"
        }
    }
}

enum NewsNetwork {
    static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration, delegate: NewsAPISessionDelegate.shared, delegateQueue: nil)
    }()
}
