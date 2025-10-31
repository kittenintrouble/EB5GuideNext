import SwiftUI
import UIKit

struct ProjectDetailView: View {
    let projectID: String

    @EnvironmentObject private var projectsStore: ProjectsStore
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var imageLoader: ProjectImageLoadingCoordinator

    @State private var isLoading = false
    @State private var errorMessage: String?

    private var project: Project? {
        projectsStore.project(withID: projectID)
    }

    private var isFavorite: Bool {
        projectsStore.isFavorite(id: projectID)
    }

    private var languageIdentifier: String {
        languageManager.currentLocale.identifier
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let project {
                    ProjectDetailContent(project: project)
                        .environmentObject(languageManager)
                        .environmentObject(projectsStore)
                        .environmentObject(imageLoader)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 60)
                } else if let errorMessage {
                    ProjectDetailErrorView(
                        message: errorMessage,
                        retry: {
                            Task { await loadDetail(force: true) }
                        }
                    )
                    .padding(.top, 60)
                } else {
                    Text(languageManager.localizedString(for: "projects.error.not_found"))
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(project?.title ?? languageManager.localizedString(for: "projects.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        projectsStore.toggleFavorite(id: projectID)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? Color.red : Color.primary)
                }
                .accessibilityLabel(Text(languageManager.localizedString(for: isFavorite ? "projects.favorite.remove" : "projects.favorite.add")))
            }
        }
        .task(id: cacheKey) {
            await loadDetail(force: false)
        }
        .refreshable {
            await loadDetail(force: true)
        }
        .onAppear {
            updateDetailImageLoading()
        }
        .onDisappear {
            imageLoader.pauseDetail(for: projectID)
        }
        .onChange(of: project) { _ in
            updateDetailImageLoading()
        }
    }

    private var cacheKey: String {
        "\(projectID)-\(languageIdentifier)"
    }

    private func loadDetail(force: Bool) async {
        guard !isLoading || force else { return }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await projectsStore.fetchProjectDetail(
                id: projectID,
                language: languageIdentifier,
                force: force
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func updateDetailImageLoading() {
        let urls = project?.images.map { $0.url } ?? []
        if urls.isEmpty {
            imageLoader.pauseDetail(for: projectID)
        } else {
            imageLoader.activateDetail(projectID: projectID, urls: urls)
        }
    }
}

private struct ProjectDetailContent: View {
    let project: Project

    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var imageLoader: ProjectImageLoadingCoordinator
    @State private var currentImageIndex = 0
    @State private var isGalleryPresented = false

    private var locale: Locale {
        languageManager.currentLocale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !project.images.isEmpty {
                ProjectImageCarousel(
                    images: project.images,
                    currentIndex: $currentImageIndex,
                    onImageTapped: { isGalleryPresented = true }
                )
                .fullScreenCover(isPresented: $isGalleryPresented) {
                    ProjectImageGalleryFullScreen(
                        images: project.images,
                        currentIndex: $currentImageIndex
                    )
                    .environmentObject(imageLoader)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(project.displayTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 8) {
                    Label(project.location, systemImage: "mappin.circle.fill")
                        .foregroundStyle(Color.blue)
                        .font(.subheadline)
                        .lineLimit(2)

                    if let status = project.statusEnum {
                        StatusBadge(
                            value: status.localizedName,
                            tint: status.color
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)

            ProjectKeyFactsView(project: project)
                .padding(.horizontal, 20)

            if !financialRows.isEmpty {
                ProjectInfoSection(
                    title: languageManager.localizedString(for: "projects.financial_overview"),
                    iconName: "chart.bar.fill"
                ) {
                    ForEach(Array(financialRows.enumerated()), id: \.offset) { _, row in
                        InfoRow(label: row.label, value: row.value, highlight: row.highlight)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !uscisRows.isEmpty {
                ProjectInfoSection(
                    title: languageManager.localizedString(for: "projects.uscis_status"),
                    iconName: "building.columns.fill"
                ) {
                    ForEach(Array(uscisRows.enumerated()), id: \.offset) { _, row in
                        InfoRow(label: row.label, value: row.value, highlight: row.highlight)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !teaRows.isEmpty {
                ProjectInfoSection(
                    title: languageManager.localizedString(for: "projects.tea_label"),
                    iconName: "leaf.fill"
                ) {
                    ForEach(Array(teaRows.enumerated()), id: \.offset) { _, row in
                        InfoRow(label: row.label, value: row.value, highlight: row.highlight)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !loanRows.isEmpty {
                ProjectInfoSection(
                    title: languageManager.localizedString(for: "projects.loan_structure"),
                    iconName: "doc.text.fill"
                ) {
                    ForEach(Array(loanRows.enumerated()), id: \.offset) { _, row in
                        InfoRow(label: row.label, value: row.value, highlight: row.highlight)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !jobRows.isEmpty {
                ProjectInfoSection(
                    title: languageManager.localizedString(for: "projects.job_creation"),
                    iconName: "person.3.fill"
                ) {
                    ForEach(Array(jobRows.enumerated()), id: \.offset) { _, row in
                        InfoRow(label: row.label, value: row.value, highlight: row.highlight)
                    }
                }
                .padding(.horizontal, 20)
            }

            if let description = project.fullDescription.nonEmpty {
                SectionHeader(
                    title: languageManager.localizedString(for: "projects.detail.description"),
                    iconName: "text.alignleft"
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
            }

            ProjectInquiryForm(project: project)
                .padding(.horizontal, 20)
        }
        .onChange(of: project.images) { newImages in
            let maxIndex = max(0, newImages.count - 1)
            currentImageIndex = min(currentImageIndex, maxIndex)
        }
    }

    private func formattedPerInvestor(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formattedTerm(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private typealias InfoRowEntry = (label: String, value: String, highlight: Bool)

    private var financialRows: [InfoRowEntry] {
        var rows: [InfoRowEntry] = []
        if let total = project.financials.totalProjectDisplay.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.financial.total_project"),
                total,
                false
            ))
        }
        if let offering = project.financials.eb5OfferingDisplay.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.eb5_offering"),
                offering,
                false
            ))
        }
        if let minimum = project.financials.minInvestmentDisplay.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.min_investments"),
                minimum,
                true
            ))
        }
        if let investors = project.financials.eb5Investors.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.financial.eb5_investors"),
                investors,
                false
            ))
        }
        return rows
    }

    private var uscisRows: [InfoRowEntry] {
        var rows: [InfoRowEntry] = []
        if let filingDate = project.uscis.i956fFilingDate?.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.uscis.i956f_filing_date"),
                filingDate,
                false
            ))
        }
        if let approvalDate = project.uscis.i956fApprovalDate?.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.uscis.i956f_approval_date"),
                approvalDate,
                false
            ))
        }
        if let i956StatusRaw = project.uscis.i956fStatus?.nonEmpty {
            let localized = I956FStatus(rawValue: i956StatusRaw)?.localizedName ?? i956StatusRaw
            rows.append(("I-956F", localized, false))
        }
        if let i526StatusRaw = project.uscis.i526eStatus?.nonEmpty {
            let localized = I526EStatus(rawValue: i526StatusRaw)?.localizedName ?? i526StatusRaw
            rows.append(("I-526E", localized, false))
        }
        return rows
    }

    private var teaRows: [InfoRowEntry] {
        var rows: [InfoRowEntry] = []
        let teaTypeRaw = TEAType(rawValue: project.tea.type)?.localizedName ?? project.tea.type
        if let typeValue = teaTypeRaw.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.tea.type"),
                typeValue,
                false
            ))
        }
        if let designation = project.tea.designation?.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.tea.designation"),
                designation,
                false
            ))
        }
        return rows
    }

    private var loanRows: [InfoRowEntry] {
        var rows: [InfoRowEntry] = []

        let loanTypeRaw = LoanType(rawValue: project.loanStructure.type)?.localizedName ?? project.loanStructure.type
        if let typeValue = loanTypeRaw.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.loan_type"),
                typeValue,
                false
            ))
        }

        if let interest = project.loanStructure.annualReturnDisplay.nonEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.interest"),
                interest,
                false
            ))
        }

        if let termYears = project.loanStructure.termYears {
            let formatted = formattedTerm(termYears)
            let suffix = languageManager.localizedString(for: "projects.years")
            rows.append((
                languageManager.localizedString(for: "projects.term"),
                "\(formatted) \(suffix)",
                false
            ))
        }

        let escrowLabelKey = project.loanStructure.escrow ? "common.yes" : "common.no"
        if project.loanStructure.escrow || !rows.isEmpty {
            rows.append((
                languageManager.localizedString(for: "projects.escrow"),
                languageManager.localizedString(for: escrowLabelKey),
                false
            ))
        }

        return rows
    }

    private var jobRows: [InfoRowEntry] {
        var rows: [InfoRowEntry] = []
        if project.jobs.total > 0 {
            rows.append((
                languageManager.localizedString(for: "projects.jobs.total"),
                "\(project.jobs.total)",
                false
            ))
        }
        if project.jobs.perInvestor > 0 {
            rows.append((
                languageManager.localizedString(for: "projects.jobs.per_investor"),
                formattedPerInvestor(project.jobs.perInvestor),
                false
            ))
        }
        return rows
    }
}

