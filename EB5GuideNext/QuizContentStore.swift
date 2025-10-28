import Foundation
import Combine

struct QuizChoice: Identifiable, Hashable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

struct QuizQuestion: Identifiable, Hashable {
    let id: UUID
    let articleID: Int
    let canonicalCategory: String
    let canonicalSubcategory: String?
    let localizedSubcategory: String?
    let promptArticleTitle: String
    let detail: String?
    let choices: [QuizChoice]
    let correctChoiceID: UUID

    init(
        id: UUID = UUID(),
        articleID: Int,
        canonicalCategory: String,
        canonicalSubcategory: String?,
        localizedSubcategory: String?,
        promptArticleTitle: String,
        detail: String?,
        choices: [QuizChoice],
        correctChoiceID: UUID
    ) {
        self.id = id
        self.articleID = articleID
        self.canonicalCategory = canonicalCategory
        self.canonicalSubcategory = canonicalSubcategory
        self.localizedSubcategory = localizedSubcategory
        self.promptArticleTitle = promptArticleTitle
        self.detail = detail
        self.choices = choices
        self.correctChoiceID = correctChoiceID
    }

    var correctChoice: QuizChoice? {
        choices.first(where: { $0.id == correctChoiceID })
    }
}

struct QuizCategory: Identifiable, Hashable {
    let canonicalName: String
    let title: String
    let appearanceName: String
    let questions: [QuizQuestion]

    var id: String { canonicalName }
    var totalQuestions: Int { questions.count }
}

struct QuizResult: Codable, Equatable {
    var attempts: Int
    var totalQuestions: Int
    var bestCorrectAnswers: Int
    var cumulativeTime: TimeInterval
    var cumulativeQuestions: Int

    var averageTimePerQuestion: Double {
        guard cumulativeQuestions > 0 else { return 0 }
        return cumulativeTime / Double(cumulativeQuestions)
    }
}

struct QuizAttempt {
    let categoryID: String
    let totalQuestions: Int
    let correctAnswers: Int
    let totalDuration: TimeInterval
}

final class QuizContentStore: ObservableObject {
    @Published private(set) var categories: [QuizCategory] = []
    @Published private(set) var resultsByCategory: [String: QuizResult]

    private let baseStore: BaseContentStore
    private let defaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []

    private static let resultsStorageKey = "quiz.results.v1"
    private static let maxQuestionCount = 12
    private static let minimumDistractorCount = 2

