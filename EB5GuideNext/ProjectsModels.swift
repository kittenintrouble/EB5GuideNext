import Foundation
import SwiftUI

fileprivate func normalizedLookupKey(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "" }
    let replaced = trimmed
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
    let components = replaced
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
    let joined = components.joined(separator: " ")
    let locale = Locale(identifier: "en_US_POSIX")
    return joined.folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: locale)
}

struct ProjectsResponse: Codable {
    let dataVersion: String?
    let items: [Project]
    let total: Int
    let offset: Int
    let limit: Int
    let nextOffset: Int?

    enum CodingKeys: String, CodingKey {
        case dataVersion = "data_version"
        case items
        case total
        case offset
        case limit
        case nextOffset = "next_offset"
    }

    init(
        dataVersion: String? = nil,
        items: [Project] = [],
        total: Int = 0,
        offset: Int = 0,
        limit: Int = 0,
        nextOffset: Int? = nil
    ) {
        self.dataVersion = dataVersion
        self.items = items
        self.total = total
        self.offset = offset
        self.limit = limit
        self.nextOffset = nextOffset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataVersion = try container.decodeIfPresent(String.self, forKey: .dataVersion)
        items = (try? container.decode([Project].self, forKey: .items)) ?? []
        total = container.decodeIfPresentFlexibleInt(forKey: .total) ?? items.count
        offset = container.decodeIfPresentFlexibleInt(forKey: .offset) ?? 0
        limit = container.decodeIfPresentFlexibleInt(forKey: .limit) ?? items.count
        nextOffset = container.decodeIfPresentFlexibleInt(forKey: .nextOffset)
    }
}

struct Project: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let name: String?
    let slug: String?
    let shortDescription: String
    let fullDescription: String
    let location: String
    let type: String
    let status: String
    let developer: String
    let expectedOpening: String
    let images: [ProjectImage]
    let financials: Financials
    let uscis: USCIS
    let tea: TEA
    let jobs: Jobs
    let loanStructure: LoanStructure
    let published: Bool
    let publishedAt: String?

    var typeEnum: ProjectType? { ProjectType(apiValue: type) }
    var statusEnum: ProjectStatus? { ProjectStatus(apiValue: status) }
    var displayTitle: String {
        if let display = title.trimmedNonEmpty { return display }
        if let name = name?.trimmedNonEmpty {
            return name
        }
        if let slug = slug?.trimmedNonEmpty {
            return slug
        }
        return id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case slug
        case shortDescription
        case fullDescription
        case location
        case type
        case status
        case developer
        case expectedOpening
        case images
        case financials
        case uscis
        case tea
        case jobs
        case loanStructure
        case published
        case publishedAt
    }

    init(
        id: String,
        title: String,
        name: String?,
        slug: String?,
        shortDescription: String,
        fullDescription: String,
        location: String,
        type: String,
        status: String,
        developer: String,
        expectedOpening: String,
        images: [ProjectImage],
        financials: Financials,
        uscis: USCIS,
        tea: TEA,
        jobs: Jobs,
        loanStructure: LoanStructure,
        published: Bool,
        publishedAt: String?
    ) {
        self.id = id
        self.title = title
        self.name = name
        self.slug = slug
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.location = location
        self.type = type
        self.status = status
        self.developer = developer
        self.expectedOpening = expectedOpening
        self.images = images
        self.financials = financials
        self.uscis = uscis
        self.tea = tea
        self.jobs = jobs
        self.loanStructure = loanStructure
        self.published = published
        self.publishedAt = publishedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        name = try? container.decode(String.self, forKey: .name)
        slug = try? container.decode(String.self, forKey: .slug)
        shortDescription = (try? container.decode(String.self, forKey: .shortDescription)) ?? ""
        fullDescription = (try? container.decode(String.self, forKey: .fullDescription)) ?? ""
        location = (try? container.decode(String.self, forKey: .location)) ?? ""
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        status = (try? container.decode(String.self, forKey: .status)) ?? ""
        developer = (try? container.decode(String.self, forKey: .developer)) ?? ""
        expectedOpening = (try? container.decode(String.self, forKey: .expectedOpening)) ?? ""
        images = (try? container.decode([ProjectImage].self, forKey: .images)) ?? []
        financials = (try? container.decode(Financials.self, forKey: .financials)) ?? Financials()
        uscis = (try? container.decode(USCIS.self, forKey: .uscis)) ?? USCIS()
        tea = (try? container.decode(TEA.self, forKey: .tea)) ?? TEA()
        jobs = (try? container.decode(Jobs.self, forKey: .jobs)) ?? Jobs()
        loanStructure = (try? container.decode(LoanStructure.self, forKey: .loanStructure)) ?? LoanStructure()
        published = (try? container.decode(Bool.self, forKey: .published)) ?? true
        publishedAt = try? container.decode(String.self, forKey: .publishedAt)
    }
}

