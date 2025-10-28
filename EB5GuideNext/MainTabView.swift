import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var baseStore: BaseContentStore
    @StateObject private var quizStore: QuizContentStore

    init() {
        let baseStore = BaseContentStore()
        _baseStore = StateObject(wrappedValue: baseStore)
        _quizStore = StateObject(wrappedValue: QuizContentStore(baseStore: baseStore))
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("tab.home", systemImage: "house.fill") }

            BaseView()
                .tabItem { Label("tab.base", systemImage: "square.grid.2x2.fill") }

            QuizzesView()
                .tabItem { Label("tab.quizzes", systemImage: "checkmark.circle.fill") }

            NewsView()
                .tabItem { Label("tab.news", systemImage: "newspaper.fill") }

            ProjectsView()
                .tabItem { Label("tab.projects", systemImage: "folder.fill") }
        }
        .environmentObject(baseStore)
        .environmentObject(quizStore)
        .onAppear {
            baseStore.loadArticles(for: languageManager.currentLocale.identifier)
        }
        .onChange(of: languageManager.currentLocale.identifier) { newValue in
            baseStore.loadArticles(for: newValue)
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            Text("home.placeholder")
                .navigationTitle("tab.home")
                .navigationBarTitleDisplayMode(.large)
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
