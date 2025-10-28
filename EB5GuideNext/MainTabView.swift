import SwiftUI

struct MainTabView: View {
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
    }
}

struct HomeView: View { var body: some View { NavigationStack { Text("home.placeholder").navigationTitle("tab.home") } } }
struct BaseView: View { var body: some View { NavigationStack { Text("base.placeholder").navigationTitle("tab.base") } } }
struct QuizzesView: View { var body: some View { NavigationStack { Text("quizzes.placeholder").navigationTitle("tab.quizzes") } } }
struct NewsView: View { var body: some View { NavigationStack { Text("news.placeholder").navigationTitle("tab.news") } } }
struct ProjectsView: View { var body: some View { NavigationStack { Text("projects.placeholder").navigationTitle("tab.projects") } } }

#Preview { MainTabView() }