struct ProjectImage: Codable, Identifiable, Equatable {
    var id: String { url }
    let url: String
    let alt: String
    let caption: String?

    init(url: String, alt: String, caption: String?) {
        self.url = url
        self.alt = alt
        self.caption = caption
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let stringValue = try? singleValue.decode(String.self) {
            self.url = stringValue
            self.alt = ""
            self.caption = nil
        } else {
            let keyed = try decoder.container(keyedBy: CodingKeys.self)
            url = (try? keyed.decode(String.self, forKey: .url)) ?? ""
            alt = (try? keyed.decode(String.self, forKey: .alt)) ?? ""
            caption = try? keyed.decode(String.self, forKey: .caption)
        }
    }

    enum CodingKeys: String, CodingKey {
        case url
        case alt
        case caption
    }
}

struct Financials: Codable, Equatable {
    let totalProject: String
    let eb5Offering: String
    let minInvestment: String
    let eb5Investors: String

    var totalProjectDisplay: String { Financials.formatCurrency(totalProject) }
    var eb5OfferingDisplay: String { Financials.formatCurrency(eb5Offering) }
    var minInvestmentDisplay: String { Financials.formatCurrency(minInvestment) }

    private static func formatCurrency(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        let cleaned = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        if let number = Double(cleaned) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            formatter.currencySymbol = "$"
            return formatter.string(from: NSNumber(value: number)) ?? trimmed
        }
        return trimmed
    }

    init(
        totalProject: String = "",
        eb5Offering: String = "",
        minInvestment: String = "",
        eb5Investors: String = ""
    ) {
        self.totalProject = totalProject
        self.eb5Offering = eb5Offering
        self.minInvestment = minInvestment
        self.eb5Investors = eb5Investors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalProject = container.decodeIfPresentAsString(forKey: .totalProject) ?? ""
        eb5Offering = container.decodeIfPresentAsString(forKey: .eb5Offering) ?? ""
        minInvestment = container.decodeIfPresentAsString(forKey: .minInvestment) ?? ""
        eb5Investors = container.decodeIfPresentAsString(forKey: .eb5Investors) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case totalProject
        case eb5Offering
        case minInvestment
        case eb5Investors
    }
}

struct USCIS: Codable, Equatable {
    let i956fStatus: String?
    let i956fFilingDate: String?
    let i956fApprovalDate: String?
    let i526eStatus: String?

    init(
        i956fStatus: String? = nil,
        i956fFilingDate: String? = nil,
        i956fApprovalDate: String? = nil,
        i526eStatus: String? = nil
    ) {
        self.i956fStatus = i956fStatus
        self.i956fFilingDate = i956fFilingDate
        self.i956fApprovalDate = i956fApprovalDate
        self.i526eStatus = i526eStatus
    }
}

struct TEA: Codable, Equatable {
    let type: String
    let designation: String?

    init(type: String = "", designation: String? = nil) {
        self.type = type
        self.designation = designation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type))
            ?? container.decodeIfPresentAsString(forKey: .type)
            ?? ""
        designation = container.decodeIfPresentAsString(forKey: .designation)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case designation
    }
}

struct Jobs: Codable, Equatable {
    let total: Int
    let perInvestor: Double

    init(total: Int = 0, perInvestor: Double = 0) {
        self.total = total
        self.perInvestor = perInvestor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0

        if let doubleValue = try? container.decode(Double.self, forKey: .perInvestor) {
            perInvestor = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .perInvestor),
                  let parsed = Double(stringValue) {
            perInvestor = parsed
        } else {
            perInvestor = 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case total
        case perInvestor
    }
}

struct LoanStructure: Codable, Equatable {
    let type: String
    let annualReturn: String
    let termYears: Double?
    let escrow: Bool

    var annualReturnDisplay: String {
        let trimmed = annualReturn.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        if let value = Double(trimmed.replacingOccurrences(of: "%", with: "")) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
        }
        return trimmed
    }

