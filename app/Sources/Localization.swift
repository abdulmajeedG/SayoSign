import Foundation
import SwiftUI

/// The languages SayoSign ships with. UI-only: technical values such as bundle IDs,
/// file extensions and protocol names are never translated.
enum AppLanguage: String, CaseIterable, Identifiable, Hashable {
    case english = "en"
    case arabic = "ar"
    case french = "fr"
    case portuguese = "pt"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case spanish = "es"
    case german = "de"
    case russian = "ru"
    case japanese = "ja"
    case turkish = "tr"
    case italian = "it"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .french: return "Français"
        case .portuguese: return "Português"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .turkish: return "Türkçe"
        case .italian: return "Italiano"
        }
    }

    var englishName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "Arabic"
        case .french: return "French"
        case .portuguese: return "Portuguese"
        case .simplifiedChinese: return "Chinese, Simplified"
        case .traditionalChinese: return "Chinese, Traditional"
        case .spanish: return "Spanish"
        case .german: return "German"
        case .russian: return "Russian"
        case .japanese: return "Japanese"
        case .turkish: return "Turkish"
        case .italian: return "Italian"
        }
    }

    var initial: String {
        switch self {
        case .english: return "A"
        case .arabic: return "ع"
        case .french: return "F"
        case .portuguese: return "P"
        case .simplifiedChinese: return "简"
        case .traditionalChinese: return "繁"
        case .spanish: return "E"
        case .german: return "D"
        case .russian: return "Р"
        case .japanese: return "日"
        case .turkish: return "T"
        case .italian: return "I"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english: return "en"
        case .arabic: return "ar"
        case .french: return "fr"
        case .portuguese: return "pt"
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .spanish: return "es"
        case .german: return "de"
        case .russian: return "ru"
        case .japanese: return "ja"
        case .turkish: return "tr"
        case .italian: return "it"
        }
    }

    var isRTL: Bool { self == .arabic }
}

/// Loads the selected .lproj bundle at runtime. The choice is stored in UserDefaults,
/// independently from the signing state file, so it survives updates and resets of app data.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    static let storageKey = "sayosign.language"

    @Published private(set) var language: AppLanguage
    @Published private(set) var revision: Int = 0

    private let lock = NSLock()
    private var bundle: Bundle
    private var fallback: Bundle

    private init() {
        fallback = Bundle.main
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        let choice = AppLanguage(rawValue: stored ?? "") ?? Self.systemDefault()
        language = choice
        bundle = Self.bundle(for: choice) ?? Bundle.main
    }


    private static func systemDefault() -> AppLanguage {
        guard let system = Locale.preferredLanguages.first?.lowercased() else { return .english }
        if system.hasPrefix("zh") {
            if system.contains("hant") || system.contains("tw") || system.contains("hk") || system.contains("mo") {
                return .traditionalChinese
            }
            return .simplifiedChinese
        }
        return AppLanguage.allCases.first { system.hasPrefix($0.rawValue.lowercased()) } ?? .english
    }

    var locale: Locale { Locale(identifier: language.localeIdentifier) }
    var isRTL: Bool { language.isRTL }
    var layoutDirection: LayoutDirection { language.isRTL ? .rightToLeft : .leftToRight }

    func set(_ value: AppLanguage) {
        guard value != language else { return }
        UserDefaults.standard.set(value.rawValue, forKey: Self.storageKey)
        UserDefaults.standard.synchronize()
        let b = Self.bundle(for: value) ?? Bundle.main
        lock.lock()
        bundle = b
        lock.unlock()
        language = value
        revision += 1
        objectWillChange.send()
    }

    func string(_ key: String) -> String {
        lock.lock()
        let b = bundle
        let f = fallback
        lock.unlock()
        let value = b.localizedString(forKey: key, value: "\u{0}", table: nil)
        if value != "\u{0}" { return value }
        let english = f.localizedString(forKey: key, value: "\u{0}", table: nil)
        return english == "\u{0}" ? key : english
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        func load(_ code: String) -> Bundle? {
            guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
            return Bundle(path: path)
        }
        if let b = load(language.rawValue) { return b }
        // A regional tag such as zh-Hant-HK still uses the Traditional Chinese strings.
        if let b = load(String(language.rawValue.prefix(2))) { return b }
        return load("en")
    }
}
