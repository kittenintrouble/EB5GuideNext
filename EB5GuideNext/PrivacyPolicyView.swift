import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: PolicyTab = .disclaimer

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("policy.picker.title", selection: $selectedTab) {
                    ForEach(PolicyTab.allCases) { tab in
                        Text(tab.titleKey)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)

                Divider()
                    .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(selectedTab.headerKey)
                            .font(.title3.weight(.semibold))
                            .padding(.top, 8)

                        Text(selectedTab.introKey)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        ForEach(selectedTab.blocks) { block in
                            PolicyBlockView(block: block)
                        }
                    }
                    .padding([.horizontal, .bottom])
                    .padding(.top, 20)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle(Text("policy.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("policy.action.close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview { PrivacyPolicyView() }

private struct PolicyBlock: Identifiable {
    struct Content: Identifiable {
        enum Kind {
            case paragraph(String)
            case bulletList([String])
        }

        let id = UUID()
        let kind: Kind

        static func paragraph(_ key: String) -> Content {
            Content(kind: .paragraph(key))
        }

        static func bulletList(_ keys: [String]) -> Content {
            Content(kind: .bulletList(keys))
        }
    }

    let id = UUID()
    let title: String?
    let contents: [Content]
}

private struct PolicyBlockView: View {
    let block: PolicyBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = block.title {
                Text(LocalizedStringKey(title))
                    .font(.headline)
            }

            ForEach(block.contents) { content in
                switch content.kind {
                case .paragraph(let key):
                    Text(LocalizedStringKey(key))
                        .font(.body)
                        .foregroundStyle(.primary)
                case .bulletList(let keys):
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(keys, id: \.self) { key in
                            HStack(alignment: .top, spacing: 8) {
                                Text("policy.bullet.prefix")
                                    .font(.body)
                                Text(LocalizedStringKey(key))
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private enum PolicyTab: Int, CaseIterable, Identifiable {
    case disclaimer
    case terms
    case privacy

    var id: Int { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .disclaimer: return "policy.tab.disclaimer"
        case .terms: return "policy.tab.terms"
        case .privacy: return "policy.tab.privacy"
        }
    }

    var headerKey: LocalizedStringKey {
        switch self {
        case .disclaimer: return "policy.disclaimer.title"
        case .terms: return "policy.terms.title"
        case .privacy: return "policy.privacy.title"
        }
    }

    var introKey: LocalizedStringKey {
        switch self {
        case .disclaimer: return "policy.disclaimer.intro"
        case .terms: return "policy.terms.intro"
        case .privacy: return "policy.privacy.intro"
        }
    }

    var blocks: [PolicyBlock] {
        switch self {
        case .disclaimer:
            return [
                PolicyBlock(title: "policy.disclaimer.purpose.title", contents: [.paragraph("policy.disclaimer.purpose.body")]),
                PolicyBlock(title: "policy.disclaimer.offer.title", contents: [.paragraph("policy.disclaimer.offer.body")]),
                PolicyBlock(title: "policy.disclaimer.independence.title", contents: [.paragraph("policy.disclaimer.independence.body")]),
                PolicyBlock(title: "policy.disclaimer.info_sources.title", contents: [.paragraph("policy.disclaimer.info_sources.body")]),
                PolicyBlock(title: "policy.disclaimer.forward_looking.title", contents: [.paragraph("policy.disclaimer.forward_looking.body")]),
                PolicyBlock(title: "policy.disclaimer.investor_responsibility.title", contents: [.paragraph("policy.disclaimer.investor_responsibility.body")]),
                PolicyBlock(title: "policy.disclaimer.government.title", contents: [.paragraph("policy.disclaimer.government.body")]),
                PolicyBlock(title: "policy.disclaimer.liability.title", contents: [.paragraph("policy.disclaimer.liability.body")])
            ]
        case .terms:
            return [
                PolicyBlock(title: "policy.terms.updated.title", contents: [.paragraph("policy.terms.updated.body")]),
                PolicyBlock(title: "policy.terms.acceptance.title", contents: [.paragraph("policy.terms.acceptance.body")]),
                PolicyBlock(title: "policy.terms.eligibility.title", contents: [.paragraph("policy.terms.eligibility.body")]),
                PolicyBlock(title: "policy.terms.role.title", contents: [.paragraph("policy.terms.role.body")]),
                PolicyBlock(title: "policy.terms.accounts.title", contents: [.paragraph("policy.terms.accounts.body")]),
                PolicyBlock(
                    title: "policy.terms.conduct.title",
                    contents: [
                        .paragraph("policy.terms.conduct.body"),
                        .bulletList([
                            "policy.terms.conduct.item1",
                            "policy.terms.conduct.item2",
                            "policy.terms.conduct.item3",
                            "policy.terms.conduct.item4",
                            "policy.terms.conduct.item5"
                        ])
                    ]
                ),
                PolicyBlock(title: "policy.terms.third_party.title", contents: [.paragraph("policy.terms.third_party.body")]),
                PolicyBlock(title: "policy.terms.inquiries.title", contents: [.paragraph("policy.terms.inquiries.body")]),
                PolicyBlock(title: "policy.terms.advertising.title", contents: [.paragraph("policy.terms.advertising.body")]),
                PolicyBlock(title: "policy.terms.ip.title", contents: [.paragraph("policy.terms.ip.body")]),
                PolicyBlock(title: "policy.terms.no_advice.title", contents: [.paragraph("policy.terms.no_advice.body")]),
                PolicyBlock(title: "policy.terms.disclaimers.title", contents: [.paragraph("policy.terms.disclaimers.body")]),
                PolicyBlock(title: "policy.terms.indemnification.title", contents: [.paragraph("policy.terms.indemnification.body")]),
                PolicyBlock(title: "policy.terms.compliance.title", contents: [.paragraph("policy.terms.compliance.body")]),
                PolicyBlock(title: "policy.terms.governing_law.title", contents: [.paragraph("policy.terms.governing_law.body")]),
                PolicyBlock(title: "policy.terms.changes.title", contents: [.paragraph("policy.terms.changes.body")]),
                PolicyBlock(title: "policy.terms.contact.title", contents: [.paragraph("policy.terms.contact.body")])
            ]
        case .privacy:
            return [
                PolicyBlock(title: "policy.privacy.last_updated.title", contents: [.paragraph("policy.privacy.last_updated.body")]),
                PolicyBlock(title: "policy.privacy.overview.title", contents: [.paragraph("policy.privacy.overview.body")]),
                PolicyBlock(
                    title: "policy.privacy.info_collect.title",
                    contents: [
                        .paragraph("policy.privacy.info_collect.body"),
                        .bulletList([
                            "policy.privacy.info_collect.item1",
                            "policy.privacy.info_collect.item2",
                            "policy.privacy.info_collect.item3",
                            "policy.privacy.info_collect.item4"
                        ]),
                        .paragraph("policy.privacy.info_collect.note")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.use.title",
                    contents: [
                        .paragraph("policy.privacy.use.body"),
                        .bulletList([
                            "policy.privacy.use.item1",
                            "policy.privacy.use.item2",
                            "policy.privacy.use.item3",
                            "policy.privacy.use.item4",
                            "policy.privacy.use.item5"
                        ])
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.share.title",
                    contents: [
                        .paragraph("policy.privacy.share.body"),
                        .bulletList([
                            "policy.privacy.share.item1",
                            "policy.privacy.share.item2",
                            "policy.privacy.share.item3",
                            "policy.privacy.share.item4",
                            "policy.privacy.share.item5",
                            "policy.privacy.share.item6",
                            "policy.privacy.share.item7"
                        ]),
                        .paragraph("policy.privacy.share.footer")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.cookies.title",
                    contents: [
                        .paragraph("policy.privacy.cookies.body"),
                        .paragraph("policy.privacy.cookies.note")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.security.title",
                    contents: [
                        .paragraph("policy.privacy.security.body")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.rights.title",
                    contents: [
                        .paragraph("policy.privacy.rights.body"),
                        .bulletList([
                            "policy.privacy.rights.item1",
                            "policy.privacy.rights.item2",
                            "policy.privacy.rights.item3",
                            "policy.privacy.rights.item4",
                            "policy.privacy.rights.item5"
                        ]),
                        .paragraph("policy.privacy.rights.note")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.california.title",
                    contents: [
                        .paragraph("policy.privacy.california.body")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.eu.title",
                    contents: [
                        .paragraph("policy.privacy.eu.body")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.children.title",
                    contents: [
                        .paragraph("policy.privacy.children.body")
                    ]
                ),
                PolicyBlock(
                    title: "policy.privacy.changes.title",
                    contents: [
                        .paragraph("policy.privacy.changes.body")
                    ]
                )
            ]
        }
    }
}