    init(
        type: String = "",
        annualReturn: String = "",
        termYears: Double? = nil,
        escrow: Bool = false
    ) {
        self.type = type
        self.annualReturn = annualReturn
        self.termYears = termYears
        self.escrow = escrow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        annualReturn = container.decodeIfPresentAsString(forKey: .annualReturn) ?? ""
        if let doubleValue = try? container.decode(Double.self, forKey: .termYears) {
            termYears = doubleValue
        } else if let stringValue = try? container.decode(String.self, forKey: .termYears),
                  let parsed = Double(stringValue) {
            termYears = parsed
        } else {
            termYears = nil
        }

        if let boolValue = try? container.decode(Bool.self, forKey: .escrow) {
            escrow = boolValue
        } else if let stringValue = try? container.decode(String.self, forKey: .escrow) {
            escrow = (stringValue as NSString).boolValue
        } else {
            escrow = false
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case annualReturn
        case termYears
        case escrow
    }
}

private extension String {
    var trimmedOrEmpty: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var trimmedNonEmpty: String? {
        let trimmed = trimmedOrEmpty
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ProjectInquiry: Codable, Equatable {
    let projectId: String
    let projectTitle: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let countryOfBirth: String
    let countryOfLiving: String
    let currentVisaStatus: String
    let accreditedInvestor: Bool
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectTitle = "project_title"
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phone
        case countryOfBirth = "country_of_birth"
        case countryOfLiving = "country_of_living"
        case currentVisaStatus = "current_visa_status"
        case accreditedInvestor = "accredited_investor"
        case timestamp
    }
}

struct InquiryResponse: Codable, Equatable {
    let success: Bool
    let message: String?
    let inquiryId: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case inquiryId = "inquiry_id"
        case error
    }
}

enum ProjectStatus: String, CaseIterable {
    case planning = "Planning"
    case underConstruction = "Under Construction"
    case completed = "Completed"

    var localizationKey: String { "project.status.\(rawValue)" }

    var color: Color {
        switch self {
        case .planning:
            return Color(red: 0.55, green: 0.36, blue: 0.98)
        case .underConstruction:
            return Color(.systemGreen)
        case .completed:
            return Color(red: 0.6, green: 0.19, blue: 0.25)
        }
    }

    init?(apiValue: String) {
        let normalized = ProjectStatus.normalize(apiValue)
        if let match = ProjectStatus.localizedLookup[normalized] {
            self = match
            return
        }
        if ProjectStatus.matchesPlanning(normalized) {
            self = .planning
            return
        }
        if ProjectStatus.matchesUnderConstruction(normalized) {
            self = .underConstruction
            return
        }
        if ProjectStatus.matchesCompleted(normalized) {
            self = .completed
            return
        }
        return nil
    }

    private static let localizedLookup: [String: ProjectStatus] = {
        var mapping: [String: ProjectStatus] = [:]

        func register(_ value: String, status: ProjectStatus) {
            let key = normalize(value)
            guard !key.isEmpty else { return }
            mapping[key] = status
        }

        let bundles: [Bundle] = {
            var result: [Bundle] = [Bundle.main]
            let codes = LanguageManager.supportedLanguageCodes

            for code in codes {
                if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    result.append(bundle)
                }
            }

            if let basePath = Bundle.main.path(forResource: "Base", ofType: "lproj"),
               let baseBundle = Bundle(path: basePath) {
                result.append(baseBundle)
            }

            return result
        }()

        for status in ProjectStatus.allCases {
            register(status.rawValue, status: status)
            register(status.rawValue.lowercased(), status: status)

            let localizationKey = status.localizationKey
            for bundle in bundles {
                let localized = bundle.localizedString(forKey: localizationKey, value: nil, table: nil)
                if localized != localizationKey {
                    register(localized, status: status)
                }
            }
        }

        let manualMappings: [(String, ProjectStatus)] = [
            ("规划阶段", .planning),
            ("计划阶段", .planning),
            ("Đang quy hoạch", .planning),
            ("계획 단계", .planning),
            ("建设中", .underConstruction),
            ("施工中", .underConstruction),
            ("Đang xây dựng", .underConstruction),
            ("공사 중", .underConstruction),
            ("已完成", .completed),
            ("完工", .completed),
            ("Đã hoàn thành", .completed),
            ("완료", .completed)
        ]

        for (value, status) in manualMappings {
            register(value, status: status)
        }

        return mapping
    }()

    private static func normalize(_ value: String) -> String {
        normalizedLookupKey(value)
    }

    private static func matchesPlanning(_ normalized: String) -> Bool {
        guard !normalized.isEmpty else { return false }
        if normalized.contains("plan") { return true }
        return false
    }

    private static func matchesUnderConstruction(_ normalized: String) -> Bool {
        guard !normalized.isEmpty else { return false }
        if normalized.contains("construct") { return true }
        if normalized.contains("build") { return true }
        return false
    }

    private static func matchesCompleted(_ normalized: String) -> Bool {
        guard !normalized.isEmpty else { return false }
        if normalized.contains("complete") { return true }
        if normalized.contains("finish") { return true }
        if normalized.contains("done") { return true }
        return false
    }
}

