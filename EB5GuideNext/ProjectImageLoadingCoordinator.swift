import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class ProjectImageLoadingCoordinator: ObservableObject {
    private struct ImageRequest: Equatable, Hashable {
        let original: String
        let fetch: URL
    }

    private enum Mode: Equatable {
        case idle
        case list(requests: [ImageRequest])
        case detail(projectID: String, requests: [ImageRequest])

        var requests: [ImageRequest] {
            switch self {
            case .idle:
                return []
            case .list(let requests):
                return requests
            case .detail(_, let requests):
                return requests
            }
        }
    }

    @Published private(set) var images: [String: UIImage] = [:]

    private var currentMode: Mode = .idle
    private var loadingTask: Task<Void, Never>?
    private let cache: RemoteImageCache
    private let session: URLSession
    private var lastListRequests: [ImageRequest] = []

    init(cache: RemoteImageCache? = nil, session: URLSession? = nil) {
        self.cache = cache ?? RemoteImageCache.shared
        self.session = session ?? ProjectImageLoadingCoordinator.defaultSession
    }

    func image(for urlString: String) -> UIImage? {
        if let image = images[urlString] {
            return image
        }
        guard let normalized = normalizedURL(from: urlString) else { return nil }
        return cache.image(for: normalized)
    }

    func activateList(with urlStrings: [String]) {
        let requests = imageRequests(from: urlStrings)
        lastListRequests = requests
        switchToMode(.list(requests: requests))
    }

    func pauseList() {
        if case .list = currentMode {
            switchToMode(.idle)
        }
    }

    func resumeList() {
        guard !lastListRequests.isEmpty else { return }
        switchToMode(.list(requests: lastListRequests))
    }

    func activateDetail(projectID: String, urls urlStrings: [String]) {
        let requests = imageRequests(from: urlStrings)
        switchToMode(.detail(projectID: projectID, requests: requests))
    }

    func pauseDetail(for projectID: String) {
        if case .detail(let currentID, _) = currentMode, currentID == projectID {
            switchToMode(.idle)
        }
    }

    private func switchToMode(_ mode: Mode) {
        if currentMode == mode { return }

        loadingTask?.cancel()
        loadingTask = nil
        currentMode = mode

        let requests = mode.requests
        publishCachedImages(for: requests)

        guard !requests.isEmpty, mode != .idle else { return }

        loadingTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSequentially(requests: requests)
        }
    }

    private func publishCachedImages(for requests: [ImageRequest]) {
        var updated = images
        for request in requests {
            if updated[request.original] != nil { continue }
            if let cached = cache.image(for: request.fetch) {
                updated[request.original] = cached
            }
        }

        if updated != images {
            images = updated
        }
    }

    private func loadSequentially(requests: [ImageRequest]) async {
        for request in requests {
            if Task.isCancelled { break }
            if hasImage(for: request) { continue }

            do {
                if let image = try await fetchImage(for: request) {
                    if Task.isCancelled { break }
                    var snapshot = images
                    snapshot[request.original] = image
                    images = snapshot
                }
            } catch {
                if error is CancellationError { continue }
                if (error as? URLError)?.code == .cancelled { continue }
#if DEBUG
                print("⚠️ Failed to load project image:", request.fetch.absoluteString, error.localizedDescription)
#endif
            }
        }
    }

    private func fetchImage(for request: ImageRequest) async throws -> UIImage? {
        if let cached = cache.image(for: request.fetch) {
            images[request.original] = cached
            return cached
        }

        var urlRequest = URLRequest(url: request.fetch)
        urlRequest.cachePolicy = .returnCacheDataElseLoad
        urlRequest.timeoutInterval = 35

        let (data, response) = try await session.data(for: urlRequest)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        if image.size.width <= 0 || image.size.height <= 0 {
            throw URLError(.cannotDecodeContentData)
        }

        cache.store(image, for: request.fetch)
        return image
    }

    private func hasImage(for request: ImageRequest) -> Bool {
        if let memory = images[request.original] {
            if memory.isRenderable {
                return true
            } else {
                images.removeValue(forKey: request.original)
            }
        }
        if let cached = cache.image(for: request.fetch) {
            images[request.original] = cached
            return true
        }
        return false
    }

    private func imageRequests(from strings: [String]) -> [ImageRequest] {
        var seenOriginal = Set<String>()
        var requests: [ImageRequest] = []

        for string in strings {
            guard seenOriginal.insert(string).inserted else { continue }
            guard let normalized = normalizedURL(from: string) else { continue }
            requests.append(ImageRequest(original: string, fetch: normalized))
        }

        return requests
    }

    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 90
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration)
    }()

    private func normalizedURL(from urlString: String) -> URL? {
        RemoteImageURLNormalizer.url(from: urlString)
    }
}
