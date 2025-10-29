import SwiftUI

struct BaseNavigationRequest {
    let path: [BaseRoute]
    let animate: Bool
    let activateTab: Bool

    init(path: [BaseRoute], animate: Bool = true, activateTab: Bool = true) {
        self.path = path
        self.animate = animate
        self.activateTab = activateTab
    }
}

struct HomeView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var baseStore: BaseContentStore
    @Binding var homeNavigationPath: NavigationPath
    let onRequestBaseNavigation: (BaseNavigationRequest) -> Void

    private var languageOptions: [LanguageOption] { LanguageOption.supported }

    private var currentLanguageOption: LanguageOption {
        let identifier = languageManager.currentLocale.identifier
        if let exactMatch = languageOptions.first(where: { $0.matches(localeIdentifier: identifier) }) {
            return exactMatch
        }

        if let languageCode = languageManager.currentLocale.language.languageCode?.identifier,
           let languageMatch = languageOptions.first(where: { $0.matches(localeIdentifier: languageCode) }) {
            return languageMatch
        }

        return languageOptions.first(where: { $0.code == "en" })!
    }

    private var completedArticlesCount: Int {
        baseStore.completedIDs.count
    }

    private var totalArticlesCount: Int {
        baseStore.articles.count
    }

    private var favoriteArticles: [EB5Article] {
        baseStore.favoriteIDs
            .compactMap { baseStore.article(withID: $0) }
            .sorted { lhs, rhs in
                (lhs.dayNumber ?? Int.max, lhs.title) < (rhs.dayNumber ?? Int.max, rhs.title)
            }
    }


    private var favoriteArticleItems: [FavoriteCardContent] {
        favoriteArticles.map { article in
            FavoriteCardContent(
                id: article.id,
                title: article.title,
                subtitle: nil,
                destination: .article(id: article.id, disableBaseAnimation: true),
                isFavorite: true,
                isCompleted: baseStore.isCompleted(article.id)
            )
        }
    }

    private var favoriteNewsItems: [FavoriteCardContent] {
        []
    }

    private var favoriteProjectItems: [FavoriteCardContent] {
        []
    }

    var body: some View {
        NavigationStack(path: $homeNavigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ArticlesProgressCard(
                        completed: completedArticlesCount,
                        total: totalArticlesCount,
                        favorites: favoriteArticleItems,
                        onToggleFavorite: { content in
                            baseStore.toggleFavorite(for: content.id)
                        },
                        actionLabel: languageManager.localizedString(for: "home.section.articles.button"),
                        onExplore: { resetBaseAndSelect() }
                    )

                    FavoritesSimpleSection(
                        title: languageManager.localizedString(for: "home.favorites.news"),
                        emptyMessage: languageManager.localizedString(for: "home.favorites.empty"),
                        items: favoriteNewsItems,
                        iconSystemName: "newspaper"
                    )

                    FavoritesSimpleSection(
                        title: languageManager.localizedString(for: "home.favorites.projects"),
                        emptyMessage: languageManager.localizedString(for: "home.favorites.empty"),
                        items: favoriteProjectItems,
                        iconSystemName: "folder"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("home.title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSelector(
                        options: languageOptions,
                        current: currentLanguageOption
                    )
                }
            }
            .navigationDestination(for: FavoriteNavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
    }
}

private extension HomeView {
    func resetBaseAndSelect() {
        routeToBase(path: [])
    }

    func routeToBase(path: [BaseRoute]) {
        DispatchQueue.main.async {
            onRequestBaseNavigation(BaseNavigationRequest(path: path))
        }
    }

    func articleDetailView(articleID: Int, disableBaseNavigationAnimation: Bool = false) -> HomeArticleDetailView {
        HomeArticleDetailView(
            articleID: articleID,
            onRequestBaseNavigation: onRequestBaseNavigation,
            disableBaseNavigationAnimation: disableBaseNavigationAnimation
        )
    }

    @ViewBuilder
    func destinationView(for destination: FavoriteNavigationDestination) -> some View {
        switch destination {
        case .article(let id, let disableBaseAnimation):
            articleDetailView(articleID: id, disableBaseNavigationAnimation: disableBaseAnimation)
        }
    }
}

