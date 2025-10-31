import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var baseStore: BaseContentStore
    @StateObject private var quizStore: QuizContentStore
    @StateObject private var newsStore: NewsStore
    @StateObject private var projectsStore = ProjectsStore()
    @State private var selectedTab: Tab = .home
    @State private var baseNavigationPath: [BaseRoute] = []
    @State private var homeNavigationPath = NavigationPath()
    @State private var pendingBaseNavigationRequest: BaseNavigationRequest?
    @State private var pendingNewsArticleID: String?
    private let pendingNewsDefaultsKey = "PendingNewsArticleID"

    enum Tab: Hashable {
        case home
        case base
        case quizzes
        case news
        case projects
    }

    init() {
        let baseStore = BaseContentStore()
        let newsStore = NewsStore()
        _baseStore = StateObject(wrappedValue: baseStore)
        _quizStore = StateObject(wrappedValue: QuizContentStore(baseStore: baseStore))
        _newsStore = StateObject(wrappedValue: newsStore)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                homeNavigationPath: $homeNavigationPath,
                onRequestBaseNavigation: handleBaseNavigationRequest
            )
                .tabItem { Label("tab.home", systemImage: "house.fill") }
                .tag(Tab.home)

            BaseView(
                navigationPath: $baseNavigationPath,
                onRequestNavigation: handleBaseNavigationRequest
            )
                .tabItem { Label("tab.base", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.base)

            QuizzesView()
                .tabItem { Label("tab.quizzes", systemImage: "questionmark.circle.fill") }
                .tag(Tab.quizzes)

            NewsView()
                .tabItem { Label("tab.news", systemImage: "newspaper.fill") }
                .tag(Tab.news)

            ProjectsView()
                .tabItem { Label("tab.projects", systemImage: "folder.fill") }
                .tag(Tab.projects)
        }
        .environmentObject(baseStore)
        .environmentObject(quizStore)
        .environmentObject(newsStore)
        .environmentObject(projectsStore)
        .onAppear {
            baseStore.loadArticles(for: languageManager.currentLocale.identifier)
            Task {
                await newsStore.refresh(language: languageManager.currentLocale.identifier, force: false)
            }
            if pendingNewsArticleID == nil,
               let stored = UserDefaults.standard.string(forKey: pendingNewsDefaultsKey) {
                pendingNewsArticleID = stored
                selectedTab = .news
                triggerNewsDeepLinkIfNeeded(stored)
            }
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == .home {
                homeNavigationPath = NavigationPath()
            } else if newValue == .base {
                if pendingBaseNavigationRequest != nil {
                    applyPendingBaseNavigationRequest()
                } else {
                    resetBaseNavigationPath()
                }
            } else if newValue == .news, let articleID = pendingNewsArticleID {
                triggerNewsDeepLinkIfNeeded(articleID)
            }
        }
        .onChange(of: languageManager.currentLocale.identifier) { newValue in
            baseStore.loadArticles(for: newValue)
            baseNavigationPath = []
            homeNavigationPath = NavigationPath()
            pendingBaseNavigationRequest = nil
            Task {
                await newsStore.refresh(language: newValue, force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newsNotificationReceived)) { notification in
            guard let articleID = notification.userInfo?["article_id"] as? String else { return }
            pendingNewsArticleID = articleID
            selectedTab = .news
            triggerNewsDeepLinkIfNeeded(articleID)
        }
    }

    private func handleBaseNavigationRequest(_ request: BaseNavigationRequest) {
        if request.activateTab {
            pendingBaseNavigationRequest = request
            if selectedTab == .base {
                applyPendingBaseNavigationRequest()
            } else {
                selectedTab = .base
            }
        } else {
            applyBaseNavigationRequest(request)
        }
    }

    private func applyPendingBaseNavigationRequest() {
        guard let request = pendingBaseNavigationRequest else { return }
        pendingBaseNavigationRequest = nil
        applyBaseNavigationRequest(request)
    }

    private func applyBaseNavigationRequest(_ request: BaseNavigationRequest) {
        let applyPath = {
            var transaction = Transaction()
            if request.animate {
                transaction.animation = .easeInOut(duration: 0.24)
                transaction.disablesAnimations = false
            } else {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }

            withTransaction(transaction) {
                self.baseNavigationPath = request.path
            }
        }

        let delay: DispatchTimeInterval = request.animate ? .milliseconds(30) : .milliseconds(1)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            applyPath()
        }
    }

    private func resetBaseNavigationPath() {
        var transaction = Transaction()
        transaction.animation = nil
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            baseNavigationPath = []
        }
    }

    private func triggerNewsDeepLinkIfNeeded(_ articleID: String) {
        guard selectedTab == .news else { return }
        DispatchQueue.main.async {
            newsStore.requestOpenArticle(id: articleID)
            pendingNewsArticleID = nil
            UserDefaults.standard.removeObject(forKey: pendingNewsDefaultsKey)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(LanguageManager())
}
