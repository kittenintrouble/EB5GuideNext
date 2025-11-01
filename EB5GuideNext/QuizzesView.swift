import SwiftUI

struct QuizzesView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var quizStore: QuizContentStore

    var body: some View {
        NavigationStack {
            Group {
                if quizStore.categories.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(quizStore.categories) { category in
                                NavigationLink {
                                    QuizRunnerView(category: category)
                                        .environmentObject(languageManager)
                                        .environmentObject(quizStore)
                                } label: {
                                    QuizCategoryRow(
                                        category: category,
                                        result: quizStore.result(for: category.canonicalName)
                                    )
                                    .environmentObject(languageManager)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(languageManager.localizedString(for: "quiz.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageSwitchMenu(languageManager: languageManager)
                }
            }
        }
    }
}

private struct QuizCategoryRow: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let category: QuizCategory
    let result: QuizResult?

    var body: some View {
        let appearance = CategoryAppearance.forCategory(category.appearanceName)
        let score = result?.bestCorrectAnswers ?? 0
        let progress = category.totalQuestions > 0
            ? Double(score) / Double(category.totalQuestions)
            : 0
        let progressText = languageManager.localizedFormat("quiz.row.progress_format", score, category.totalQuestions)

        HStack(alignment: .center, spacing: 16) {
            GradientIcon(appearance: appearance, size: 52)

            VStack(alignment: .leading, spacing: 12) {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(progressText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(appearance.primaryColor)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 4)
    }
}

private struct QuizRunnerView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    struct SessionResult {
        let attempt: QuizAttempt
        let aggregate: QuizResult
    }

    let category: QuizCategory

    @EnvironmentObject private var quizStore: QuizContentStore
    @StateObject private var viewModel: QuizSessionViewModel
    @State private var sessionResult: SessionResult?
    @State private var pathID = UUID()
    @Environment(\.dismiss) private var dismiss

    init(category: QuizCategory) {
        self.category = category
        _viewModel = StateObject(wrappedValue: QuizSessionViewModel(category: category))
    }

    var body: some View {
        let appearance = CategoryAppearance.forCategory(category.appearanceName)

        Group {
            if let result = sessionResult {
                QuizResultView(
                    category: category,
                    attempt: result.attempt,
                    aggregate: result.aggregate,
                    appearance: appearance,
                    onRestart: restart
                )
                .environmentObject(languageManager)
            } else {
                QuizQuestionFlow(
                    category: category,
                    appearance: appearance,
                    question: viewModel.currentQuestion,
                    index: viewModel.currentQuestionIndex,
                    total: category.totalQuestions,
                    selectedChoiceID: viewModel.selectedChoice(for: viewModel.currentQuestion),
                    revealCorrect: viewModel.shouldRevealCorrectAnswer(for: viewModel.currentQuestion),
                    onSelect: { choice in
                        viewModel.select(choiceID: choice.id, for: viewModel.currentQuestion)
                    },
                    onNext: advance,
                    isLast: viewModel.isLastQuestion
                )
                .environmentObject(languageManager)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(category.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if sessionResult == nil {
                    Button("quiz.action.restart") {
                        restart()
                    }
                } else {
                    Button("quiz.action.close") {
                        dismiss()
                    }
                }
            }
        }
        .id(pathID)
    }

    private func advance() {
        if let attempt = viewModel.advance() {
            let aggregate = quizStore.record(attempt)
            sessionResult = SessionResult(attempt: attempt, aggregate: aggregate)
        }
    }

    private func restart() {
        viewModel.resetSession()
        sessionResult = nil
        pathID = UUID()
    }
}

private struct QuizQuestionFlow: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let category: QuizCategory
    let appearance: CategoryAppearance
    let question: QuizQuestion
    let index: Int
    let total: Int
    let selectedChoiceID: UUID?
    let revealCorrect: Bool
    let onSelect: (QuizChoice) -> Void
    let onNext: () -> Void
    let isLast: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                progressHeader

                QuizQuestionCard(
                    question: question,
                    selectedChoiceID: selectedChoiceID,
                    revealCorrect: revealCorrect,
                    appearance: appearance,
                    onSelect: onSelect
                )
                .environmentObject(languageManager)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localizedFormat("quiz.progress_format", index + 1, total))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            ProgressView(value: Double(index + 1), total: Double(total))
                .progressViewStyle(.linear)
                .tint(appearance.primaryColor)
        }
    }

    private var actionBar: some View {
        let isDisabled = selectedChoiceID == nil
        return VStack(spacing: 12) {
            Button(action: onNext) {
                Text(isLast ? "quiz.action.finish" : "quiz.action.next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(appearance.primaryColor.opacity(isDisabled ? 0.4 : 1))
                    .foregroundStyle(Color.white)
                    .cornerRadius(16)
            }
            .disabled(isDisabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: -2)
    }
}

private struct QuizQuestionCard: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let question: QuizQuestion
    let selectedChoiceID: UUID?
    let revealCorrect: Bool
    let appearance: CategoryAppearance
    let onSelect: (QuizChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let subcategory = question.localizedSubcategory, !subcategory.isEmpty {
                Text(subcategory)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appearance.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(appearance.primaryColor.opacity(0.12))
                    )
            }

            Text(languageManager.localizedFormat("quiz.prompt.match_description", question.promptArticleTitle))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(question.choices) { choice in
                    QuizChoiceRow(
                        choice: choice,
                        isSelected: selectedChoiceID == choice.id,
                        isCorrect: choice.id == question.correctChoiceID,
                        revealCorrect: revealCorrect,
                        appearance: appearance,
                        onTap: {
                            withAnimation(.none) {
                                onSelect(choice)
                            }
                        }
                    )
                }
            }

            if let selected = selectedChoiceID,
               selected != question.correctChoiceID,
               let correct = question.correctChoice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("quiz.feedback.incorrect")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(languageManager.localizedFormat("quiz.feedback.correct_answer", correct.text))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appearance.primaryColor)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }

            if let detail = question.detail,
               !(detail.isEmpty) {
                Divider()
                    .padding(.top, 4)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct QuizChoiceRow: View {
    let choice: QuizChoice
    let isSelected: Bool
    let isCorrect: Bool
    let revealCorrect: Bool
    let appearance: CategoryAppearance
    let onTap: () -> Void


    var body: some View {
        let colors = resolvedColors()
        let highlightCorrect = shouldHighlightCorrect
        let iconColor = highlightCorrect ? Color.green : colors.icon

        Button(action: {
            withAnimation(.none) {
                onTap()
            }
        }) {
            HStack(alignment: .center, spacing: 12) {
                Text(choice.text)
                    .font(.body)
                    .foregroundStyle(colors.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                if let iconName = colors.iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(backgroundView(colors: colors, highlightCorrect: highlightCorrect))
        .overlay(borderView(colors: colors, highlightCorrect: highlightCorrect))
        .buttonStyle(.plain)
        .animation(.none, value: isSelected)
        .animation(.none, value: revealCorrect)
    }

    private func resolvedColors() -> (background: Color, border: Color, text: Color, icon: Color, iconName: String?) {
        if isSelected && isCorrect {
            return (
                appearance.primaryColor.opacity(0.16),
                appearance.primaryColor.opacity(0.5),
                .primary,
                appearance.primaryColor,
                "checkmark.circle.fill"
            )
        }

        if isSelected && !isCorrect {
            return (
                Color.red.opacity(0.14),
                Color.red.opacity(0.35),
                .primary,
                Color.red,
                "xmark.circle.fill"
            )
        }

        if !isSelected && isCorrect && revealCorrect {
            return (
                appearance.primaryColor.opacity(0.1),
                appearance.primaryColor.opacity(0.4),
                .primary,
                appearance.primaryColor,
                "checkmark.circle.fill"
            )
        }

        return (
            Color(.systemBackground),
            Color.black.opacity(0.05),
            .primary,
            appearance.primaryColor,
            nil
        )
    }

    private var shouldHighlightCorrect: Bool {
        revealCorrect && isCorrect && !isSelected
    }

    @ViewBuilder
    private func backgroundView(colors: (background: Color, border: Color, text: Color, icon: Color, iconName: String?), highlightCorrect: Bool) -> some View {
        if highlightCorrect {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.green.opacity(0.18))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colors.background)
        }
    }

    private func borderView(colors: (background: Color, border: Color, text: Color, icon: Color, iconName: String?), highlightCorrect: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(highlightCorrect ? Color.green.opacity(0.55) : colors.border, lineWidth: 1)
    }
}

private struct QuizResultView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let category: QuizCategory
    let attempt: QuizAttempt
    let aggregate: QuizResult
    let appearance: CategoryAppearance
    let onRestart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                progressHeader

                resultCard

                statisticsSection

                Button(action: onRestart) {
                    Text("quiz.action.restart")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(appearance.primaryColor.opacity(0.2))
                        .foregroundStyle(appearance.primaryColor)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(languageManager.localizedFormat("quiz.progress_format", attempt.totalQuestions, attempt.totalQuestions))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

            ProgressView(value: Double(attempt.totalQuestions), total: Double(attempt.totalQuestions))
                .progressViewStyle(.linear)
                .tint(appearance.primaryColor)
        }
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            Image(systemName: resultIconName)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(appearance.primaryColor)

            Text(primaryMessage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            Text(languageManager.localizedFormat("quiz.result.summary_format", attempt.correctAnswers, attempt.totalQuestions))
            .font(.body)
            .foregroundStyle(.primary)

            Text(languageManager.localizedFormat("quiz.result.percentage_format", percentage * 100))
            .font(.callout.weight(.semibold))
            .foregroundStyle(appearance.primaryColor)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 6)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            statRow(
                title: languageManager.localizedString(for: "quiz.result.best_score"),
                value: languageManager.localizedFormat("quiz.result.best_score_value", aggregate.bestCorrectAnswers, aggregate.totalQuestions)
            )

            statRow(
                title: languageManager.localizedString(for: "quiz.result.average_time"),
                value: formattedAverageTime
            )

            statRow(
                title: languageManager.localizedString(for: "quiz.result.attempts"),
                value: "\(aggregate.attempts)"
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private var percentage: Double {
        guard attempt.totalQuestions > 0 else { return 0 }
        return Double(attempt.correctAnswers) / Double(attempt.totalQuestions)
    }

    private var formattedAverageTime: String {
        guard attempt.totalQuestions > 0 else {
            return "--"
        }
        let averageSeconds = attempt.totalDuration / Double(attempt.totalQuestions)
        return languageManager.localizedFormat("quiz.result.average_time_value", averageSeconds)
    }

    private var primaryMessage: String {
        switch percentage {
        case let value where value >= 0.99:
            return languageManager.localizedString(for: "quiz.result.message.perfect")
        case let value where value >= 0.75:
            return languageManager.localizedString(for: "quiz.result.message.great")
        default:
            return languageManager.localizedString(for: "quiz.result.message.keep_going")
        }
    }

    private var resultIconName: String {
        switch percentage {
        case let value where value >= 0.99:
            return "medal.fill"
        case let value where value >= 0.75:
            return "star.fill"
        default:
            return "sparkles"
        }
    }
}