private struct ArticlesProgressCard: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let completed: Int
    let total: Int
    let favorites: [FavoriteCardContent]
    let onToggleFavorite: (FavoriteCardContent) -> Void
    let actionLabel: String
    let onExplore: () -> Void

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(languageManager.localizedString(for: "home.section.articles.title"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(languageManager.completionText(completed: completed, total: total))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)

            Button(action: onExplore) {
                Text(actionLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(Color.white)
                    .cornerRadius(16)
            }

            if !favorites.isEmpty {
                Text(languageManager.localizedString(for: "home.favorites.title"))
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                    .foregroundStyle(.primary)

                ArticleFavoritesList(
                    favorites: favorites,
                    onToggleFavorite: onToggleFavorite
                )
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
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

private struct ArticleFavoriteRow: View {
    let item: FavoriteCardContent
    let onToggleFavorite: (FavoriteCardContent) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(item.title)
                    .font(item.isCompleted ? .footnote.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if item.isCompleted {
                    HomeCompletedBadge()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    onToggleFavorite(item)
                }
            } label: {
                Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(item.isFavorite ? Color.red : Color(.tertiaryLabel))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }
}

private struct ArticleFavoritesList: View {
    let favorites: [FavoriteCardContent]
    let onToggleFavorite: (FavoriteCardContent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(favorites.enumerated()), id: \.offset) { index, item in
                Group {
                    if let destination = item.destination {
                        NavigationLink(value: destination) {
                            ArticleFavoriteRow(
                                item: item,
                                onToggleFavorite: onToggleFavorite
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ArticleFavoriteRow(
                            item: item,
                            onToggleFavorite: onToggleFavorite
                        )
                    }
                }

                if index < favorites.count - 1 {
                    Divider()
                        .padding(.leading, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct HomeCompletedBadge: View {
    var body: some View {
        Text(LocalizedStringKey("base.article.completed_badge"))
            .font(.caption2.weight(.semibold))
            .foregroundColor(Color.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.12))
            )
    }
}

private struct FavoritesSimpleSection: View {
    let title: String
    let emptyMessage: String
    let items: [FavoriteCardContent]
    let iconSystemName: String?

    init(title: String, emptyMessage: String, items: [FavoriteCardContent], iconSystemName: String? = nil) {
        self.title = title
        self.emptyMessage = emptyMessage
        self.items = items
        self.iconSystemName = iconSystemName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let iconSystemName {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: iconSystemName)
                }
                .font(.headline)
                .foregroundStyle(.primary)
            } else {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        Group {
                            if let destination = item.destination {
                                NavigationLink(value: destination) {
                                    simpleRow(for: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                simpleRow(for: item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func simpleRow(for item: FavoriteCardContent) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

            }

            Spacer()

            if item.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.red)
            } else if item.destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
    }
}

private struct FavoriteCardContent: Identifiable {
    let id: Int
    let title: String
    let subtitle: String?
    let destination: FavoriteNavigationDestination?
    let isFavorite: Bool
    let isCompleted: Bool

    init(id: Int, title: String, subtitle: String?, destination: FavoriteNavigationDestination?, isFavorite: Bool = false, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
        self.isFavorite = isFavorite
        self.isCompleted = isCompleted
    }
}

private enum FavoriteNavigationDestination: Hashable {
    case article(id: Int, disableBaseAnimation: Bool = false)
}

extension HomeView {
    fileprivate struct LanguageOption: Identifiable {
        let code: String
        let flag: String
        let nameKey: String

        var id: String { code }

        var displayName: String {
            nameKey
        }

        static let supported: [LanguageOption] = [
            LanguageOption(code: "en", flag: "🇺🇸", nameKey: "home.language.english"),
            LanguageOption(code: "zh-Hans", flag: "🇨🇳", nameKey: "home.language.chinese"),
            LanguageOption(code: "vi", flag: "🇻🇳", nameKey: "home.language.vietnamese"),
            LanguageOption(code: "ko", flag: "🇰🇷", nameKey: "home.language.korean")
        ]

        func matches(localeIdentifier: String) -> Bool {
            let loweredIdentifier = localeIdentifier.lowercased()
            let normalizedCode = code.lowercased()

            if loweredIdentifier == normalizedCode { return true }
            if loweredIdentifier.replacingOccurrences(of: "-", with: "_") == normalizedCode { return true }

            let identifierBase = loweredIdentifier.split(separator: "-").first?.lowercased()
            if identifierBase == normalizedCode { return true }

            if let codeBase = normalizedCode.split(separator: "-").first?.lowercased(), codeBase == loweredIdentifier {
                return true
            }

            if let codeBase = normalizedCode.split(separator: "-").first?.lowercased(), codeBase == identifierBase {
                return true
            }

            return false
        }
    }
}

private struct LanguageSelector: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let options: [HomeView.LanguageOption]
    let current: HomeView.LanguageOption

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Text(current.flag)
                Text(LocalizedStringKey(current.displayName))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .frame(minWidth: 140)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            LanguageSelectionSheet(
                options: options,
                isPresented: $isPresented
            )
            .environmentObject(languageManager)
        }
    }
}

private struct LanguageSelectionSheet: View {
    let options: [HomeView.LanguageOption]
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var isPresented: Bool

    private var currentIdentifier: String { languageManager.currentLocale.identifier }

    var body: some View {
        NavigationStack {
            List(options) { option in
                Button {
                    if !option.matches(localeIdentifier: currentIdentifier) {
                        languageManager.setLanguage(code: option.code)
                    }
                    isPresented = false
                } label: {
                    HStack(spacing: 12) {
                        Text(option.flag)
                        Text(LocalizedStringKey(option.displayName))
                            .foregroundStyle(.primary)
                        Spacer()
                        if option.matches(localeIdentifier: currentIdentifier) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(option.matches(localeIdentifier: currentIdentifier))
            }
            .listStyle(.insetGrouped)
            .listRowSeparator(.hidden)
            .navigationTitle(LocalizedStringKey("home.language.sheet.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("common.cancel")) {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct HomeArticleDetailView: View {
    @EnvironmentObject private var baseStore: BaseContentStore

    let articleID: Int
    let onRequestBaseNavigation: (BaseNavigationRequest) -> Void
    @State private var suppressAnimationsForNextNavigation: Bool

    init(
        articleID: Int,
        onRequestBaseNavigation: @escaping (BaseNavigationRequest) -> Void,
        disableBaseNavigationAnimation: Bool
    ) {
        self.articleID = articleID
        self.onRequestBaseNavigation = onRequestBaseNavigation
        self._suppressAnimationsForNextNavigation = State(initialValue: disableBaseNavigationAnimation)
    }

    private var article: EB5Article? {
        baseStore.article(withID: articleID)
    }

    var body: some View {
        if let article {
            ArticleDetailView(
                store: baseStore,
                categoryName: article.category,
                subcategoryName: article.subcategory,
                articleID: articleID,
                onRequestNavigation: { request in
                    requestBaseNavigation(
                        path: request.path,
                        activateTab: true,
                        preferAnimation: request.animate
                    )
                }
            )
            .onAppear {
                prepareBasePath(for: article)
            }
        } else {
            Text(LocalizedStringKey("home.article.unavailable"))
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareBasePath(for article: EB5Article) {
        requestBaseNavigation(
            path: [
                .category(name: article.category),
                .subcategory(category: article.category, name: article.subcategory),
                .article(category: article.category, subcategory: article.subcategory, articleID: article.id)
            ],
            activateTab: false,
            preferAnimation: false,
            consumeSuppression: false
        )
    }

    private func requestBaseNavigation(
        path: [BaseRoute],
        activateTab: Bool,
        preferAnimation: Bool = true,
        consumeSuppression: Bool = true
    ) {
        let shouldAnimate: Bool
        if suppressAnimationsForNextNavigation && consumeSuppression {
            shouldAnimate = false
        } else {
            shouldAnimate = preferAnimation
        }

        onRequestBaseNavigation(
            BaseNavigationRequest(
                path: path,
                animate: shouldAnimate,
                activateTab: activateTab
            )
        )

        if suppressAnimationsForNextNavigation && consumeSuppression {
            suppressAnimationsForNextNavigation = false
        }
    }
}
