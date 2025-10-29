import Foundation

// MARK: - News List

struct NewsListResponse: Codable {
    let dataVersion: String
    let items: [NewsArticleSummary]
    let nextOffset: String?

    enum CodingKeys: String, CodingKey {
        case dataVersion = "data_version"
        case items
        case nextOffset = "next_offset"
    }
}

struct NewsArticleSummary: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let title: String
    let publishedAt: String
    let shortDescription: String?
    let heroImage: NewsImage?
    let category: String?
    let tags: [String]?
    let published: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case title
        case publishedAt = "published_at"
        case shortDescription = "short_description"
        case heroImage = "hero_image"
        case category
        case tags
        case published
    }
}

// MARK: - News Detail

struct NewsArticleDetail: Codable {
    let dataVersion: String
    let id: String
    let slug: String
    let title: String
    let publishedAt: String
    let shortDescription: String?
    let heroImage: NewsImage?
    let category: String?
    let tags: [String]?
    let article: [NewsBlock]
    let meta: NewsMeta?
    let relatedIDs: [String]?
    let published: Bool?
    let lang: String?

    enum CodingKeys: String, CodingKey {
        case dataVersion = "data_version"
        case id
        case slug
        case title
        case publishedAt = "published_at"
        case shortDescription = "short_description"
        case heroImage = "hero_image"
        case category
        case tags
        case article
        case meta
        case relatedIDs = "related_ids"
        case published
        case lang
    }
}

struct NewsMeta: Codable {
    let seoTitle: String?
    let seoDescription: String?

    enum CodingKeys: String, CodingKey {
        case seoTitle = "seo_title"
        case seoDescription = "seo_description"
    }
}

// MARK: - Shared Models

struct NewsImage: Codable, Hashable {
    let url: String
    let alt: String
    let credit: String?
    let caption: String?
}

struct NewsBlock: Codable, Hashable {
    let type: String
    let text: String?
    let level: Int?
    let title: String?
    let variant: String?
    let attribution: String?
    let items: [String]?
}

// MARK: - Computed helpers

extension NewsArticleSummary {
    var publishedDate: Date? {
        ISO8601DateFormatter.newsAPIDecoder.date(from: publishedAt)
    }

    func formattedDate(locale: Locale) -> String {
        guard let date = publishedDate else { return publishedAt }
        return DateFormatter.newsFriendly(locale: locale).string(from: date)
    }

    var displayShortDescription: String {
        let trimmed = shortDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "" : trimmed
    }
}

extension NewsArticleDetail {
    var publishedDate: Date? {
        ISO8601DateFormatter.newsAPIDecoder.date(from: publishedAt)
    }

    func formattedDate(locale: Locale) -> String {
        guard let date = publishedDate else { return publishedAt }
        return DateFormatter.newsFriendly(locale: locale).string(from: date)
    }

    var estimatedWordCount: Int {
        article.reduce(into: 0) { total, block in
            total += block.wordCount
        }
    }

    var asSummary: NewsArticleSummary {
        NewsArticleSummary(
            id: id,
            slug: slug,
            title: title,
            publishedAt: publishedAt,
            shortDescription: shortDescription,
            heroImage: heroImage,
            category: category,
            tags: tags,
            published: published
        )
    }
}

private extension NewsBlock {
    var wordCount: Int {
        var count = 0
        if let text {
            count += text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        }
        if let items {
            for item in items {
                count += item.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            }
        }
        return count
    }
}

private extension ISO8601DateFormatter {
    static let newsAPIDecoder: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static func newsFriendly(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = locale
        return formatter
    }
}
