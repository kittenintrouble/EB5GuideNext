import SwiftUI

struct LanguageSwitchMenu: View {
    @ObservedObject var languageManager: LanguageManager
    var beforeChange: (() -> Void)?
    var afterChange: (() -> Void)?
    @State private var pendingTask: Task<Void, Never>? = nil
    @State private var isSheetPresented = false

    private var currentIdentifier: String {
        languageManager.currentLocale.identifier
    }

    var body: some View {
        Button {
            isSheetPresented = true
        } label: {
            Image(systemName: "globe")
                .imageScale(.large)
        }
        .accessibilityLabel(Text(languageManager.localizedString(for: "language.switcher.accessibility")))
        .sheet(isPresented: $isSheetPresented) {
            LanguageSelectionSheet(
                languageManager: languageManager,
                currentIdentifier: currentIdentifier,
                onSelect: { option in
                    isSheetPresented = false
                    guard !option.matches(localeIdentifier: currentIdentifier) else { return }
                    scheduleLanguageChange(for: option)
                },
                onCancel: {
                    isSheetPresented = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func scheduleLanguageChange(for option: LanguageSwitchOption) {
        pendingTask?.cancel()
        let selectedCode = option.code
        pendingTask = Task { @MainActor in
            // Give the menu a moment to dismiss before we manipulate navigation state.
            try? await Task.sleep(nanoseconds: 150_000_000)
            beforeChange?()
            // Allow any navigation updates to settle.
            try? await Task.sleep(nanoseconds: 80_000_000)
            languageManager.setLanguage(code: selectedCode)
            afterChange?()
        }
    }
}

struct LanguageSwitchOption: Identifiable, CaseIterable {
    let id: String
    let code: String
    let flag: String
    let nameKey: String

    static let allCases: [LanguageSwitchOption] = [
        LanguageSwitchOption(id: "en", code: "en", flag: "🇺🇸", nameKey: "home.language.english"),
        LanguageSwitchOption(id: "zh-Hans", code: "zh-Hans", flag: "🇨🇳", nameKey: "home.language.chinese"),
        LanguageSwitchOption(id: "vi", code: "vi", flag: "🇻🇳", nameKey: "home.language.vietnamese"),
        LanguageSwitchOption(id: "ko", code: "ko", flag: "🇰🇷", nameKey: "home.language.korean")
    ]

    var localizedKey: LocalizedStringKey {
        LocalizedStringKey(nameKey)
    }

    func matches(localeIdentifier: String) -> Bool {
        let loweredIdentifier = localeIdentifier.lowercased()
        let normalizedCode = code.lowercased()

        if loweredIdentifier == normalizedCode { return true }
        if loweredIdentifier.replacingOccurrences(of: "-", with: "_") == normalizedCode { return true }

        let identifierBase = loweredIdentifier.split(separator: "-").first?.lowercased()
        if identifierBase == normalizedCode { return true }

        if let codeBase = normalizedCode.split(separator: "-").first?.lowercased(), codeBase == loweredIdentifier {
            return true
        }

        if let codeBase = normalizedCode.split(separator: "-").first?.lowercased(), codeBase == identifierBase {
            return true
        }

        return false
    }
}

private struct LanguageSelectionSheet: View {
    @ObservedObject var languageManager: LanguageManager
    let currentIdentifier: String
    let onSelect: (LanguageSwitchOption) -> Void
    let onCancel: () -> Void

    private var title: String {
        languageManager.localizedString(for: "home.language.sheet.title")
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                languageCard

                Button(action: onCancel) {
                    Text(LocalizedStringKey("common.cancel"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            ForEach(LanguageSwitchOption.allCases) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 14) {
                        Text(option.flag)
                            .font(.system(size: 24))
                            .frame(width: 32, alignment: .leading)
                        Text(option.localizedKey)
                            .font(.system(size: 17))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if option.matches(localeIdentifier: currentIdentifier) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                if option.id != LanguageSwitchOption.allCases.last?.id {
                    Divider()
                        .overlay(Color(UIColor.separator))
                        .padding(.leading, 16 + 32 + 14)
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
}

struct LanguageSwitchOverlay: View {
    @ObservedObject var languageManager: LanguageManager

    var body: some View {
        Group {
            if languageManager.isSwitchingLanguage {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text(languageManager.localizedString(for: "language.switching"))
                            .font(.headline)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.black.opacity(0.6))
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: languageManager.isSwitchingLanguage)
    }
}
