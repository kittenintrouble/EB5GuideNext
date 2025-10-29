import Foundation
import Combine

struct EB5Article: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let category: String
    let subcategory: String
    let description: String
    let shortDescription: String?
    let examples: [String]?
    let dayNumber: Int?
}

struct CategorySummary: Identifiable, Hashable {
    let name: String
    let articles: [EB5Article]

    var id: String { name }

    var totalCount: Int { articles.count }
}

struct SubcategorySummary: Identifiable, Hashable {
    let name: String
    let canonicalName: String?
    let articles: [EB5Article]

    var id: String { canonicalName ?? name }

    var totalCount: Int { articles.count }
}

final class BaseContentStore: ObservableObject {
    @Published private(set) var articles: [EB5Article] = []
    @Published private(set) var favoriteIDs: Set<Int>
    @Published private(set) var completedIDs: Set<Int>

    private let defaults: UserDefaults
    private var englishReferenceByID: [Int: EB5Article] = [:]
    private var subcategoryOrderByCategory: [String: [String]] = [:]

    private static let favoritesKey = "base.favorite.article_ids"
    private static let completedKey = "base.completed.article_ids"
    static let categoryOrder = [
        "Compliance",
        "EB-5 Basics",
        "Foundations",
        "Immigration & Legal Process",
        "Investment",
        "Real Estate & Business",
        "Risk Management"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoriteIDs = BaseContentStore.loadIDs(forKey: BaseContentStore.favoritesKey, defaults: defaults)
        self.completedIDs = BaseContentStore.loadIDs(forKey: BaseContentStore.completedKey, defaults: defaults)
    }

    func loadArticles(for localeIdentifier: String) {
        let decoder = JSONDecoder()
        let candidates = localeCandidates(for: localeIdentifier)
        loadEnglishReferenceIfNeeded()

        for candidate in candidates {
            guard let url = Bundle.main.url(
                forResource: "eb5_terms",
                withExtension: "json",
                subdirectory: nil,
                localization: candidate
            ) else { continue }

            do {
                let data = try Data(contentsOf: url)
                let decoded = try decoder.decode([EB5Article].self, from: data)
                applyDecodedArticles(decoded)
                return
            } catch {
                continue
            }
        }

        DispatchQueue.main.async {
            self.articles = []
        }
    }

