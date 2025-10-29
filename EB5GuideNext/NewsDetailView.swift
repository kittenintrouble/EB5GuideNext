import SwiftUI
import Combine
import UIKit

struct NewsDetailView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var newsStore: NewsStore

    let articleID: String
    let initialSummary: NewsArticleSummary?

    @State private var summary: NewsArticleSummary?
    @State private var detail: NewsArticleDetail?
    @State private var heroImageStore: UIImage?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var isLoadingImage: Bool = false
    @State private var heroImageTask: Task<Void, Never>? = nil

    init(articleID: String, initialSummary: NewsArticleSummary?) {
        self.articleID = articleID
        self.initialSummary = initialSummary
        self._summary = State(initialValue: initialSummary)
    }

    private var activeSummary: NewsArticleSummary? {
        summary ?? newsStore.summary(withID: articleID)
    }

    private var isFavorite: Bool {
        newsStore.isFavorite(id: articleID)
    }

    private var heroMetadata: NewsImage? {
        detail?.heroImage ?? activeSummary?.heroImage
    }

    private var heroImage: Image? {
        heroImageStore.map { Image(uiImage: $0) }
    }

    private var heroImageURL: URL? {
        guard let path = heroMetadata?.url, !path.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return URL(string: path)
    }

    private var heroImageCredit: String? {
        heroMetadata?.credit
    }

    private var displayTitle: String {
        detail?.title ?? activeSummary?.title ?? ""
    }

    private var displaySubtitle: String {
        let source = detail?.shortDescription ?? activeSummary?.shortDescription
        let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed
    }

    private var publishedDateText: String {
        let locale = languageManager.currentLocale
        if let detail {
            return detail.formattedDate(locale: locale)
        }
        if let summary = activeSummary {
            return summary.formattedDate(locale: locale)
        }
        return ""
    }

    private var displayCategory: String? {
        detail?.category ?? activeSummary?.category
    }

    private var displayTags: [String] {
        detail?.tags ?? activeSummary?.tags ?? []
    }

    private var readingTimeText: String? {
        guard let detail else { return nil }
        let wordCount = detail.estimatedWordCount
        guard wordCount > 0 else { return nil }
        let minutes = max(1, Int(round(Double(wordCount) / 200.0)))
        return languageManager.localizedFormat("news.reading_time.minutes", minutes)
    }

    private var shareURL: URL? {
        if let slug = detail?.slug ?? activeSummary?.slug {
            return URL(string: "https://eb-5.app/news/\(slug)")
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                heroSection

            VStack(alignment: .leading, spacing: 20) {
                NewsMetaHeader(
                    publishedDate: publishedDateText,
                    readingTime: readingTimeText,
                    category: displayCategory,
                    tags: displayTags
                    )

                    if !displayTitle.isEmpty {
                        Text(displayTitle)
                            .font(.largeTitle.weight(.bold))
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                    }

                    if !displaySubtitle.isEmpty {
                        Text(displaySubtitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.08))
                            )
                    }

                }
                .padding(.horizontal, 24)

                contentSection

                if let credit = heroImageCredit, !credit.isEmpty {
                    Text(credit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(LocalizedStringKey("news.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                }
                .accessibilityLabel(LocalizedStringKey(isFavorite ? "news.favorites.remove" : "news.favorites.add"))
            }
        }
        .task {
            if summary == nil {
                summary = newsStore.summary(withID: articleID)
            }
            await loadDetail(force: false)
            await scheduleHeroImageLoad(force: false)
        }
        .refreshable {
            await loadDetail(force: true)
            await scheduleHeroImageLoad(force: true)
        }
        .onChange(of: languageManager.currentLocale.identifier) { _ in
            summary = newsStore.summary(withID: articleID)
            Task {
                await loadDetail(force: true)
                await scheduleHeroImageLoad(force: true)
            }
        }
        .onDisappear {
            Task { await cancelHeroImageLoad() }
        }
        .overlay(alignment: .bottom) {
            if let message = errorMessage {
                NewsInlineErrorMessage(
                    message: message,
                    retryAction: { Task { await loadDetail(force: true) } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Sections

private extension NewsDetailView {
    var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = heroImage {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(.secondarySystemGroupedBackground)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.accentColor)
                            .scaleEffect(1.4)
                    }
                }
            }
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    var contentSection: some View {
        Group {
            if let detail, !detail.article.isEmpty {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(Array(detail.article.enumerated()), id: \.offset) { index, block in
                        NewsContentBlockView(block: block, index: index)
                    }
                }
                .padding(.horizontal, 24)
            } else if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    var placeholderHero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.35),
                    Color.accentColor.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "newspaper")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.6))
        }
    }
}

