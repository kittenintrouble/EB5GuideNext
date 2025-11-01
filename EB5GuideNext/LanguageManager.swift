import SwiftUI
import Combine

@MainActor
final class LanguageManager: ObservableObject {
    static let languageDidChangeNotification = Notification.Name("LanguageManager.languageDidChange")
    static let storageKey = "selectedLanguageCode"
    static let supportedLanguageCodes: [String] = ["en", "zh-Hans", "vi", "ko"]
    static func messagingCode(for normalizedCode: String) -> String {
        switch normalizedCode.lowercased() {
        case "zh-hans":
            return "zh"
        case "en", "vi", "ko":
            return normalizedCode.lowercased()
        default:
            return normalizedCode.lowercased()
        }
    }

    @AppStorage(LanguageManager.storageKey) private var storedCode: String = "en"

    @Published var currentLocale: Locale = Locale(identifier: "en")
    private var cachedBundles: [String: Bundle] = [:]
    @Published var isSwitchingLanguage = false
    private var languageSwitchTask: Task<Void, Never>?

    init() {
        let normalized = LanguageManager.normalizedCode(for: storedCode)
        storedCode = normalized
        currentLocale = Locale(identifier: normalized)
    }

    var currentAPICode: String {
        LanguageManager.apiCode(for: currentLocale.identifier)
    }

    func setLanguage(code: String) {
        // Normalize a few common codes to match your .lproj folders
        let normalized = LanguageManager.normalizedCode(for: code)
        guard normalized != currentLocale.identifier else { return }

        languageSwitchTask?.cancel()
        isSwitchingLanguage = true
        storedCode = normalized
        cachedBundles.removeAll()
        // Always assign a new Locale to trigger UI updates even if the code didn't change
        currentLocale = Locale(identifier: normalized)
        NotificationCenter.default.post(name: LanguageManager.languageDidChangeNotification, object: normalized)

        languageSwitchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.endSwitchingIfNeeded()
        }
    }

    private func endSwitchingIfNeeded() {
        isSwitchingLanguage = false
        languageSwitchTask = nil
    }

    func localizedString(for key: String) -> String {
        let code = currentLocale.identifier
        if let bundle = bundle(for: code) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: "")
    }

    func localizedFormat(_ key: String, arguments: [CVarArg]) -> String {
        let format = localizedString(for: key)
        return String(format: format, locale: currentLocale, arguments: arguments)
    }

    func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
        localizedFormat(key, arguments: args)
    }

    func completionText(completed: Int, total: Int) -> String {
        localizedFormat("base.completed_format", completed, total)
    }

    static func normalizedCode(for code: String) -> String {
        switch code.lowercased() {
        case "zh", "zh-cn", "zh-hans": return "zh-Hans"
        case "en-us", "en": return "en"
        case "vi-vn", "vi": return "vi"
        case "ko-kr", "ko": return "ko"
        default: return code
        }
    }

    static func apiCode(for code: String) -> String {
        let normalized = normalizedCode(for: code)
        switch normalized {
        case "zh-Hans":
            return "zh"
        default:
            return normalized.lowercased()
        }
    }

    private func bundle(for code: String) -> Bundle? {
        if let cached = cachedBundles[code] { return cached }

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            cachedBundles[code] = bundle
            return bundle
        }

        if let path = Bundle.main.path(forResource: "Base", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            cachedBundles[code] = bundle
            return bundle
        }

        return nil
    }
}