    var categories: [CategorySummary] {
        let grouped = Dictionary(grouping: articles, by: { $0.category })
        return grouped.map { CategorySummary(name: $0.key, articles: $0.value) }
            .sorted { lhs, rhs in
                let lhsIndex = categorySortIndex(for: lhs.articles)
                let rhsIndex = categorySortIndex(for: rhs.articles)
                if lhsIndex == rhsIndex {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhsIndex < rhsIndex
            }
    }

    func subcategories(in category: String) -> [SubcategorySummary] {
        let filtered = articles.filter { $0.category == category }
        let grouped = Dictionary(grouping: filtered, by: { $0.subcategory })

        return grouped.map { entry in
            let articles = entry.value
            return SubcategorySummary(
                name: entry.key,
                canonicalName: canonicalSubcategoryName(for: articles),
                articles: articles
            )
        }
        .sorted { lhs, rhs in
            let lhsIndex = subcategorySortIndex(for: lhs.articles)
            let rhsIndex = subcategorySortIndex(for: rhs.articles)
            if lhsIndex == rhsIndex {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhsIndex < rhsIndex
        }
    }

    func articles(in category: String, subcategory: String) -> [EB5Article] {
        articles.filter { $0.category == category && $0.subcategory == subcategory }
    }

    func appearanceCategoryName(for articles: [EB5Article]) -> String? {
        loadEnglishReferenceIfNeeded()
        guard let first = articles.first else { return nil }
        return appearanceCategoryName(forArticleID: first.id)
    }

    func appearanceCategoryName(forArticleID id: Int) -> String? {
        loadEnglishReferenceIfNeeded()
        return englishReferenceByID[id]?.category
    }

    func canonicalSubcategoryName(forArticleID id: Int) -> String? {
        loadEnglishReferenceIfNeeded()
        return englishReferenceByID[id]?.subcategory
    }

    func canonicalSubcategoryName(for articles: [EB5Article]) -> String? {
        loadEnglishReferenceIfNeeded()
        guard let first = articles.first else { return nil }
        return englishReferenceByID[first.id]?.subcategory
    }

    private func categorySortIndex(for articles: [EB5Article]) -> Int {
        if let canonical = appearanceCategoryName(for: articles),
           let index = BaseContentStore.categoryOrder.firstIndex(of: canonical) {
            return index
        }
        return BaseContentStore.categoryOrder.count
    }

    private func subcategorySortIndex(for articles: [EB5Article]) -> Int {
        guard let canonicalCategory = appearanceCategoryName(for: articles),
              let canonicalSubcategory = canonicalSubcategoryName(for: articles),
              let order = subcategoryOrderByCategory[canonicalCategory],
              let index = order.firstIndex(of: canonicalSubcategory) else {
            return Int.max
        }
        return index
    }

    func article(withID id: Int) -> EB5Article? {
        articles.first { $0.id == id }
    }

    func completionCount(for articles: [EB5Article]) -> Int {
        articles.reduce(into: 0) { partialResult, article in
            if completedIDs.contains(article.id) {
                partialResult += 1
            }
        }
    }

    func isCompleted(_ articleID: Int) -> Bool {
        completedIDs.contains(articleID)
    }

    func toggleCompleted(for articleID: Int) {
        performOnMain {
            if self.completedIDs.contains(articleID) {
                self.completedIDs.remove(articleID)
            } else {
                self.completedIDs.insert(articleID)
            }
            self.persist(self.completedIDs, key: BaseContentStore.completedKey)
        }
    }

    func isFavorite(_ articleID: Int) -> Bool {
        favoriteIDs.contains(articleID)
    }

    func toggleFavorite(for articleID: Int) {
        performOnMain {
            if self.favoriteIDs.contains(articleID) {
                self.favoriteIDs.remove(articleID)
            } else {
                self.favoriteIDs.insert(articleID)
            }
            self.persist(self.favoriteIDs, key: BaseContentStore.favoritesKey)
        }
    }

    // MARK: - Helpers

    private func applyDecodedArticles(_ decoded: [EB5Article]) {
        DispatchQueue.main.async {
            let validIDs = Set(decoded.map(\.id))
            let newFavorites = self.favoriteIDs.intersection(validIDs)
            if newFavorites != self.favoriteIDs {
                self.favoriteIDs = newFavorites
                self.persist(newFavorites, key: BaseContentStore.favoritesKey)
            }

            let newCompleted = self.completedIDs.intersection(validIDs)
            if newCompleted != self.completedIDs {
                self.completedIDs = newCompleted
                self.persist(newCompleted, key: BaseContentStore.completedKey)
            }

            self.articles = decoded
        }
    }

    private func performOnMain(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async {
                updates()
            }
        }
    }

    private func localeCandidates(for identifier: String) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()

        func append(_ value: String?) {
            guard let value, !value.isEmpty else { return }
            if !seen.contains(value) {
                unique.append(value)
                seen.insert(value)
            }
        }

        append(identifier)
        append(Locale(identifier: identifier).language.languageCode?.identifier)
        if identifier.contains("-") {
            append(identifier.split(separator: "-")[0].description)
        }
        append("Base")
        append("en")

        return unique
    }

    private static func loadIDs(forKey key: String, defaults: UserDefaults) -> Set<Int> {
        let values = defaults.array(forKey: key) as? [Int] ?? []
        return Set(values)
    }

    private func persist(_ ids: Set<Int>, key: String) {
        defaults.set(Array(ids).sorted(), forKey: key)
    }

    private func loadEnglishReferenceIfNeeded() {
        guard englishReferenceByID.isEmpty else { return }

        let decoder = JSONDecoder()
        let preferredLocalizations = ["en", "Base"]

        for localization in preferredLocalizations {
            guard let url = Bundle.main.url(
                forResource: "eb5_terms",
                withExtension: "json",
                subdirectory: nil,
                localization: localization
            ) else { continue }

            do {
                let data = try Data(contentsOf: url)
                let articles = try decoder.decode([EB5Article].self, from: data)
                englishReferenceByID = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
                subcategoryOrderByCategory = articles.reduce(into: [:]) { result, article in
                    var list = result[article.category] ?? []
                    if !list.contains(article.subcategory) {
                        list.append(article.subcategory)
                    }
                    result[article.category] = list
                }
                return
            } catch {
                continue
            }
        }
    }
}