private struct ProjectImageCarousel: View {
    let images: [ProjectImage]
    @Binding var currentIndex: Int
    var onImageTapped: (() -> Void)?
    @EnvironmentObject private var imageLoader: ProjectImageLoadingCoordinator

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        carouselItem(for: image)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 20)
                .onTapGesture {
                    onImageTapped?()
                }

                if images.count > 1 {
                    indicator
                        .padding(.bottom, 24)
                }
            }

            if images.indices.contains(currentIndex),
               let caption = images[currentIndex].caption?.nonEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func carouselItem(for image: ProjectImage) -> some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                if let loaded = imageLoader.image(for: image.url) {
                    Image(uiImage: loaded)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
        }
        .frame(height: 300)
    }

    private var indicator: some View {
        HStack(spacing: 8) {
            ForEach(images.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == currentIndex ? 24 : 8, height: 8)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35), in: Capsule())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
    }
}

private struct ProjectImageGalleryFullScreen: View {
    let images: [ProjectImage]
    @Binding var currentIndex: Int
    @EnvironmentObject private var imageLoader: ProjectImageLoadingCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    galleryItem(for: image)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .padding(.top, 40)
            .padding(.trailing, 24)
        }
        .overlay(alignment: .bottom) {
            if images.count > 1 {
                HStack(spacing: 8) {
                    ForEach(images.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: index == currentIndex ? 32 : 10, height: 10)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.45), in: Capsule())
                .padding(.bottom, 32)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func galleryItem(for image: ProjectImage) -> some View {
        ZStack {
            Color.black

            if let loaded = imageLoader.image(for: image.url) {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .ignoresSafeArea()
    }
}

private struct StatusBadge: View {
    let value: String
    let tint: Color

    var body: some View {
        Text(value)
            .font(.footnote)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct ProjectKeyFactsView: View {
    let project: Project
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasAnyFacts {
                SectionHeader(
                    title: languageManager.localizedString(for: "projects.detail.key_information"),
                    iconName: "info.circle.fill"
                )

                VStack(alignment: .leading, spacing: 12) {
                    if let type = typeDisplay {
                        InfoRow(
                            label: languageManager.localizedString(for: "projects.detail.project_type"),
                            value: type
                        )
                    }

                    if let developer = project.developer.nonEmpty {
                        InfoRow(
                            label: languageManager.localizedString(for: "projects.detail.developer"),
                            value: developer
                        )
                    }

                    if let expected = project.expectedOpening.nonEmpty {
                        InfoRow(
                            label: languageManager.localizedString(for: "projects.detail.expected_opening"),
                            value: expected
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                )
            }
        }
    }

    private var typeDisplay: String? {
        let base = project.typeEnum?.localizedName ?? project.type
        return base.nonEmpty
    }

    private var hasAnyFacts: Bool {
        typeDisplay != nil
            || project.developer.nonEmpty != nil
            || project.expectedOpening.nonEmpty != nil
    }
}

private struct ProjectInfoSection<Content: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, iconName: iconName)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(highlight ? .bold : .medium)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.primary)
        }
    }
}