enum ProjectType: String, CaseIterable {
    case lodging = "Lodging"
    case commercial = "Commercial"
    case residential = "Residential"
    case mixedUse = "Mixed-Use"
    case infrastructure = "Infrastructure"
    case other = "Other"

    var localizationKey: String {
        "project.type.\(rawValue)"
    }

    init?(apiValue: String) {
        let normalized = normalizedLookupKey(apiValue)
        guard !normalized.isEmpty else { return nil }
        if let match = ProjectType.allCases.first(where: { normalizedLookupKey($0.rawValue) == normalized }) {
            self = match
        } else {
            return nil
        }
    }
}

enum I956FStatus: String, CaseIterable {
    case approved = "Approved"
    case pending = "Pending"
    case notFiled = "Not Filed"

    var localizationKey: String {
        switch self {
        case .approved:
            return "projects.uscis.i956f.approved"
        case .pending:
            return "projects.uscis.i956f.pending"
        case .notFiled:
            return "projects.uscis.i956f.not_filed"
        }
    }

    var color: Color {
        switch self {
        case .approved:
            return .green
        case .pending:
            return .orange
        case .notFiled:
            return .gray
        }
    }

    init?(apiValue: String) {
        let normalized = normalizedLookupKey(apiValue)
        guard !normalized.isEmpty else { return nil }
        if let match = I956FStatus.allCases.first(where: { normalizedLookupKey($0.rawValue) == normalized }) {
            self = match
        } else {
            return nil
        }
    }
}

enum I526EStatus: String, CaseIterable {
    case openToInvestment = "Open to Investment"
    case fullySubscribed = "Fully Subscribed"
    case notApplicable = "N/A (Pre‑RIA / No I‑526E)"
    case closed = "Closed (Not Accepting New Investors)"

    var localizationKey: String {
        switch self {
        case .openToInvestment:
            return "projects.uscis.i526e.open"
        case .fullySubscribed:
            return "projects.uscis.i526e.full"
        case .notApplicable:
            return "projects.uscis.i526e.na"
        case .closed:
            return "projects.uscis.i526e.closed"
        }
    }

    var color: Color {
        switch self {
        case .openToInvestment:
            return .green
        case .fullySubscribed:
            return .orange
        case .notApplicable:
            return .gray
        case .closed:
            return .red
        }
    }

    init?(apiValue: String) {
        let normalized = normalizedLookupKey(apiValue)
        guard !normalized.isEmpty else { return nil }
        if let match = I526EStatus.allCases.first(where: { normalizedLookupKey($0.rawValue) == normalized }) {
            self = match
        } else {
            return nil
        }
    }
}

enum TEAType: String, CaseIterable {
    case ruralAreas = "Rural Areas"
    case highUnemploymentAreas = "High-Unemployment Areas"
    case none = "None"

    var localizationKey: String {
        switch self {
        case .ruralAreas:
            return "projects.tea.rural"
        case .highUnemploymentAreas:
            return "projects.tea.high_unemployment"
        case .none:
            return "projects.tea.none"
        }
    }

    init?(apiValue: String) {
        let normalized = normalizedLookupKey(apiValue)
        guard !normalized.isEmpty else { return nil }
        if let match = TEAType.allCases.first(where: { normalizedLookupKey($0.rawValue) == normalized }) {
            self = match
        } else {
            return nil
        }
    }
}

enum LoanType: String, CaseIterable {
    case loan = "Loan"
    case mezzanine = "Mezzanine"
    case equity = "Equity"
    case other = "Other"

    var localizationKey: String {
        switch self {
        case .loan:
            return "projects.loan.type.loan"
        case .mezzanine:
            return "projects.loan.type.mezzanine"
        case .equity:
            return "projects.loan.type.equity"
        case .other:
            return "projects.loan.type.other"
        }
    }

    init?(apiValue: String) {
        let normalized = normalizedLookupKey(apiValue)
        guard !normalized.isEmpty else { return nil }
        if let match = LoanType.allCases.first(where: { normalizedLookupKey($0.rawValue) == normalized }) {
            self = match
        } else {
            return nil
        }
    }
}
private extension KeyedDecodingContainer {
    func decodeIfPresentAsString(forKey key: Key) -> String? {
        if let string = try? decode(String.self, forKey: key) {
            return string
        }
        if let int = try? decode(Int.self, forKey: key) {
            return String(int)
        }
        if let double = try? decode(Double.self, forKey: key) {
            return String(double)
        }
        if let bool = try? decode(Bool.self, forKey: key) {
            return bool ? "true" : "false"
        }
        return nil
    }

    func decodeIfPresentFlexibleInt(forKey key: Key) -> Int? {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decode(String.self, forKey: key),
           let parsed = Int(stringValue) {
            return parsed
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}
