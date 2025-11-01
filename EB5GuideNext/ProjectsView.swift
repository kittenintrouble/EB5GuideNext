import SwiftUI
import Combine

@available(iOS 16.0, *)
struct ProjectsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var projectsStore: ProjectsStore
    @StateObject private var imageLoader = ProjectImageLoadingCoordinator()
    @State private var isActive = false
    @State private var navigationPath: [String] = []
    @State private var lastHandledPendingNavigationToken: UUID?

    private var languageIdentifier: String {
        languageManager.currentLocale.identifier
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            navigationDecoratedContent
                .navigationDestination(for: String.self) { projectID in
                    ProjectDetailView(projectID: projectID)
                }
        }
        .environmentObject(imageLoader)
        .onChange(of: navigationPath.isEmpty) { isEmpty in
            if isEmpty {
                lastHandledPendingNavigationToken = nil
            }
        }
        .onReceive(projectsStore.$pendingNavigation.compactMap { $0 }) { navigation in
            handlePendingNavigation(navigation)
        }
    }

    private var previewImageURLs: [String] {
        projectsStore.projects.compactMap { $0.images.first?.url }
    }

    private var navigationDecoratedContent: some View {
        mainContent
            .navigationTitle(languageManager.localizedString(for: "nav.title.projects"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSwitchMenu(
                        languageManager: languageManager,
                        beforeChange: {
                            resetNavigationSelection()
                        }
                    )
                }
            }
            .onAppear {
                isActive = true
                resetNavigationSelection()
                if !projectsStore.isLoadingList {
                    imageLoader.activateList(with: previewImageURLs)
                }
                Task {
                    await projectsStore.loadProjects(
                        language: languageIdentifier,
                        force: projectsStore.projects.isEmpty
                    )
                }
                if let pending = projectsStore.pendingNavigation {
                    handlePendingNavigation(pending)
                }
            }
            .onDisappear {
                isActive = false
                imageLoader.pauseList()
            }
            .onChange(of: projectsStore.isLoadingList) { newValue in
                if newValue {
                    imageLoader.pauseList()
                } else if isActive {
                    imageLoader.activateList(with: previewImageURLs)
                }
            }
            .onChange(of: languageManager.currentLocale.identifier) { newValue in
                resetNavigationSelection()
                Task {
                    await projectsStore.loadProjects(language: newValue, force: true)
                }
            }
            .onChange(of: projectsStore.projects) { _ in
                guard isActive, !projectsStore.isLoadingList else { return }
                imageLoader.activateList(with: previewImageURLs)
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        if projectsStore.isLoadingList && projectsStore.projects.isEmpty {
            loadingView
        } else if let error = projectsStore.listErrorMessage, projectsStore.projects.isEmpty {
            errorView(message: error)
        } else if projectsStore.projects.isEmpty {
            emptyView
        } else {
            projectsList
        }
    }

    private var loadingView: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ErrorStateView(message: message) {
            Task {
                await projectsStore.loadProjects(language: languageIdentifier, force: true)
            }
        }
    }

    private var emptyView: some View {
        EmptyStateView(
            title: languageManager.localizedString(for: "projects.empty.title"),
            message: languageManager.localizedString(for: "projects.empty.subtitle")
        ) {
            Task {
                await projectsStore.loadProjects(language: languageIdentifier, force: true)
            }
        }
    }

    private var projectsList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(projectsStore.projects) { project in
                    navigationLink(for: project)
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottom) {
            if projectsStore.isLoadingList {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding()
            }
        }
    }

    private func navigationLink(for project: Project) -> some View {
        NavigationLink(value: project.id) {
            ProjectCardView(
                project: project,
                isFavorite: projectsStore.isFavorite(id: project.id),
                onToggleFavorite: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        projectsStore.toggleFavorite(id: project.id)
                    }
                },
                languageManager: languageManager,
                variant: .standard
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                clearPendingNavigationIfNeeded()
            }
        )
    }
}

private extension ProjectsView {
    func handlePendingNavigation(_ pending: ProjectsStore.PendingProjectNavigation) {
        guard pending.token != lastHandledPendingNavigationToken else { return }
        lastHandledPendingNavigationToken = pending.token
        navigateToProject(with: pending.projectID)
        projectsStore.consumePendingProject(token: pending.token)
    }

    func navigateToProject(with projectID: String) {
        navigationPath = [projectID]
    }

    func resetNavigationSelection() {
        lastHandledPendingNavigationToken = nil
        navigationPath.removeAll()
    }

    func clearPendingNavigationIfNeeded() {
        if let pending = projectsStore.pendingNavigation {
            projectsStore.consumePendingProject(token: pending.token)
        }
        lastHandledPendingNavigationToken = nil
        if !navigationPath.isEmpty {
            navigationPath.removeAll()
        }
    }
}


struct ProjectCardView: View {
    enum Variant {
        case standard
        case compact
    }

    let project: Project
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let languageManager: LanguageManager
    let variant: Variant
    @EnvironmentObject private var projectsStore: ProjectsStore

    init(
        project: Project,
        isFavorite: Bool,
        onToggleFavorite: @escaping () -> Void,
        languageManager: LanguageManager,
        variant: Variant = .standard
    ) {
        self.project = project
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
        self.languageManager = languageManager
        self.variant = variant
    }

    private var imageHeight: CGFloat {
        switch variant {
        case .standard:
            return 200
        case .compact:
            return 140
        }
    }