private struct ProjectDetailErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                Label("common.retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(.horizontal, 32)
    }
}

private struct ProjectInquiryForm: View {
    let project: Project

    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var projectsStore: ProjectsStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var countryOfBirth = ""
    @State private var currentCountry = ""
    @State private var selectedVisaStatus: VisaStatus?
    @State private var isAccredited = false

    @State private var firstNameError: String?
    @State private var lastNameError: String?
    @State private var emailError: String?
    @State private var phoneError: String?
    @State private var birthCountryError: String?
    @State private var currentCountryError: String?
    @State private var visaStatusError: String?
    @State private var accreditedError: String?
    @State private var submissionError: String?
    @State private var submissionSuccessMessage: String?
    @State private var isSubmitting = false
    @State private var showValidation = false
    @State private var showConsentSheet = false

    private var isFormValid: Bool {
        validateFirstName()
        validateLastName()
        validateEmail()
        validatePhone()
        validateCountryOfBirth()
        validateCurrentCountry()
        validateVisaStatus()
        validateAccredited()
        return [
            firstNameError,
            lastNameError,
            emailError,
            phoneError,
            birthCountryError,
            currentCountryError,
            visaStatusError,
            accreditedError
        ].allSatisfy { $0 == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }

                Text(languageManager.localizedString(for: "projects.inquiry.header"))
                    .font(.title3)
                    .fontWeight(.bold)
            }

