import Foundation
import Combine

final class QuizSessionViewModel: ObservableObject {
    let category: QuizCategory

    @Published private(set) var currentQuestionIndex: Int = 0
    @Published private(set) var selections: [UUID: UUID] = [:]
    @Published private(set) var revealedQuestionIDs: Set<UUID> = []
    @Published private(set) var completedAttempt: QuizAttempt?

    private var durations: [UUID: TimeInterval] = [:]
    private var questionStartTime: Date = Date()
    private var sessionStartTime: Date = Date()

    init(category: QuizCategory) {
        self.category = category
        resetSession()
    }

    var currentQuestion: QuizQuestion {
        category.questions[currentQuestionIndex]
    }

    var isLastQuestion: Bool {
        currentQuestionIndex >= category.questions.count - 1
    }

    func resetSession() {
        currentQuestionIndex = 0
        selections = [:]
        revealedQuestionIDs = []
        completedAttempt = nil
        durations = [:]
        let now = Date()
        questionStartTime = now
        sessionStartTime = now
    }

    func selectedChoice(for question: QuizQuestion) -> UUID? {
        selections[question.id]
    }

    func shouldRevealCorrectAnswer(for question: QuizQuestion) -> Bool {
        revealedQuestionIDs.contains(question.id)
    }

    func select(choiceID: UUID, for question: QuizQuestion) {
        selections[question.id] = choiceID
        if choiceID != question.correctChoiceID {
            revealedQuestionIDs.insert(question.id)
        }
    }

    @discardableResult
    func advance() -> QuizAttempt? {
        recordDuration(for: currentQuestion)

        if isLastQuestion {
            let attempt = finalizeAttempt()
            completedAttempt = attempt
            return attempt
        } else {
            currentQuestionIndex += 1
            questionStartTime = Date()
            return nil
        }
    }

    private func recordDuration(for question: QuizQuestion) {
        let elapsed = Date().timeIntervalSince(questionStartTime)
        guard elapsed >= 0 else { return }
        durations[question.id, default: 0] += elapsed
    }

    private func finalizeAttempt() -> QuizAttempt {
        let correctAnswers = category.questions.reduce(into: 0) { partialResult, question in
            if selections[question.id] == question.correctChoiceID {
                partialResult += 1
            }
        }

        let totalDuration = durations.values.reduce(0, +)

        return QuizAttempt(
            categoryID: category.canonicalName,
            totalQuestions: category.totalQuestions,
            correctAnswers: correctAnswers,
            totalDuration: totalDuration
        )
    }
}
