import Foundation

final class NewsImageLoader {
    static let shared = NewsImageLoader()

    private init() {}

    func dataTask(for request: URLRequest) async throws -> (Data, URLResponse) {
        let session = NewsNetwork.sharedSession
        let task = try await session.data(for: request, delegate: nil)
        return task
    }
}
