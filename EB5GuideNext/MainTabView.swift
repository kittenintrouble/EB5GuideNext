import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var baseStore: BaseContentStore
    @StateObject private var quizStore: QuizContentStore
    @State private var selectedTab: Tab = .home
    @State private var baseNavigationPath: [BaseRoute] = []
    @State private var homeNavigationPath = NavigationPath()
    @State private var pendingBaseNavigationRequest: BaseNavigationRequest?

    enum Tab: Hashable {
        case home
        case base
        case quizzes
        case news
        case projects
    }

    init() {
        let baseStore = BaseContentStore()
        _baseStore = StateObject(wrappedValue: baseStore)
        _quizStore = StateObject(wrappedValue: QuizContentStore(baseStore: baseStore))
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
        .onAppear {
            baseStore.loadArticles(for: languageManager.currentLocale.identifier)
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
            }
        }
        .onChange(of: languageManager.currentLocale.identifier) { newValue in
            baseStore.loadArticles(for: newValue)
            baseNavigationPath = []
            homeNavigationPath = NavigationPath()
            pendingBaseNavigationRequest = nil
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
}

struct NewsView: View {
    var body: some View {
        NavigationStack {
            Text("news.placeholder")
                .navigationTitle("tab.news")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProjectsView: View {
    var body: some View {
        NavigationStack {
            Text("projects.placeholder")
                .navigationTitle("tab.projects")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(LanguageManager())
}