// MARK: - Actions

private extension NewsDetailView {
    func toggleFavorite() {
        newsStore.toggleFavorite(id: articleID)
    }

    func loadDetail(force: Bool = false) async {
        if !force, detail != nil { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await newsStore.fetchDetail(for: articleID, language: languageManager.currentLocale.identifier)
            detail = fetched
            summary = fetched.asSummary
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func scheduleHeroImageLoad(force: Bool) async {
        await cancelHeroImageLoad()
        guard heroImageStore == nil || force else { return }
        heroImageTask = Task { await ensureHeroImage(force: force) }
    }

    @MainActor
    func cancelHeroImageLoad() async {
        heroImageTask?.cancel()
        heroImageTask = nil
    }
    func ensureHeroImage(force: Bool) async {
        guard !Task.isCancelled else { return }
        guard await MainActor.run(body: beginHeroImageLoad) else { return }
        guard let url = heroImageURL else {
            await MainActor.run(body: endHeroImageLoad)
            return
        }
        defer { Task { await MainActor.run(body: endHeroImageLoad) } }
        guard !Task.isCancelled else { return }

        let candidates = candidateImageURLs(from: url)

        if !force, let existing = heroImageStore {
            for key in candidates {
                RemoteImageCache.shared.store(existing, for: key)
            }
            return
        }

        for key in candidates {
            if Task.isCancelled { return }
            if let cached = RemoteImageCache.shared.image(for: key) {
                for target in candidates {
                    RemoteImageCache.shared.store(cached, for: target)
                }
                await MainActor.run { heroImageStore = cached }
                if !force {
                    return
                }
            }
        }

        for key in candidates {
            if Task.isCancelled { return }
            do {
                var request = URLRequest(url: key)
                request.cachePolicy = force ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
                request.timeoutInterval = 30
                let (data, _) = try await NewsImageLoader.shared.dataTask(for: request)
                if let uiImage = UIImage(data: data) {
                    for target in candidates {
                        RemoteImageCache.shared.store(uiImage, for: target)
                    }
                    await MainActor.run { heroImageStore = uiImage }
                    return
                }
            } catch {
                if Task.isCancelled { return }
                continue
            }
        }
    }

    @MainActor
    func beginHeroImageLoad() -> Bool {
        if isLoadingImage {
            return false
        }
        isLoadingImage = true
        return true
    }

    @MainActor
    func endHeroImageLoad() {
        isLoadingImage = false
        heroImageTask = nil
    }

    @MainActor
    func candidateImageURLs(from url: URL) -> [URL] {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [url]
        }

        let normalizedHost = components.host?.lowercased()
        let path = components.path.lowercased()
        let isStaticAsset = path.contains("/app-img/")

        var hosts: [String] = []
        if isStaticAsset {
            hosts.append("eb-5.app")
            hosts.append("api.eb-5.app")
            hosts.append("news-service.replit.app")
            if let normalizedHost, !normalizedHost.isEmpty {
                hosts.append(normalizedHost)
            }
        } else {
            if let normalizedHost, !normalizedHost.isEmpty {
                hosts.append(normalizedHost)
            }
            hosts.append(contentsOf: ["api.eb-5.app", "news-service.replit.app"])
        }

        let priorityHosts = hosts.uniqued(prepending: nil)

        var unique: [URL] = []
        var seen = Set<String>()

        for host in priorityHosts {
            guard !host.isEmpty else { continue }
            components.scheme = "https"
            components.host = host
            if let candidate = components.url {
                let key = candidate.absoluteString
                if !seen.contains(key) {
                    unique.append(candidate)
                    seen.insert(key)
                }
            }
        }

        return unique
    }
}

// MARK: - Subviews

private struct NewsMetaHeader: View {
    let publishedDate: String
    let readingTime: String?
    let category: String?
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category, !category.isEmpty {
                Label(category, systemImage: "newspaper.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .labelStyle(.titleAndIcon)
            }

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                if !publishedDate.isEmpty {
                    Label(publishedDate, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let readingTime {
                    Label(readingTime, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !tags.isEmpty {
                NewsTagStrip(tags: tags)
            }
        }
    }
}

private struct NewsInlineErrorMessage: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Button(action: retryAction) {
                Text(LocalizedStringKey("common.retry"))
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentColor)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
        )
    }
}

private struct NewsContentBlockView: View {
    let block: NewsBlock
    let index: Int

