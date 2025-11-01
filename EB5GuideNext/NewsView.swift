import SwiftUI
import Combine

struct NewsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var newsStore: NewsStore

    @State private var lastRequestedLanguageCode: String?
    @State private var navigationPath = NavigationPath()

    private var articles: [NewsArticleSummary] { newsStore.articles }
    private var listErrorMessage: String? { newsStore.listErrorMessage }
    private var isLoading: Bool { newsStore.isLoadingList }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading && articles.isEmpty {
                    loadingView
                } else if articles.isEmpty, let message = listErrorMessage {
                    errorView(message: message)
                } else if articles.isEmpty {
                    emptyView
                } else {
                    contentView
                }
            }
            .navigationTitle(languageManager.localizedString(for: "nav.title.news"))
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(for: NewsRoute.self) { route in
                NewsDetailDestination(route: route)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSwitchMenu(
                        languageManager: languageManager,
                        beforeChange: {
                            navigationPath = NavigationPath()
                        }
                    )
                }
            }
        }
        .task {
            await loadIfNeeded()
        }
        .onChange(of: languageManager.currentLocale.identifier) { newValue in
            Task { await reload(for: LanguageManager.apiCode(for: newValue), force: true) }
        }
        .onReceive(newsStore.$pendingArticleID.compactMap { $0 }) { articleID in
            openArticleDetail(articleID)
        }
        .onAppear {
            if let pending = newsStore.pendingArticleID {
                openArticleDetail(pending)
            }
        }
    }
}

private extension NewsView {
    enum NewsRoute: Hashable {
        case detail(String)
    }

    var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 18, pinnedViews: []) {
                ForEach(articles) { article in
                    NavigationLink(value: NewsRoute.detail(article.id)) {
                        NewsCardView(
                            article: article,
                            locale: languageManager.currentLocale,
                            isFavorite: newsStore.isFavorite(id: article.id),
                            onToggleFavorite: {
                                newsStore.toggleFavorite(id: article.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("news-card-\(article.id)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await reloadCurrentLanguage(force: true)
        }
    }

    var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(LocalizedStringKey("news.loading"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("news.empty.title"))
                .font(.headline)
            Text(LocalizedStringKey("news.empty.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("news.error.title"))
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await reloadCurrentLanguage(force: true) }
            } label: {
                Text(LocalizedStringKey("common.retry"))
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.white)
                    .cornerRadius(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    @MainActor
    func loadIfNeeded() async {
        await reloadCurrentLanguage(force: articles.isEmpty)
    }

    @MainActor
    func reloadCurrentLanguage(force: Bool) async {
        let languageCode = languageManager.currentAPICode
        await reload(for: languageCode, force: force)
    }

    @MainActor
    func reload(for languageCode: String, force: Bool) async {
        if lastRequestedLanguageCode != languageCode || force {
            lastRequestedLanguageCode = languageCode
            await newsStore.refresh(language: languageCode, force: force)
        }
    }

    func openArticleDetail(_ articleID: String) {
        navigationPath = NavigationPath()
        navigationPath.append(NewsRoute.detail(articleID))
        newsStore.clearPendingArticle(id: articleID)
    }

    struct NewsDetailDestination: View {
        let route: NewsRoute
        @EnvironmentObject private var newsStore: NewsStore

        var body: some View {
            switch route {
            case .detail(let articleID):
                NewsDetailView(
                    articleID: articleID,
                    initialSummary: newsStore.summary(withID: articleID)
                )
            }
        }
    }
}

private struct NewsCardView: View {
    let article: NewsArticleSummary
    let locale: Locale
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.formattedDate(locale: locale))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onToggleFavorite()
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isFavorite ? Color.red : Color(.tertiaryLabel))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(isFavorite ? "news.favorites.remove" : "news.favorites.add"))
            }

            if !article.displayShortDescription.isEmpty {
                Text(article.displayShortDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let tags = article.tags, !tags.isEmpty {
                NewsTagStrip(tags: tags)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }
}
