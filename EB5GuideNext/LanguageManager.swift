import SwiftUI
import Combine

final class LanguageManager: ObservableObject {
    @AppStorage("selectedLanguageCode") private var storedCode: String = "en"

    @Published var currentLocale: Locale = Locale(identifier: "en")
    private var cachedBundles: [String: Bundle] = [:]

    init() {
        currentLocale = Locale(identifier: storedCode)
    }

    func setLanguage(code: String) {
        // Normalize a few common codes to match your .lproj folders
        let normalized = normalize(code)
        storedCode = normalized
        cachedBundles.removeAll()
        // Always assign a new Locale to trigger UI updates even if the code didn't change
        currentLocale = Locale(identifier: normalized)
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

    private func normalize(_ code: String) -> String {
        switch code.lowercased() {
        case "zh", "zh-cn", "zh-hans": return "zh-Hans"
        case "en-us", "en": return "en"
        case "vi-vn", "vi": return "vi"
        case "ko-kr", "ko": return "ko"
        default: return code
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
