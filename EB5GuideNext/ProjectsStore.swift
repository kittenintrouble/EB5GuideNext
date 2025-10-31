import Foundation
import Combine

@MainActor
final class ProjectsStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var isLoadingList = false
    @Published private(set) var listErrorMessage: String?
    @Published private(set) var favorites: Set<String>
    @Published private(set) var dataVersion: String?
    @Published private(set) var totalAvailable: Int = 0

    private var detailCache: [String: Project] = [:]
    private var detailLanguageCache: [String: String] = [:]
    private var currentListLanguage: String?

    private let service: ProjectService
    private let defaults: UserDefaults

    private static let favoritesKey = "projects.favorite.ids"

    init(service: ProjectService? = nil, defaults: UserDefaults = .standard) {
        self.service = service ?? ProjectService.shared
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: ProjectsStore.favoritesKey) ?? []
        self.favorites = Set(stored)
    }

    func loadProjects(language rawCode: String, force: Bool = false) async {
        let normalized = LanguageManager.normalizedCode(for: rawCode)
        guard !isLoadingList else { return }
        let languageChanged = currentListLanguage != normalized
        if languageChanged {
            clearCachedDetails()
        }
        if !force, !languageChanged, !projects.isEmpty {
            return
        }

        isLoadingList = true
        listErrorMessage = nil

        do {
            let apiCode = LanguageManager.apiCode(for: normalized)
            let response = try await service.fetchProjects(lang: apiCode)
            projects = response.items
            dataVersion = response.dataVersion
            totalAvailable = response.total
            currentListLanguage = normalized
            print("📦 Loaded projects:", projects.count, "lang:", normalized)
            if let first = projects.first {
                print("   • First project title:", first.title)
            }
        } catch {
            listErrorMessage = error.localizedDescription
            currentListLanguage = normalized
            print("⚠️ Failed to load projects:", error.localizedDescription)
        }

        isLoadingList = false
    }

    func project(withID id: String) -> Project? {
        if let cached = detailCache[id] {
            return cached
        }
        return projects.first { $0.id == id }
    }

    func fetchProjectDetail(id: String, language rawCode: String, force: Bool = false) async throws -> Project {
        let normalized = LanguageManager.normalizedCode(for: rawCode)
        if !force,
           let cached = detailCache[id],
           detailLanguageCache[id] == normalized {
            return cached
        }

        let apiCode = LanguageManager.apiCode(for: normalized)
        let detail = try await service.fetchProject(id: id, lang: apiCode)
        detailCache[id] = detail
        detailLanguageCache[id] = normalized

        if let index = projects.firstIndex(where: { $0.id == id }) {
            projects[index] = detail
        } else {
            projects.append(detail)
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

    func submitInquiry(_ inquiry: ProjectInquiry) async throws -> InquiryResponse {
        try await service.submitInquiry(form: inquiry)
    }

    func clearCachedDetails() {
        detailCache.removeAll()
        detailLanguageCache.removeAll()
    }

    private func persistFavorites() {
        defaults.set(Array(favorites).sorted(), forKey: ProjectsStore.favoritesKey)
    }
}