            if let success = submissionSuccessMessage {
                SuccessBanner(message: success)
            } else {
                if let error = submissionError {
                    ErrorBanner(message: error)
                }

                VStack(alignment: .leading, spacing: 14) {
                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.first_name"),
                        text: $firstName,
                        error: $firstNameError,
                        placeholder: languageManager.localizedString(for: "projects.form.first_name.placeholder"),
                        textContentType: .givenName,
                        autocapitalization: .words,
                        onEditingChanged: { _ in if showValidation { validateFirstName() } }
                    )

                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.last_name"),
                        text: $lastName,
                        error: $lastNameError,
                        placeholder: languageManager.localizedString(for: "projects.form.last_name.placeholder"),
                        textContentType: .familyName,
                        autocapitalization: .words,
                        onEditingChanged: { _ in if showValidation { validateLastName() } }
                    )

                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.email"),
                        text: $email,
                        error: $emailError,
                        placeholder: languageManager.localizedString(for: "projects.form.email.placeholder"),
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never,
                        disableAutocorrection: true,
                        onEditingChanged: { _ in if showValidation { validateEmail() } }
                    )

                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.phone"),
                        text: $phoneNumber,
                        error: $phoneError,
                        placeholder: languageManager.localizedString(for: "projects.form.phone.placeholder"),
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber,
                        onEditingChanged: { _ in if showValidation { validatePhone() } }
                    )

                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.country_birth"),
                        text: $countryOfBirth,
                        error: $birthCountryError,
                        placeholder: languageManager.localizedString(for: "projects.form.country_birth.placeholder"),
                        autocapitalization: .words,
                        onEditingChanged: { _ in if showValidation { validateCountryOfBirth() } }
                    )

                    LabeledInput(
                        title: languageManager.localizedString(for: "projects.form.current_country"),
                        text: $currentCountry,
                        error: $currentCountryError,
                        placeholder: languageManager.localizedString(for: "projects.form.current_country.placeholder"),
                        autocapitalization: .words,
                        onEditingChanged: { _ in if showValidation { validateCurrentCountry() } }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(languageManager.localizedString(for: "projects.form.visa_status"))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Menu {
                            ForEach(VisaStatus.allCases) { status in
                                Button(action: {
                                    selectedVisaStatus = status
                                    if showValidation { validateVisaStatus() }
                                }) {
                                    HStack {
                                        Text(status.localizedName)
                                        if status == selectedVisaStatus {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedVisaStatus?.localizedName
                                     ?? languageManager.localizedString(for: "projects.form.visa.placeholder"))
                                    .foregroundColor(selectedVisaStatus == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.quaternaryLabel), lineWidth: 1)
                            )
                        }

                        if let visaStatusError {
                            ValidationText(message: visaStatusError)
                        }
                    }

                    AccreditationToggle(
                        isOn: $isAccredited,
                        onInfoTap: { showConsentSheet = true },
                        onToggle: { _ in
                            if showValidation { validateAccredited() }
                        }
                    ) {
                        accreditationText
                    }

                    if let accreditedError {
                        ValidationText(message: accreditedError)
                    }
                }

                Button {
                    submit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Text(languageManager.localizedString(for: "projects.form.submit"))
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .disabled(isSubmitting)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
        .sheet(isPresented: $showConsentSheet) {
            ConsentNoticeView()
                .environmentObject(languageManager)
        }
    }

    private func submit() {
        showValidation = true
        guard isFormValid else { return }
        guard let visaStatus = selectedVisaStatus else { return }

        submissionError = nil
        isSubmitting = true

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBirth = countryOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrent = currentCountry.trimmingCharacters(in: .whitespacesAndNewlines)

        let inquiry = ProjectInquiry(
            projectId: project.id,
            projectTitle: project.displayTitle,
            firstName: trimmedFirst,
            lastName: trimmedLast,
            email: trimmedEmail,
            phone: trimmedPhone,
            countryOfBirth: trimmedBirth,
            countryOfLiving: trimmedCurrent,
            currentVisaStatus: visaStatus.apiValue,
            accreditedInvestor: isAccredited,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )

        Task {
            do {
                let response = try await projectsStore.submitInquiry(inquiry)
                await MainActor.run {
                    isSubmitting = false
                    if response.success {
                        submissionSuccessMessage = response.message ?? languageManager.localizedString(for: "projects.inquiry.success")
                    } else {
                        submissionError = response.error ?? languageManager.localizedString(for: "projects.inquiry.error.generic")
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submissionError = error.localizedDescription
                }
            }
        }
    }

    @discardableResult
    private func validateFirstName() -> Bool {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            firstNameError = languageManager.localizedString(for: "projects.form.validation.first_name")
            return false
        }
        firstNameError = nil
        return true
    }

    @discardableResult
    private func validateLastName() -> Bool {
        let trimmed = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 2 {
            lastNameError = languageManager.localizedString(for: "projects.form.validation.last_name")
            return false
        }
        lastNameError = nil
        return true
    }

    @discardableResult
    private func validateEmail() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        if !predicate.evaluate(with: trimmed) {
            emailError = languageManager.localizedString(for: "projects.form.validation.email")
            return false
        }
        emailError = nil
        return true
    }

    @discardableResult
    private func validatePhone() -> Bool {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter { $0.isNumber }
        if trimmed.isEmpty || digits.count < 5 || !trimmed.hasPrefix("+") {
            phoneError = languageManager.localizedString(for: "projects.form.validation.phone")
            return false
        }
        phoneError = nil
        return true
    }

    @discardableResult
    private func validateCountryOfBirth() -> Bool {
        let trimmed = countryOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            birthCountryError = languageManager.localizedString(for: "projects.form.validation.country_birth")
            return false
        }
        birthCountryError = nil
        return true
    }

    @discardableResult
    private func validateCurrentCountry() -> Bool {
        let trimmed = currentCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            currentCountryError = languageManager.localizedString(for: "projects.form.validation.current_country")
            return false
        }
        currentCountryError = nil
        return true
    }

    @discardableResult
    private func validateVisaStatus() -> Bool {
        if selectedVisaStatus == nil {
            visaStatusError = languageManager.localizedString(for: "projects.form.validation.visa")
            return false
        }
        visaStatusError = nil
        return true
    }

    @discardableResult
    private func validateAccredited() -> Bool {
        if !isAccredited {
            accreditedError = languageManager.localizedString(for: "projects.form.validation.accredited")
            return false
        }
        accreditedError = nil
        return true
    }

    private var accreditationText: some View {
        let baseText = languageManager.localizedString(for: "projects.form.accredited.prefix")
        let linkText = languageManager.localizedString(for: "projects.form.accredited.link")

        return (
            Text(baseText + " ")
                .foregroundColor(.primary)
            + Text(linkText)
                .foregroundColor(.accentColor)
                .underline()
        )
        .font(.subheadline)
    }
}

