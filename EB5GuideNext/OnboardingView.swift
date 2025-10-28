import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let onComplete: () -> Void

    struct LangOption: Identifiable, Equatable {
        let code: String
        let title: LocalizedStringKey
        let flag: String

        var id: String { code }
    }

    private var options: [LangOption] {
        [
            .init(code: "en", title: "language.english", flag: "🇺🇸"),
            .init(code: "zh-Hans", title: "language.chinese_simplified", flag: "🇨🇳"),
            .init(code: "vi", title: "language.vietnamese", flag: "🇻🇳"),
            .init(code: "ko", title: "language.korean", flag: "🇰🇷")
        ]
    }

    @State private var selectedCode: String = "en"
    @State private var showPrivacy: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Top spacing
                Spacer().frame(height: 42)

                // Logo
                Group {
                    Image("EB5Logo")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }

                // Title
                Text(LocalizedStringKey("onboarding.title"))
                    .font(.system(size: 34, weight: .regular))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                // Subtitle
                Text(LocalizedStringKey("onboarding.subtitle"))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 6)
                    .padding(.horizontal, 28)

                // Section: language
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey("onboarding.choose_language"))
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.top, 28)
                        .padding(.horizontal, 24)

                    languageCard
                        .padding(.horizontal, 20)
                }
                .padding(.top, 4)

                // Agreement text
                agreementView
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 18)
                    .padding(.horizontal, 24)

                // Primary button
                Button(action: {
                    languageManager.setLanguage(code: selectedCode)
                    onComplete()
                }) {
                    let title = languageManager.localizedString(for: "onboarding.lets_go")
                    Text(title.uppercased(with: languageManager.currentLocale))
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)
                )
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            selectedCode = languageManager.currentLocale.identifier
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
                .environmentObject(languageManager)
        }
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { idx in
                let option = options[idx]
                Button {
                    selectedCode = option.code
                    languageManager.setLanguage(code: option.code)
                } label: {
                    HStack(spacing: 14) {
                        Text(option.flag)
                            .font(.system(size: 24))
                            .frame(width: 28, alignment: .leading)
                        Text(option.title)
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if option.code == selectedCode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if idx < options.count - 1 {
                    Divider()
                        .overlay(Color(UIColor.separator))
                        .padding(.leading, 16 + 28 + 14) // align under text, not under flag
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(UIColor.quaternaryLabel), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }

    private var agreementView: some View {
        let prefix = languageManager.localizedString(for: "onboarding.agree_prefix")
        let company = languageManager.localizedString(for: "onboarding.company")
        let suffix = languageManager.localizedString(for: "onboarding.agree_suffix")

        var attributed = AttributedString(prefix)

        if !prefix.isEmpty && !prefix.hasSuffix(" ") && !company.isEmpty {
            attributed.append(AttributedString(" "))
        }

        let companyStart = attributed.endIndex
        attributed.append(AttributedString(company))
        let companyRange = companyStart..<attributed.endIndex

        if !suffix.isEmpty {
            let firstSuffixIsSpace = suffix.first?.isWhitespace ?? false
            let lastCharIsSpace = attributed.characters.last?.isWhitespace ?? false
            let needsSpace = !firstSuffixIsSpace && !lastCharIsSpace
            if needsSpace {
                attributed.append(AttributedString(" "))
            }
            attributed.append(AttributedString(suffix))
        }

        if !company.isEmpty {
            attributed[companyRange].foregroundColor = .accentColor
            attributed[companyRange].underlineStyle = .single
            attributed[companyRange].font = .system(size: 15, weight: .semibold)
        }

        let inline = Text(attributed)
            + Text(" ")
            + Text(Image(systemName: "arrow.up.right.square")).foregroundColor(.accentColor)

        return Button(action: { showPrivacy = true }) {
            inline
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(prefix) + Text(" ") + Text(company) + Text(" ") + Text(suffix))
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(LanguageManager())
}
