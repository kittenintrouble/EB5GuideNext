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
    @Published private(set) var pendingProjectID: String?

    private var detailCache: [String: Project] = [:]
    private var detailLanguageCache: [String: String] = [:]
    private var currentListLanguage: String?
    private var pendingListRequest: (language: String, force: Bool, languageChanged: Bool)?

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
        let languageChanged = currentListLanguage != normalized

        if !force, !languageChanged, !projects.isEmpty {
            return
        }

        pendingListRequest = (
            language: normalized,
            force: force || languageChanged || projects.isEmpty,
            languageChanged: languageChanged
        )

        await processPendingListRequest()
    }

    private func processPendingListRequest() async {
        guard !isLoadingList else { return }
        guard let request = pendingListRequest else { return }
        pendingListRequest = nil
        await performListLoad(
            language: request.language,
            force: request.force,
            languageChanged: request.languageChanged
        )
        if pendingListRequest != nil {
            await processPendingListRequest()
        }
    }

    private func performListLoad(language: String, force _: Bool, languageChanged: Bool) async {
        if languageChanged {
            clearCachedDetails()
        }

        isLoadingList = true
        listErrorMessage = nil
        let previousProjectsByID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

        do {
            let apiCode = LanguageManager.apiCode(for: language)
            let response = try await service.fetchProjects(lang: apiCode)
            let mergedItems = mergeProjectList(response.items, fallback: previousProjectsByID)
            projects = mergedItems
            dataVersion = response.dataVersion
            totalAvailable = response.total
            currentListLanguage = language
            print("📦 Loaded projects:", projects.count, "lang:", language)
            if let first = projects.first {
                print("   • First project title:", first.title)
            }
        } catch {
            listErrorMessage = error.localizedDescription
            currentListLanguage = language
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
        let fetchedDetail = try await service.fetchProject(id: id, lang: apiCode)
        let fallbackProject = projects.first { $0.id == id }
        let detail = fallbackProject.map { fetchedDetail.fillingBlanks(using: $0) } ?? fetchedDetail
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

    func requestOpenProject(id: String) {
        pendingProjectID = id
    }

    func clearPendingProject(id: String) {
        if pendingProjectID == id {
            pendingProjectID = nil
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favorites).sorted(), forKey: ProjectsStore.favoritesKey)
    }

    private func mergeProjectList(_ newItems: [Project], fallback: [String: Project]) -> [Project] {
        newItems.map { project in
            guard let fallbackProject = fallback[project.id] else { return project }
            return project.fillingBlanks(using: fallbackProject)
        }
    }
}

fileprivate func prefer(_ primary: String, fallback: String) -> String {
    let trimmed = primary.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallbackTrimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return fallbackTrimmed
    }
    return primary
}

fileprivate func preferOptional(_ primary: String?, fallback: String?) -> String? {
    if let primary = primary?.trimmingCharacters(in: .whitespacesAndNewlines), !primary.isEmpty {
        return primary
    }
    if let fallback = fallback?.trimmingCharacters(in: .whitespacesAndNewlines), !fallback.isEmpty {
        return fallback
    }
    return nil
}

private extension Project {
    func fillingBlanks(using fallback: Project) -> Project {
        Project(
            id: id,
            title: prefer(title, fallback: fallback.title),
            name: preferOptional(name, fallback: fallback.name),
            slug: preferOptional(slug, fallback: fallback.slug),
            shortDescription: prefer(shortDescription, fallback: fallback.shortDescription),
            fullDescription: prefer(fullDescription, fallback: fallback.fullDescription),
            location: prefer(location, fallback: fallback.location),
            type: prefer(type, fallback: fallback.type),
            status: prefer(status, fallback: fallback.status),
            developer: prefer(developer, fallback: fallback.developer),
            expectedOpening: prefer(expectedOpening, fallback: fallback.expectedOpening),
            images: images.isEmpty ? fallback.images : images,
            financials: financials.merging(with: fallback.financials),
            uscis: uscis.merging(with: fallback.uscis),
            tea: tea.merging(with: fallback.tea),
            jobs: jobs.preferringData(from: fallback.jobs),
            loanStructure: loanStructure.merging(with: fallback.loanStructure),
            published: published,
            publishedAt: publishedAt ?? fallback.publishedAt
        )
    }
}

private extension Financials {
    func merging(with fallback: Financials) -> Financials {
        Financials(
            totalProject: prefer(totalProject, fallback: fallback.totalProject),
            eb5Offering: prefer(eb5Offering, fallback: fallback.eb5Offering),
            minInvestment: prefer(minInvestment, fallback: fallback.minInvestment),
            eb5Investors: prefer(eb5Investors, fallback: fallback.eb5Investors)
        )
    }
}

private extension USCIS {
    func merging(with fallback: USCIS) -> USCIS {
        USCIS(
            i956fStatus: preferOptional(i956fStatus, fallback: fallback.i956fStatus),
            i956fFilingDate: preferOptional(i956fFilingDate, fallback: fallback.i956fFilingDate),
            i956fApprovalDate: preferOptional(i956fApprovalDate, fallback: fallback.i956fApprovalDate),
            i526eStatus: preferOptional(i526eStatus, fallback: fallback.i526eStatus)
        )
    }
}

private extension TEA {
    func merging(with fallback: TEA) -> TEA {
        TEA(
            type: prefer(type, fallback: fallback.type),
            designation: preferOptional(designation, fallback: fallback.designation)
        )
    }
}

private extension Jobs {
    func preferringData(from fallback: Jobs) -> Jobs {
        if total == 0 && perInvestor == 0 {
            return fallback
        }
        return self
    }
}

private extension LoanStructure {
    func merging(with fallback: LoanStructure) -> LoanStructure {
        LoanStructure(
            type: prefer(type, fallback: fallback.type),
            annualReturn: prefer(annualReturn, fallback: fallback.annualReturn),
            termYears: termYears ?? fallback.termYears,
            escrow: escrow || fallback.escrow
        )
    }
}