    private var showsDescription: Bool { variant == .standard }
    private var showsFlexibleInfo: Bool { variant == .standard }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            imageSection

            VStack(alignment: .leading, spacing: 12) {
                titleRow

                Label(project.location, systemImage: "mappin.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.blue)
                    .lineLimit(1)

                if let minInvestment = project.financials.minInvestmentDisplay.nonEmpty {
                    let label = languageManager.localizedString(for: "projects.card.min_investment")
                    HighlightBadge(
                        label: label,
                        value: minInvestment,
                        background: Color.orange.opacity(0.18),
                        foreground: Color.orange
                    )
                }

                if showsDescription {
                    Text(project.shortDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                if showsFlexibleInfo {
                    FlexibleInfoRow(
                        project: project,
                        languageManager: languageManager,
                        statusOverride: projectsStore.cachedStatus(for: project)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }

    private var imageSection: some View {
        Group {
            switch variant {
            case .standard:
                ZStack(alignment: .topTrailing) {
                    ProjectImageView(url: project.images.first?.url, height: imageHeight)

                    ProjectsFavoriteButton(
                        isFavorite: isFavorite,
                        languageManager: languageManager,
                        action: onToggleFavorite,
                        variant: .overlay
                    )
                    .padding(12)
                }
            case .compact:
                ProjectImageView(url: project.images.first?.url, height: imageHeight)
            }
        }
    }

    private var titleRow: some View {
            HStack(alignment: .center, spacing: 12) {
            Text(project.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer()

            if variant == .compact {
                ProjectsFavoriteButton(
                    isFavorite: isFavorite,
                    languageManager: languageManager,
                    action: onToggleFavorite,
                    variant: .inline
                )
                .fixedSize()
            }
        }
    }
}

struct ProjectImageView: View {
    let url: String?
    let height: CGFloat
    @EnvironmentObject private var imageLoader: ProjectImageLoadingCoordinator

    var body: some View {
        Group {
            if let url,
               let image = imageLoader.image(for: url),
               image.isRenderable {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.secondarySystemBackground)
                    .overlay {
                        ProgressView().progressViewStyle(.circular)
                    }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct ProjectsFavoriteButton: View {
    enum Variant {
        case overlay
        case inline
    }

    let isFavorite: Bool
    let languageManager: LanguageManager
    let action: () -> Void
    let variant: Variant

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                Text(languageManager.localizedString(for: isFavorite ? "projects.favorite.remove" : "projects.favorite.add"))
            )
    }

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .overlay:
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.red : Color.white)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        case .inline:
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.red : Color(.tertiaryLabel))
                .padding(6)
        }
    }
}

struct FlexibleInfoRow: View {
    let project: Project
    let languageManager: LanguageManager
    let statusOverride: ProjectStatus?

    var body: some View {
        let badges = badgeItems

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(badges) { badgeView($0) }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(badges) { badgeView($0) }
            }
        }
    }

    private var badgeItems: [BadgeItem] {
        var items: [BadgeItem] = []
        if let type = localizedProjectType() {
            items.append(
                BadgeItem(
                    label: languageManager.localizedString(for: "projects.type_label"),
                    value: type,
                    tint: Color.blue.opacity(0.12),
                    foreground: Color.blue
                )
            )
        }
        if let status = statusOverride ?? project.statusEnum ?? ProjectStatus(apiValue: project.status) {
            let palette = statusPalette(for: status)
            let localizedStatus = languageManager.localizedString(for: status.localizationKey)
            items.append(
                BadgeItem(
                    label: languageManager.localizedString(for: "projects.status_label"),
                    value: localizedStatus,
                    tint: palette.tint,
                    foreground: palette.foreground
                )
            )
        } else if let statusRaw = project.status.nonEmpty {
            items.append(
                BadgeItem(
                    label: languageManager.localizedString(for: "projects.status_label"),
                    value: statusRaw,
                    tint: Color(.secondarySystemBackground).opacity(0.12),
                    foreground: Color.primary
                )
            )
        }
        return items
    }

    @ViewBuilder
    private func badgeView(_ badge: BadgeItem) -> some View {
        let parts = Text("\(badge.label): ")
            .font(.caption)
            + Text(badge.value)
            .font(.caption)
            .fontWeight(.bold)
        parts
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(badge.tint ?? Color(.secondarySystemBackground).opacity(0.12))
            .foregroundStyle(badge.foreground ?? Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private struct BadgeItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let tint: Color?
        let foreground: Color?
    }

    private func statusPalette(for status: ProjectStatus) -> (tint: Color, foreground: Color) {
        let baseColor = status.color
        if status == .completed {
            return (baseColor.opacity(0.12), Color(red: 0.6, green: 0.19, blue: 0.25))
        }
        return (baseColor.opacity(0.15), baseColor)
    }

    private func localizedProjectType() -> String? {
        if let typeEnum = project.typeEnum {
            return languageManager.localizedString(for: typeEnum.localizationKey)
        }
        return project.type.nonEmpty
    }
}

struct HighlightBadge: View {
    let label: String
    let value: String
    let background: Color
    let foreground: Color

    var body: some View {
        (Text("\(label): ")
            .font(.caption2)
         + Text(value)
            .font(.caption)
            .fontWeight(.bold)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(Capsule())
    }
}


private struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .font(.body)

            Button(action: retryAction) {
                Label {
                    Text(LocalizedStringKey("common.retry"))
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(Color(.tertiaryLabel))

            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                Label {
                    Text(LocalizedStringKey("common.retry"))
                } icon: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
