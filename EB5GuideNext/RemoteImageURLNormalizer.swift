import Foundation

enum RemoteImageURLNormalizer {
    private static let preferredHost = "eb-5.app"

    static func url(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let existing = URL(string: trimmed), existing.scheme != nil {
            return normalized(url: existing)
        }

        let path = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
        var components = URLComponents()
        components.scheme = "https"
        components.host = preferredHost
        components.path = path
        return components.url
    }

    static func normalized(url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "https"
        components.host = preferredHost
        if components.path.isEmpty {
            components.path = "/"
        }
        return components.url
    }
}
