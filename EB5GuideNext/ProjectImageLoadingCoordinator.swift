import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
final class ProjectImageLoadingCoordinator: ObservableObject {
    private enum Mode: Equatable {
        case idle
        case list(urls: [URL])
        case detail(projectID: String, urls: [URL])

        var urls: [URL] {
            switch self {
            case .idle:
                return []
            case .list(let urls):
                return urls
            case .detail(_, let urls):
                return urls
            }
        }
    }

    @Published private(set) var images: [String: UIImage] = [:]

    private var currentMode: Mode = .idle
    private var loadingTask: Task<Void, Never>?
    private let cache: RemoteImageCache
    private let session: URLSession

    init(cache: RemoteImageCache? = nil, session: URLSession? = nil) {
        self.cache = cache ?? RemoteImageCache.shared
        self.session = session ?? URLSession.shared
    }

    func image(for urlString: String) -> UIImage? {
        images[urlString]
    }

    func activateList(with urlStrings: [String]) {
        let ordered = uniqueURLs(from: urlStrings)
        switchToMode(.list(urls: ordered))
    }

    func pauseList() {
        if case .list = currentMode {
            switchToMode(.idle)
        }
    }

    func activateDetail(projectID: String, urls urlStrings: [String]) {
        let ordered = uniqueURLs(from: urlStrings)
        switchToMode(.detail(projectID: projectID, urls: ordered))
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

        let urls = mode.urls
        publishCachedImages(for: urls)

        guard !urls.isEmpty, mode != .idle else { return }

        loadingTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSequentially(urls: urls)
        }
    }

    private func publishCachedImages(for urls: [URL]) {
        var updated = images
        for url in urls {
            let key = url.absoluteString
            if updated[key] != nil { continue }
            if let cached = cache.image(for: url) {
                updated[key] = cached
            }
        }

        if updated != images {
            images = updated
        }
    }

    private func loadSequentially(urls: [URL]) async {
        for url in urls {
            if Task.isCancelled { break }
            if hasImage(for: url) { continue }

            do {
                if let image = try await fetchImage(from: url) {
                    if Task.isCancelled { break }
                    cache.store(image, for: url)
                    images[url.absoluteString] = image
                }
            } catch {
#if DEBUG
                print("⚠️ Failed to load project image:", url.absoluteString, error.localizedDescription)
#endif
            }
        }
    }

    private func fetchImage(from url: URL) async throws -> UIImage? {
        if let cached = cache.image(for: url) {
            return cached
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        return image
    }

    private func hasImage(for url: URL) -> Bool {
        if images[url.absoluteString] != nil {
            return true
        }
        if cache.image(for: url) != nil {
            return true
        }
        return false
    }

    private func uniqueURLs(from strings: [String]) -> [URL] {
        var seen = Set<URL>()
        var ordered: [URL] = []

        for string in strings {
            guard let url = URL(string: string) else { continue }
            if seen.insert(url).inserted {
                ordered.append(url)
            }
        }

        return ordered
    }
}
