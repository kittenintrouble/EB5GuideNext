import SwiftUI

struct BaseView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var store = BaseContentStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.categories.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let categories = store.categories
                            ForEach(Array(categories.enumerated()), id: \.element.id) { _, category in
                                let completed = store.completionCount(for: category.articles)
                                let appearanceName = store.appearanceCategoryName(for: category.articles) ?? category.name
                                let appearance = CategoryAppearance.forCategory(appearanceName)
                                NavigationLink {
                                    CategoryDetailView(store: store, categoryName: category.name)
                                } label: {
                                    CategoryRowView(
                                        title: category.name,
                                        completed: completed,
                                        total: category.totalCount,
                                        appearance: appearance
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(LocalizedStringKey("tab.base"))
            .navigationBarTitleDisplayMode(.large)
        }
        .id(languageManager.currentLocale.identifier)
        .onAppear {
            store.loadArticles(for: languageManager.currentLocale.identifier)
        }
        .onChange(of: languageManager.currentLocale.identifier) { newValue in
            store.loadArticles(for: newValue)
        }
    }
}

private struct CategoryDetailView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: BaseContentStore
    let categoryName: String
    let onTapBase: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(store: BaseContentStore, categoryName: String, onTapBase: (() -> Void)? = nil) {
        self.store = store
        self.categoryName = categoryName
        self.onTapBase = onTapBase
    }

    var body: some View {
        let crumbs = [
            BreadcrumbItem(title: .localizedKey("tab.base"), action: {
                dismiss()
                onTapBase?()
            }),
            BreadcrumbItem(title: .plain(categoryName), action: nil)
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BreadcrumbBar(items: crumbs, activeID: crumbs.last?.id)
                    .padding(.top, 4)

                let subcategories = store.subcategories(in: categoryName)
                LazyVStack(spacing: 12) {
                    ForEach(Array(subcategories.enumerated()), id: \.element.id) { _, subcategory in
                        let completed = store.completionCount(for: subcategory.articles)
                        let appearanceName = store.appearanceCategoryName(for: subcategory.articles) ?? categoryName
                        let canonicalSubcategory = subcategory.canonicalName ?? subcategory.name
                        let baseAppearance = CategoryAppearance.forCategory(appearanceName)
                        let appearance = CategoryAppearance.iconName(forSubcategory: canonicalSubcategory).map { baseAppearance.withIcon($0) } ?? baseAppearance

                        NavigationLink {
                            SubcategoryDetailView(
                                store: store,
                                categoryName: categoryName,
                                subcategoryName: subcategory.name,
                                onTapBase: {
                                    dismiss()
                                    onTapBase?()
                                }
                            )
                            .environmentObject(languageManager)
                        } label: {
                            CategoryRowView(
                                title: subcategory.name,
                                completed: completed,
                                total: subcategory.totalCount,
                                appearance: appearance,
                                isCompact: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(categoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SubcategoryDetailView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: BaseContentStore
    let categoryName: String
    let subcategoryName: String
    let onTapBase: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(store: BaseContentStore, categoryName: String, subcategoryName: String, onTapBase: (() -> Void)? = nil) {
        self.store = store
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.onTapBase = onTapBase
    }

    var body: some View {
        let articleList = store.articles(in: categoryName, subcategory: subcategoryName)
        let enumeratedArticles = Array(articleList.enumerated())

        let crumbs = [
            BreadcrumbItem(title: .localizedKey("tab.base"), action: {
                dismiss()
                onTapBase?()
            }),
            BreadcrumbItem(title: .plain(categoryName), action: {
                dismiss()
            }),
            BreadcrumbItem(title: .plain(subcategoryName), action: nil)
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BreadcrumbBar(items: crumbs, activeID: crumbs.last?.id)
                    .padding(.top, 4)

                ForEach(enumeratedArticles, id: \.element.id) { _, article in
                    NavigationLink {
                        ArticleDetailView(
                            store: store,
                            categoryName: categoryName,
                            subcategoryName: subcategoryName,
                            articleID: article.id,
                            onTapCategory: {
                                dismiss()
                            },
                            onTapBase: {
                                dismiss()
                                onTapBase?()
                            }
                        )
                        .environmentObject(languageManager)
                    } label: {
                        ArticleRowView(
                            title: article.title,
                            isFavorite: store.isFavorite(article.id),
                            isCompleted: store.isCompleted(article.id)
                        ) {
                            store.toggleFavorite(for: article.id)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(subcategoryName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ArticleDetailView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var store: BaseContentStore
    let categoryName: String
    let subcategoryName: String
    let articleID: Int
    let onTapCategory: (() -> Void)?
    let onTapBase: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(store: BaseContentStore, categoryName: String, subcategoryName: String, articleID: Int, onTapCategory: (() -> Void)? = nil, onTapBase: (() -> Void)? = nil) {
        self.store = store
        self.categoryName = categoryName
        self.subcategoryName = subcategoryName
        self.articleID = articleID
        self.onTapCategory = onTapCategory
        self.onTapBase = onTapBase
    }

    var body: some View {
        Group {
            if let article = store.article(withID: articleID) {
                let appearanceName = store.appearanceCategoryName(forArticleID: article.id) ?? categoryName
                let baseAppearance = CategoryAppearance.forCategory(appearanceName)
                let appearance = CategoryAppearance.iconName(forSubcategory: store.canonicalSubcategoryName(for: [article]) ?? subcategoryName).map { baseAppearance.withIcon($0) } ?? baseAppearance

                let crumbs = [
                    BreadcrumbItem(title: .localizedKey("tab.base"), action: {
                        dismiss()
                        onTapBase?()
                    }),
                    BreadcrumbItem(title: .plain(categoryName), action: {
                        dismiss()
                        onTapCategory?()
                    }),
                    BreadcrumbItem(title: .plain(subcategoryName), action: {
                        dismiss()
                    }),
                    BreadcrumbItem(title: .plain(article.title), action: nil)
                ]

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        BreadcrumbBar(items: crumbs, activeID: crumbs.last?.id)
                            .padding(.top, 4)

                        Text(article.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack {
                            Button {
                                store.toggleCompleted(for: article.id)
                            } label: {
                                CompletedButtonLabel(
                                    isCompleted: store.isCompleted(article.id),
                                    tint: appearance.primaryColor
                                )
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            FavoriteButton(
                                isFavorite: store.isFavorite(article.id),
                                action: { store.toggleFavorite(for: article.id) }
                            )
                        }

                        InfoCard {
                            Text(article.description)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let examples = article.examples, !examples.isEmpty {
                            InfoCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(
                                        title: { Text(LocalizedStringKey("base.examples")) },
                                        icon: { Image(systemName: "lightbulb.max.fill") }
                                    )
                                    .font(.headline)
                                    .foregroundStyle(appearance.primaryColor)

                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(examples, id: \.self) { example in
                                            HStack(alignment: .top, spacing: 8) {
                                                Text("•")
                                                    .font(.headline)
                                                    .foregroundStyle(Color(.secondaryLabel))
                                                Text(example)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("base.article.unavailable")
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(LocalizedStringKey("base.back"))
                    }
                }
            }
        }
    }
}

private struct CategoryRowView: View {
    let title: String
    let completed: Int
    let total: Int
    let appearance: CategoryAppearance
    var isCompact: Bool = false

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 12) {
            GradientIcon(appearance: appearance, size: isCompact ? 42 : 50)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(isCompact ? .body.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("base.completed_format \(completed) \(total)")
                    .font(.footnote)
                    .foregroundStyle(Color(.secondaryLabel))

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(appearance.primaryColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 4)
    }
}

private struct ArticleRowView: View {
    let title: String
    let isFavorite: Bool
    let isCompleted: Bool
    let toggleFavorite: () -> Void
    var tint: Color

    init(title: String, isFavorite: Bool, isCompleted: Bool, tint: Color = Color(red: 0.92, green: 0.21, blue: 0.32), toggleFavorite: @escaping () -> Void) {
        self.title = title
        self.isFavorite = isFavorite
        self.isCompleted = isCompleted
        self.tint = tint
        self.toggleFavorite = toggleFavorite
    }

    var body: some View {
        HStack(spacing: 12) {
            FavoriteButton(
                isFavorite: isFavorite,
                action: toggleFavorite,
                tint: tint
            )

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()

            if isCompleted {
                CompletedBadge()
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct GradientIcon: View {
    let appearance: CategoryAppearance
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(appearance.gradient)
                .frame(width: size, height: size)

            Image(systemName: appearance.iconName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

private struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void
    var tint: Color = Color(red: 0.92, green: 0.21, blue: 0.32)

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isFavorite ? tint : Color(.tertiaryLabel))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isFavorite ? "base.favorite.remove" : "base.favorite.add"))
    }
}

private struct CompletedButtonLabel: View {
    let isCompleted: Bool
    let tint: Color

    var body: some View {
        Group {
            if isCompleted {
                Label("base.article.completed", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            } else {
                Label("base.article.mark_completed", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(tint)
                    )
            }
        }
    }
}

private struct CompletedBadge: View {
    var body: some View {
        Text("base.article.completed_badge")
            .font(.caption.bold())
            .foregroundStyle(Color.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.12))
            )
    }
}

private struct InfoCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct BreadcrumbItem: Identifiable {
    enum Title {
        case localizedKey(String)
        case plain(String)
    }

    let id = UUID()
    let title: Title
    let action: (() -> Void)?

    init(title: Title, action: (() -> Void)?) {
        self.title = title
        self.action = action
    }

    static func localizedKey(_ key: String, action: (() -> Void)? = nil) -> BreadcrumbItem {
        BreadcrumbItem(title: .localizedKey(key), action: action)
    }

    static func plain(_ text: String, action: (() -> Void)? = nil) -> BreadcrumbItem {
        BreadcrumbItem(title: .plain(text), action: action)
    }
}

private struct BreadcrumbBar: View {
    let items: [BreadcrumbItem]
    let activeID: UUID?

    @State private var scrollTrigger = UUID()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        crumb(for: item, isCurrent: index == items.count - 1)

                        if index < items.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 6)
            .onAppear { scheduleScroll() }
            .onChange(of: activeID) { _ in scheduleScroll() }
            .onChange(of: items.count) { _ in scheduleScroll() }
            .onChange(of: scrollTrigger) { _ in scrollToActive(proxy: proxy) }
        }
    }

    @ViewBuilder
    private func crumb(for item: BreadcrumbItem, isCurrent: Bool) -> some View {
        let label = label(for: item)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)

        if let action = item.action {
            Button(action: action) {
                label
                    .foregroundStyle(Color.accentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)
            .id(item.id)
        } else {
            label
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemGray5))
                )
                .id(item.id)
        }
    }

    private func label(for item: BreadcrumbItem) -> Text {
        switch item.title {
        case .localizedKey(let key):
            return Text(LocalizedStringKey(key))
        case .plain(let text):
            return Text(text)
        }
    }

    private func scheduleScroll() {
        scrollTrigger = UUID()
    }

    private func scrollToActive(proxy: ScrollViewProxy) {
        let targetID = activeID ?? items.last?.id
        guard let id = targetID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .trailing)
            }
        }
    }
}

private struct CategoryAppearance {
    let iconName: String
    let gradient: LinearGradient
    let primaryColor: Color

    static func forCategory(_ name: String) -> CategoryAppearance {
        switch name {
        case "Compliance":
            return CategoryAppearance(
                iconName: "book.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.36, green: 0.63, blue: 0.99), Color(red: 0.11, green: 0.32, blue: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.22, green: 0.42, blue: 0.87)
            )
        case "EB-5 Basics":
            return CategoryAppearance(
                iconName: "graduationcap.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.73, green: 0.55, blue: 0.99), Color(red: 0.49, green: 0.28, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.54, green: 0.32, blue: 0.93)
            )
        case "Foundations":
            return CategoryAppearance(
                iconName: "chart.bar.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.96, green: 0.54, blue: 0.83), Color(red: 0.74, green: 0.24, blue: 0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.74, green: 0.24, blue: 0.58)
            )
        case "Immigration & Legal Process":
            return CategoryAppearance(
                iconName: "doc.richtext.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.34, green: 0.79, blue: 0.86), Color(red: 0.13, green: 0.53, blue: 0.67)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.16, green: 0.56, blue: 0.69)
            )
        case "Investment":
            return CategoryAppearance(
                iconName: "dollarsign.circle.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.46, green: 0.85, blue: 0.49), Color(red: 0.14, green: 0.59, blue: 0.36)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.17, green: 0.60, blue: 0.38)
            )
        case "Real Estate & Business":
            return CategoryAppearance(
                iconName: "building.2.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.99, green: 0.64, blue: 0.40), Color(red: 0.83, green: 0.39, blue: 0.19)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.84, green: 0.40, blue: 0.20)
            )
        case "Risk Management":
            return CategoryAppearance(
                iconName: "shield.checkerboard",
                gradient: LinearGradient(
                    colors: [Color(red: 0.98, green: 0.45, blue: 0.50), Color(red: 0.78, green: 0.12, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.81, green: 0.21, blue: 0.30)
            )
        default:
            return CategoryAppearance(
                iconName: "square.grid.2x2.fill",
                gradient: LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color.accentColor
            )
        }
    }

    func withIcon(_ icon: String) -> CategoryAppearance {
        CategoryAppearance(iconName: icon, gradient: gradient, primaryColor: primaryColor)
    }

    static func iconName(forSubcategory name: String) -> String? {
        let mapping: [String: String] = [
            "Program Basics": "book.closed",
            "Investment Models": "chart.pie.fill",
            "USCIS Criteria": "checkmark.seal",
            "Eligibility Requirements": "clipboard",
            "Benefits of EB-5": "star.circle.fill",
            "History of EB-5": "clock.arrow.circlepath",
            "EB-5 Visa Types": "doc.text",
            "Direct Investment": "briefcase.fill",
            "Regional Centers": "globe",
            "Targeted Employment Areas": "mappin.circle",
            "At-Risk Investments": "exclamationmark.triangle.fill",
            "Investment Amounts": "dollarsign.circle",
            "Investment Projects Types": "cube.box.fill",
            "Funding Sources": "creditcard",
            "Selecting Real Estate Projects": "building.2.crop.circle",
            "Types of Real Estate Investments": "building.2",
            "Market Analysis": "chart.line.uptrend.xyaxis",
            "Project Development Cycle": "arrow.triangle.2.circlepath",
            "Commercial vs Residential": "building.columns",
            "EB-5 Business Plan": "doc.text.magnifyingglass",
            "Case Studies": "doc.text.image",
            "EB-5 Petition Process": "doc.append",
            "EB-5 Application Forms": "doc.on.doc",
            "Green Card Process": "person.crop.circle.badge.checkmark",
            "Adjustment of Status vs Consular Processing": "airplane.departure",
            "Immigration Attorneys & Consultants": "questionmark.circle",
            "Common EB-5 Issues & Denials": "xmark.octagon",
            "Family Immigration through EB-5": "person.2",
            "EB-5 Investment Risks": "shield.slash",
            "Due Diligence Process": "magnifyingglass.circle",
            "Fraud Prevention": "hand.raised",
            "EB-5 Project Exit Strategies": "arrow.uturn.right.circle",
            "Legal and Financial Safeguards": "shield.lefthalf.filled"
        ]
        return mapping[name]
    }
}