private enum VisaStatus: CaseIterable, Identifiable {
    case citizen
    case greenCard
    case visaE2
    case visaH1B
    case visaL1
    case visaF1
    case visaOther
    case noVisa

    var id: String { apiValue }

    var apiValue: String {
        switch self {
        case .citizen: return "U.S. Citizen"
        case .greenCard: return "U.S. Green Card"
        case .visaE2: return "Visa: E-2"
        case .visaH1B: return "Visa: H-1B"
        case .visaL1: return "Visa: L-1"
        case .visaF1: return "Visa: F-1"
        case .visaOther: return "Visa: Other"
        case .noVisa: return "No U.S. Visa"
        }
    }

    private var localizationKey: String {
        switch self {
        case .citizen: return "projects.form.visa.citizen"
        case .greenCard: return "projects.form.visa.greenCard"
        case .visaE2: return "projects.form.visa.visaE2"
        case .visaH1B: return "projects.form.visa.visaH1B"
        case .visaL1: return "projects.form.visa.visaL1"
        case .visaF1: return "projects.form.visa.visaF1"
        case .visaOther: return "projects.form.visa.visaOther"
        case .noVisa: return "projects.form.visa.noVisa"
        }
    }

    var localizedName: String {
        NSLocalizedString(localizationKey, comment: "")
    }
}

