import Foundation

struct AIGuideLanguageContext {
    let locale: Locale
    let identifier: String
    let languageCode: String
    let regionCode: String?

    var backendLanguage: String {
        let normalizedIdentifier = identifier.replacingOccurrences(of: "_", with: "-")
        guard !normalizedIdentifier.isEmpty else { return "zh-CN" }
        return normalizedIdentifier
    }

    var acceptLanguageHeader: String {
        "\(backendLanguage), \(languageCode);q=0.9, en;q=0.7"
    }

    var userRegion: String {
        regionCode ?? Locale.current.region?.identifier ?? "auto"
    }

    var displayLanguageName: String {
        locale.localizedString(forIdentifier: backendLanguage) ?? backendLanguage
    }

    var speechLanguageCode: String {
        switch languageCode.lowercased() {
        case "zh":
            if backendLanguage.lowercased().contains("hant") ||
                ["TW", "HK", "MO"].contains(userRegion.uppercased()) {
                return "zh-TW"
            }
            return "zh-CN"
        case "ja":
            return "ja-JP"
        case "ko":
            return "ko-KR"
        default:
            return "en-US"
        }
    }

    var llmResponseInstruction: String {
        switch languageCode.lowercased() {
        case "zh":
            if backendLanguage.lowercased().contains("hant") ||
                ["TW", "HK", "MO"].contains(userRegion.uppercased()) {
                return "請使用繁體中文回答，語氣自然，避免 Markdown 符號。"
            }
            return "请使用简体中文回答，语气自然，避免 Markdown 符号。"
        case "ja":
            return "日本語で自然に回答してください。Markdown 記号は使わないでください。"
        case "ko":
            return "자연스러운 한국어로 답변하세요. Markdown 기호는 사용하지 마세요."
        default:
            return "Answer in natural English. Do not use Markdown symbols."
        }
    }
}

enum AIGuideLocalization {
    private static let selectedLanguageLock = NSLock()
    private static var selectedLanguageOverride: SettingsService.AppLanguage?

    @MainActor
    static var current: AIGuideLanguageContext {
        context(for: locale(for: SettingsService.shared.language))
    }

    static var systemPreferredLocale: Locale {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        let normalizedIdentifier = preferredIdentifier.replacingOccurrences(of: "_", with: "-")
        let lowercasedIdentifier = normalizedIdentifier.lowercased()

        if lowercasedIdentifier.hasPrefix("zh-hant") ||
            lowercasedIdentifier.hasPrefix("zh-tw") ||
            lowercasedIdentifier.hasPrefix("zh-hk") ||
            lowercasedIdentifier.hasPrefix("zh-mo") {
            return Locale(identifier: "zh-Hant_TW")
        }

        if lowercasedIdentifier.hasPrefix("zh") {
            return Locale(identifier: "zh-Hans_CN")
        }

        if lowercasedIdentifier.hasPrefix("ja") {
            return Locale(identifier: "ja_JP")
        }

        if lowercasedIdentifier.hasPrefix("ko") {
            return Locale(identifier: "ko_KR")
        }

        return Locale(identifier: "en_US")
    }

    static func setSelectedLanguage(_ language: SettingsService.AppLanguage) {
        selectedLanguageLock.lock()
        selectedLanguageOverride = language
        selectedLanguageLock.unlock()
    }

    static func locale(for language: SettingsService.AppLanguage) -> Locale {
        switch language {
        case .system:
            return systemPreferredLocale
        case .chinese:
            return Locale(identifier: "zh-Hans_CN")
        case .traditionalChinese:
            return Locale(identifier: "zh-Hant_TW")
        case .english:
            return Locale(identifier: "en_US")
        case .japanese:
            return Locale(identifier: "ja_JP")
        case .korean:
            return Locale(identifier: "ko_KR")
        }
    }

    static var storedLocale: Locale {
        locale(for: selectedLanguage)
    }

    private static var selectedLanguage: SettingsService.AppLanguage {
        if let qaLanguage = qaAppLanguageOverride {
            return qaLanguage
        }

        if let override = selectedLanguageOverrideValue {
            return override
        }

        return persistedLanguage
    }

    private static var selectedLanguageOverrideValue: SettingsService.AppLanguage? {
        selectedLanguageLock.lock()
        defer { selectedLanguageLock.unlock() }
        return selectedLanguageOverride
    }

    private static var persistedLanguage: SettingsService.AppLanguage {
        guard let rawValue = UserDefaults.standard.string(forKey: "com.aiguide.settings.language") else {
            return .system
        }

        if rawValue == "中文" {
            return .chinese
        }

        return SettingsService.AppLanguage(rawValue: rawValue) ?? .system
    }

    static var activeBundle: Bundle {
        guard let lprojName = activeLprojName,
              let path = Bundle.main.path(forResource: lprojName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }

        return bundle
    }

    private static var activeLprojName: String? {
        switch selectedLanguage {
        case .system:
            return nil
        case .chinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        }
    }

    private static var qaLanguageOverride: String? {
        let prefix = "AIGUIDE_QA_LANGUAGE="
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static var qaAppLanguageOverride: SettingsService.AppLanguage? {
        switch qaLanguageOverride {
        case "zh-Hans":
            return .chinese
        case "zh-Hant":
            return .traditionalChinese
        case "en":
            return .english
        case "ja":
            return .japanese
        case "ko":
            return .korean
        default:
            return nil
        }
    }

    static func context(for locale: Locale) -> AIGuideLanguageContext {
        let identifier = locale.identifier
        let languageCode: String
        if #available(iOS 16.0, *) {
            languageCode = locale.language.languageCode?.identifier ?? Locale.current.language.languageCode?.identifier ?? "zh"
        } else {
            languageCode = locale.languageCode ?? Locale.current.languageCode ?? "zh"
        }

        let regionCode: String?
        if #available(iOS 16.0, *) {
            regionCode = locale.region?.identifier
        } else {
            regionCode = locale.regionCode
        }

        return AIGuideLanguageContext(
            locale: locale,
            identifier: identifier,
            languageCode: languageCode,
            regionCode: regionCode
        )
    }
}

enum L10n {
    static func string(_ key: String) -> String {
        AIGuideLocalization.activeBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: string(key),
            locale: AIGuideLocalization.storedLocale,
            arguments: arguments
        )
    }
}
