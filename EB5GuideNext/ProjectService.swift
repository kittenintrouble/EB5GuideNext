import Foundation
import Combine

@MainActor
final class ProjectService: ObservableObject {
    static let shared = ProjectService()

    private let dataBaseURL = "https://api.eb-5.app"
    private let formBaseURL = "https://news-service.replit.app"
    private let session: URLSession
    private let sessionDelegate = TrustingURLSessionDelegate()
    private let inquiryURL: URL

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: nil)
        inquiryURL = URL(string: "\(formBaseURL)/api/project-form")!
    }

    func fetchProjects(lang: String) async throws -> ProjectsResponse {
        let path = "/projects"
        let items = [URLQueryItem(name: "lang", value: lang)]
        return try await requestWithFallback(path: path, queryItems: items)
    }

    func fetchProject(id: String, lang: String) async throws -> Project {
        let path = "/projects/\(id)"
        let items = [URLQueryItem(name: "lang", value: lang)]
        return try await requestWithFallback(path: path, queryItems: items)
    }

    func submitInquiry(form: ProjectInquiry) async throws -> InquiryResponse {
        var request = URLRequest(url: inquiryURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(form)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

#if DEBUG
            print("📍 Inquiry URL:", inquiryURL.absoluteString)
            print("📊 Inquiry Status:", httpResponse.statusCode)
            if let preview = String(data: data, encoding: .utf8) {
                print("📦 Inquiry Response:", preview.prefix(400))
            }
#endif

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            if httpResponse.statusCode == 201 {
                return try decoder.decode(InquiryResponse.self, from: data)
            }

            let errorResponse = try decoder.decode(InquiryResponse.self, from: data)
            throw ProjectError.inquiryFailed(errorResponse.error ?? errorResponse.message ?? NSLocalizedString("projects.inquiry.error.generic", comment: ""))
        } catch {
            throw error
        }
    }

    private func requestWithFallback<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let bases = [dataBaseURL, formBaseURL]
        var lastError: Error?

        for base in bases {
            do {
                let url = makeURL(base: base, path: path, queryItems: queryItems)
                return try await performRequest(url: url)
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError ?? URLError(.cannotLoadFromNetwork)
    }

    private func makeURL(base: String, path: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(string: "\(base)\(path)")!
        components.queryItems = queryItems
        return components.url!
    }

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

#if DEBUG
        print("📍 URL:", url.absoluteString)
        print("📊 Status:", httpResponse.statusCode)
        if let preview = String(data: data, encoding: .utf8) {
            print("📦 Response:", preview.prefix(400))
        }
#endif

        if httpResponse.statusCode == 404 {
            throw ProjectError.notFound
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}

enum ProjectError: LocalizedError {
    case notFound
    case inquiryFailed(String)

    var isNotFound: Bool {
        if case .notFound = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .notFound:
            return NSLocalizedString("projects.error.not_found", comment: "")
        case .inquiryFailed(let message):
            return message
        }
    }
}

private final class TrustingURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