private struct ConsentNoticeView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    private let sections = ConsentSection.allSections

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(languageManager.localizedString(for: "projects.form.consent.intro"))
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(section.id).")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)

                                Text(languageManager.localizedString(for: section.titleKey))
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }

                            Text(languageManager.localizedString(for: section.bodyKey))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(LocalizedStringKey("projects.form.consent.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text(LocalizedStringKey("common.done"))
                    }
                }
            }
        }
    }
}

private struct ConsentSection: Identifiable {
    let id: Int
    let titleKey: String
    let bodyKey: String

    static let allSections: [ConsentSection] = [
        ConsentSection(id: 1, titleKey: "projects.form.consent.section1.title", bodyKey: "projects.form.consent.section1.body"),
        ConsentSection(id: 2, titleKey: "projects.form.consent.section2.title", bodyKey: "projects.form.consent.section2.body"),
        ConsentSection(id: 3, titleKey: "projects.form.consent.section3.title", bodyKey: "projects.form.consent.section3.body"),
        ConsentSection(id: 4, titleKey: "projects.form.consent.section4.title", bodyKey: "projects.form.consent.section4.body"),
        ConsentSection(id: 5, titleKey: "projects.form.consent.section5.title", bodyKey: "projects.form.consent.section5.body"),
        ConsentSection(id: 6, titleKey: "projects.form.consent.section6.title", bodyKey: "projects.form.consent.section6.body"),
        ConsentSection(id: 7, titleKey: "projects.form.consent.section7.title", bodyKey: "projects.form.consent.section7.body"),
        ConsentSection(id: 8, titleKey: "projects.form.consent.section8.title", bodyKey: "projects.form.consent.section8.body"),
        ConsentSection(id: 9, titleKey: "projects.form.consent.section9.title", bodyKey: "projects.form.consent.section9.body"),
        ConsentSection(id: 10, titleKey: "projects.form.consent.section10.title", bodyKey: "projects.form.consent.section10.body")
    ]
}

private struct LabeledInput: View {
    let title: String
    @Binding var text: String
    @Binding var error: String?
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization? = nil
    var disableAutocorrection: Bool? = nil
    var onEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ZStack(alignment: .leading) {
                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text, onEditingChanged: onEditingChanged)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .optionalAutocapitalization(autocapitalization)
                    .optionalAutocorrectionDisabled(disableAutocorrection)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.quaternaryLabel), lineWidth: 1)
            )

            if let error {
                ValidationText(message: error)
            }
        }
    }
}

private struct ValidationText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Color.red)
    }
}

private struct AccreditationToggle<Label: View>: View {
    @Binding var isOn: Bool
    let onInfoTap: () -> Void
    let onToggle: (Bool) -> Void
    let label: Label

    init(
        isOn: Binding<Bool>,
        onInfoTap: @escaping () -> Void,
        onToggle: @escaping (Bool) -> Void,
        @ViewBuilder label: () -> Label
    ) {
        _isOn = isOn
        self.onInfoTap = onInfoTap
        self.onToggle = onToggle
        self.label = label()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
                onToggle(isOn)
            } label: {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOn ? Color.green : Color(.systemGray5))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: isOn ? "checkmark" : "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isOn ? .white : Color(.systemGray))
                    )
            }
            .buttonStyle(.plain)

            Button(action: onInfoTap) {
                VStack(alignment: .leading, spacing: 0) {
                    label
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func optionalAutocapitalization(_ style: TextInputAutocapitalization?) -> some View {
        if let style {
            textInputAutocapitalization(style)
        } else {
            self
        }
    }

    @ViewBuilder
    func optionalAutocorrectionDisabled(_ disabled: Bool?) -> some View {
        if let disabled {
            autocorrectionDisabled(disabled)
        } else {
            self
        }
    }
}

private struct SuccessBanner: View {
    let message: String
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(languageManager.localizedString(for: "projects.inquiry.followup"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.18), Color.green.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 12)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.22), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