    var body: some View {
        switch block.type.lowercased() {
        case "heading":
            heading(level: block.level ?? 1, text: block.text ?? "")
        case "subheading":
            subheading(level: block.level ?? 2, text: block.text ?? "")
        case "paragraph":
            paragraph(text: block.text ?? "")
        case "quote":
            quote(text: block.text ?? "", attribution: block.attribution)
        case "callout":
            callout(text: block.text ?? "", title: block.title, variant: block.variant)
        case "list":
            list(items: block.items ?? [])
        default:
            paragraph(text: block.text ?? "")
        }
    }

    private func heading(level: Int, text: String) -> some View {
        let font: Font
        switch level {
        case ...1:
            font = .title2.weight(.bold)
        case 2:
            font = .title3.weight(.semibold)
        default:
            font = .headline.weight(.semibold)
        }
        return Text(text)
            .font(font)
            .foregroundStyle(.primary)
            .padding(.top, level <= 2 ? 12 : 8)
            .padding(.bottom, -4)
    }

    private func subheading(level: Int, text: String) -> some View {
        Text(text)
            .font(level <= 2 ? .title3.weight(.semibold) : .headline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.top, 10)
            .padding(.bottom, -4)
    }

    private func paragraph(text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .lineSpacing(6)
    }

    private func quote(text: String, attribution: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text)
                .font(.title3.weight(.semibold))
                .italic()
                .foregroundStyle(.primary)
            if let attribution, !attribution.isEmpty {
                Text(attribution)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
    }

    private func callout(text: String, title: String?, variant: String?) -> some View {
        let style = NewsCalloutStyle(variant: variant)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: style.iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(style.tint)
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(style.background)
        )
    }

    private func list(items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(item)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct NewsCalloutStyle {
    let iconName: String
    let tint: Color
    let background: Color

    init(variant: String?) {
        switch variant?.lowercased() {
        case "warning":
            iconName = "exclamationmark.triangle.fill"
            tint = Color.orange
            background = Color.orange.opacity(0.1)
        case "success":
            iconName = "checkmark.seal.fill"
            tint = Color.green
            background = Color.green.opacity(0.12)
        case "danger", "error":
            iconName = "xmark.octagon.fill"
            tint = Color.red
            background = Color.red.opacity(0.12)
        default:
            iconName = "info.circle.fill"
            tint = Color.accentColor
            background = Color.accentColor.opacity(0.1)
        }
    }
}

extension Array where Element == String {
    func uniqued(prepending value: String?) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        if let v = value, !v.isEmpty, !seen.contains(v) {
            result.append(v)
            seen.insert(v)
        }
        for element in self {
            if !seen.contains(element) {
                result.append(element)
                seen.insert(element)
            }
        }
        return result
    }
}