    init(baseStore: BaseContentStore, defaults: UserDefaults = .standard) {
        self.baseStore = baseStore
        self.defaults = defaults
        self.resultsByCategory = Self.loadResults(from: defaults)

        baseStore.$articles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] articles in
                self?.regenerateCategories(using: articles)
            }
            .store(in: &cancellables)

        regenerateCategories(using: baseStore.articles)
    }

    func category(withID id: String) -> QuizCategory? {
        categories.first(where: { $0.canonicalName == id })
    }

    func result(for categoryID: String) -> QuizResult? {
        resultsByCategory[categoryID]
    }

    @discardableResult
    func record(_ attempt: QuizAttempt) -> QuizResult {
        var stored = resultsByCategory[attempt.categoryID] ?? QuizResult(
            attempts: 0,
            totalQuestions: attempt.totalQuestions,
            bestCorrectAnswers: 0,
            cumulativeTime: 0,
            cumulativeQuestions: 0
        )

        stored.attempts += 1
        stored.totalQuestions = attempt.totalQuestions
        stored.bestCorrectAnswers = max(stored.bestCorrectAnswers, attempt.correctAnswers)
        stored.cumulativeTime += attempt.totalDuration
        stored.cumulativeQuestions += attempt.totalQuestions

        resultsByCategory[attempt.categoryID] = stored
        persistResults()

        return stored
    }

    private func regenerateCategories(using articles: [EB5Article]) {
        guard !articles.isEmpty else {
            categories = []
            return
        }

        let topics = articles.compactMap { article -> ArticleTopic? in
            guard let canonicalCategory = baseStore.appearanceCategoryName(forArticleID: article.id) else {
                return nil
            }

            let summary = article.shortDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? article.description.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !summary.isEmpty else { return nil }

            let canonicalSubcategory = baseStore.canonicalSubcategoryName(forArticleID: article.id)

            return ArticleTopic(
                article: article,
                canonicalCategory: canonicalCategory,
                canonicalSubcategory: canonicalSubcategory,
                localizedSubcategory: article.subcategory,
                summary: summary
            )
        }

        let grouped = Dictionary(grouping: topics, by: { $0.canonicalCategory })

        let allTopicsSorted = topics.sorted { lhs, rhs in
            if lhs.article.dayNumber != rhs.article.dayNumber,
               lhs.article.dayNumber != nil,
               rhs.article.dayNumber != nil {
                return lhs.article.dayNumber ?? 0 < rhs.article.dayNumber ?? 0
            }
            return lhs.article.id < rhs.article.id
        }

        let newCategories: [QuizCategory] = grouped.compactMap { canonical, categoryTopics in
            guard let localizedName = categoryTopics.first?.article.category else { return nil }
            let sortedTopics = categoryTopics.sorted(by: Self.topicSort(lhs:rhs:))
            let questions = buildQuestions(
                from: sortedTopics,
                allTopics: allTopicsSorted,
                canonicalCategory: canonical,
                localizedName: localizedName
            )

            guard !questions.isEmpty else { return nil }

            return QuizCategory(
                canonicalName: canonical,
                title: localizedName,
                appearanceName: canonical,
                questions: questions
            )
        }
        .sorted { lhs, rhs in
            guard let lhsIndex = BaseContentStore.categoryOrder.firstIndex(of: lhs.canonicalName),
                  let rhsIndex = BaseContentStore.categoryOrder.firstIndex(of: rhs.canonicalName) else {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            if lhsIndex == rhsIndex {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhsIndex < rhsIndex
        }

        categories = newCategories
    }

    private func buildQuestions(
        from topics: [ArticleTopic],
        allTopics: [ArticleTopic],
        canonicalCategory: String,
        localizedName: String
    ) -> [QuizQuestion] {
        guard !topics.isEmpty else { return [] }

        let grouped = Dictionary(grouping: topics, by: { $0.canonicalSubcategory ?? $0.article.subcategory })
        let orderedSubcategories = grouped.keys.sorted()
        var queue = orderedSubcategories.reduce(into: [String: [ArticleTopic]]()) { partialResult, key in
            partialResult[key] = grouped[key]?.sorted(by: Self.topicSort(lhs:rhs:)) ?? []
        }

        var selectedTopics: [ArticleTopic] = []
        selectedTopics.reserveCapacity(Self.maxQuestionCount)

        while selectedTopics.count < Self.maxQuestionCount {
            var addedInRound = false
            for key in orderedSubcategories {
                guard var list = queue[key], !list.isEmpty else { continue }
                let next = list.removeFirst()
                queue[key] = list
                selectedTopics.append(next)
                addedInRound = true
                if selectedTopics.count == Self.maxQuestionCount {
                    break
                }
            }
            if !addedInRound { break }
        }

        if selectedTopics.isEmpty {
            selectedTopics = topics.sorted(by: Self.topicSort(lhs:rhs:))
        }

        let questionCount = min(Self.maxQuestionCount, selectedTopics.count)
        var questions: [QuizQuestion] = []
        questions.reserveCapacity(questionCount)

        for (index, topic) in selectedTopics.prefix(questionCount).enumerated() {
            let detailText = topic.article.description.trimmingCharacters(in: .whitespacesAndNewlines)

            let incorrectOptions = distractors(
                for: topic,
                within: topics,
                allTopics: allTopics,
                desiredCount: Self.minimumDistractorCount,
                seed: index
            )

            let correctChoice = QuizChoice(text: topic.summary)
            var optionPool = incorrectOptions.map { QuizChoice(text: $0.summary) }
            let insertionIndex = (topic.article.id + index) % (optionPool.count + 1)
            optionPool.insert(correctChoice, at: insertionIndex)

            let question = QuizQuestion(
                articleID: topic.article.id,
                canonicalCategory: canonicalCategory,
                canonicalSubcategory: topic.canonicalSubcategory,
                localizedSubcategory: topic.localizedSubcategory,
                promptArticleTitle: topic.article.title,
                detail: detailText.isEmpty ? nil : detailText,
                choices: optionPool,
                correctChoiceID: correctChoice.id
            )

            questions.append(question)
        }

        return questions
    }

    private func distractors(
        for topic: ArticleTopic,
        within categoryTopics: [ArticleTopic],
        allTopics: [ArticleTopic],
        desiredCount: Int,
        seed: Int
    ) -> [ArticleTopic] {
        var candidates = categoryTopics.filter { $0.article.id != topic.article.id && $0.summary != topic.summary }

        if candidates.count < desiredCount {
            let additional = allTopics.filter { $0.canonicalCategory != topic.canonicalCategory && $0.summary != topic.summary }
            candidates.append(contentsOf: additional)
        }

        let sorted = candidates.sorted(by: Self.topicSort(lhs:rhs:))
        var result: [ArticleTopic] = []
        result.reserveCapacity(desiredCount)

        for offset in 0..<desiredCount {
            guard !sorted.isEmpty else { break }
            let index = (seed + offset) % sorted.count
            let candidate = sorted[index]
            if !result.contains(where: { $0.summary == candidate.summary }) {
                result.append(candidate)
            }
        }

        return result
    }

    nonisolated fileprivate static func topicSort(lhs: ArticleTopic, rhs: ArticleTopic) -> Bool {
        if let lhsDay = lhs.article.dayNumber, let rhsDay = rhs.article.dayNumber, lhsDay != rhsDay {
            return lhsDay < rhsDay
        }
        return lhs.article.id < rhs.article.id
    }

    private func persistResults() {
        guard let data = try? JSONEncoder().encode(resultsByCategory) else { return }
        defaults.set(data, forKey: Self.resultsStorageKey)
    }

    private static func loadResults(from defaults: UserDefaults) -> [String: QuizResult] {
        guard let data = defaults.data(forKey: resultsStorageKey),
              let decoded = try? JSONDecoder().decode([String: QuizResult].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

fileprivate struct ArticleTopic: Hashable {
    let article: EB5Article
    let canonicalCategory: String
    let canonicalSubcategory: String?
    let localizedSubcategory: String
    let summary: String
}
