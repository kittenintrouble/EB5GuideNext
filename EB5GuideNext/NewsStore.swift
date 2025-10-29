import Foundation
import Combine

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var articles: [NewsArticleSummary] = []
    @Published private(set) var isLoadingList: Bool = false
    @Published private(set) var listErrorMessage: String?
    @Published private(set) var favorites: Set<String>
    @Published private(set) var dataVersion: String?
    @Published private(set) var pendingArticleID: String?

    private let service: NewsAPIService
    private let defaults: UserDefaults
    private var detailCache: [String: NewsArticleDetail] = [:]
    private var currentLanguageCode: String?

    private static let favoritesKey = "news.favorite.ids"

    init(service: NewsAPIService? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? NewsAPIService()
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: NewsStore.favoritesKey) ?? []
        self.favorites = Set(stored)
    }

    func refresh(language rawCode: String, force: Bool = false) async {
        guard !isLoadingList || force else { return }

        isLoadingList = true
        listErrorMessage = nil
        let languageChanged = currentLanguageCode != rawCode

        do {
            let response = try await service.fetchNews(language: rawCode)
            articles = response.items
            dataVersion = response.dataVersion
            currentLanguageCode = rawCode
            if force || languageChanged {
                detailCache.removeAll()
            }
            if languageChanged {
                pendingArticleID = nil
            }
        } catch {
            listErrorMessage = error.localizedDescription
        }

        isLoadingList = false
    }

    func summary(withID id: String) -> NewsArticleSummary? {
        articles.first { $0.id == id }
    }

    func fetchDetail(for id: String, language rawCode: String) async throws -> NewsArticleDetail {
        if let cached = detailCache[id] {
            return cached
        }

        let detail = try await service.fetchNewsDetail(id: id, language: rawCode)
        detailCache[id] = detail

        let summary = detail.asSummary
        if let index = articles.firstIndex(where: { $0.id == id }) {
            articles[index] = summary
        } else {
            articles.append(summary)
        }

        return detail
    }

    func toggleFavorite(id: String) {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
        persistFavorites()
    }

    func isFavorite(id: String) -> Bool {
        favorites.contains(id)
    }

    func requestOpenArticle(id: String) {
        pendingArticleID = id
    }

    func clearPendingArticle(id: String) {
        if pendingArticleID == id {
            pendingArticleID = nil
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favorites).sorted(), forKey: NewsStore.favoritesKey)
    }
}
