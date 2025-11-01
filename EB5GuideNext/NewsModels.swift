import Foundation

// MARK: - News List

struct NewsListResponse: Codable {
    let dataVersion: String?
    let items: [NewsArticleSummary]
    let nextOffset: String?

    enum CodingKeys: String, CodingKey {
        case dataVersion = "data_version"
        case items
        case nextOffset = "next_offset"
    }

    init(
        dataVersion: String? = nil,
        items: [NewsArticleSummary] = [],
        nextOffset: String? = nil
    ) {
        self.dataVersion = dataVersion
        self.items = items
        self.nextOffset = nextOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataVersion = try container.decodeIfPresent(String.self, forKey: .dataVersion)
        items = (try? container.decode([NewsArticleSummary].self, forKey: .items)) ?? []
        nextOffset = try container.decodeIfPresent(String.self, forKey: .nextOffset)
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

    init(
        id: String,
        slug: String,
        title: String,
        publishedAt: String,
        shortDescription: String?,
        heroImage: NewsImage?,
        category: String?,
        tags: [String]?,
        published: Bool?
    ) {
        self.id = id
        self.slug = slug
        self.title = title
        self.publishedAt = publishedAt
        self.shortDescription = shortDescription
        self.heroImage = heroImage
        self.category = category
        self.tags = tags
        self.published = published
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let directID = try? container.decode(String.self, forKey: .id) {
            id = directID
        } else if let numericID = try? container.decode(Int.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = UUID().uuidString
        }
        slug = (try? container.decode(String.self, forKey: .slug)) ?? id
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        publishedAt = (try? container.decode(String.self, forKey: .publishedAt)) ?? ""
        shortDescription = try? container.decodeIfPresent(String.self, forKey: .shortDescription)
        heroImage = try? container.decodeIfPresent(NewsImage.self, forKey: .heroImage)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        tags = try? container.decodeIfPresent([String].self, forKey: .tags)
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .published) {
            published = boolValue
        } else if let numeric = try? container.decodeIfPresent(Int.self, forKey: .published) {
            published = numeric != 0
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .published) {
            published = (stringValue as NSString).boolValue
        } else {
            published = nil
        }
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

    init(
        dataVersion: String,
        id: String,
        slug: String,
        title: String,
        publishedAt: String,
        shortDescription: String?,
        heroImage: NewsImage?,
        category: String?,
        tags: [String]?,
        article: [NewsBlock],
        meta: NewsMeta?,
        relatedIDs: [String]?,
        published: Bool?,
        lang: String?
    ) {
        self.dataVersion = dataVersion
        self.id = id
        self.slug = slug
        self.title = title
        self.publishedAt = publishedAt
        self.shortDescription = shortDescription
        self.heroImage = heroImage
        self.category = category
        self.tags = tags
        self.article = article
        self.meta = meta
        self.relatedIDs = relatedIDs
        self.published = published
        self.lang = lang
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataVersion = (try? container.decode(String.self, forKey: .dataVersion)) ?? ""
        if let directID = try? container.decode(String.self, forKey: .id) {
            id = directID
        } else if let numericID = try? container.decode(Int.self, forKey: .id) {
            id = String(numericID)
        } else {
            id = UUID().uuidString
        }
        slug = (try? container.decode(String.self, forKey: .slug)) ?? id
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        publishedAt = (try? container.decode(String.self, forKey: .publishedAt)) ?? ""
        shortDescription = try? container.decodeIfPresent(String.self, forKey: .shortDescription)
        heroImage = try? container.decodeIfPresent(NewsImage.self, forKey: .heroImage)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        tags = try? container.decodeIfPresent([String].self, forKey: .tags)
        article = (try? container.decode([NewsBlock].self, forKey: .article)) ?? []
        meta = try? container.decodeIfPresent(NewsMeta.self, forKey: .meta)
        relatedIDs = try? container.decodeIfPresent([String].self, forKey: .relatedIDs)
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .published) {
            published = boolValue
        } else if let numeric = try? container.decodeIfPresent(Int.self, forKey: .published) {
            published = numeric != 0
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .published) {
            published = (stringValue as NSString).boolValue
        } else {
            published = nil
        }
        lang = try? container.decodeIfPresent(String.self, forKey: .lang)
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

    enum CodingKeys: String, CodingKey {
        case url
        case alt
        case credit
        case caption
    }

    init(url: String, alt: String, credit: String?, caption: String?) {
        self.url = url
        self.alt = alt
        self.credit = credit
        self.caption = caption
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let stringValue = try? singleValue.decode(String.self) {
            url = stringValue
            alt = ""
            credit = nil
            caption = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = (try? container.decode(String.self, forKey: .url)) ?? ""
        alt = (try? container.decode(String.self, forKey: .alt)) ?? ""
        credit = try? container.decodeIfPresent(String.self, forKey: .credit)
        caption = try? container.decodeIfPresent(String.self, forKey: .caption)
    }
}

struct NewsBlock: Codable, Hashable {
    let type: String
    let text: String?
    let level: Int?
    let title: String?
    let variant: String?
    let attribution: String?
    let items: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case level
        case title
        case variant
        case attribution
        case items
    }

    init(
        type: String,
        text: String?,
        level: Int?,
        title: String?,
        variant: String?,
        attribution: String?,
        items: [String]?
    ) {
        self.type = type
        self.text = text
        self.level = level
        self.title = title
        self.variant = variant
        self.attribution = attribution
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        if let stringText = try? container.decodeIfPresent(String.self, forKey: .text) {
            text = stringText
        } else if let arrayText = try? container.decodeIfPresent([String].self, forKey: .text) {
            text = arrayText.joined(separator: "\n")
        } else {
            text = nil
        }
        if let levelValue = try? container.decodeIfPresent(Int.self, forKey: .level) {
            level = levelValue
        } else if let stringLevel = try? container.decodeIfPresent(String.self, forKey: .level) {
            level = Int(stringLevel)
        } else {
            level = nil
        }
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        variant = try? container.decodeIfPresent(String.self, forKey: .variant)
        attribution = try? container.decodeIfPresent(String.self, forKey: .attribution)
        if let directItems = try? container.decodeIfPresent([String].self, forKey: .items) {
            items = directItems
        } else if let singleItem = try? container.decodeIfPresent(String.self, forKey: .items) {
            items = [singleItem]
        } else {
            items = nil
        }
    }
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
