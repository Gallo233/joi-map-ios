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
    @MainActor
    static var current: AIGuideLanguageContext {
        context(for: SettingsService.shared.language.locale)
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

    static var storedLocale: Locale {
        let rawValue = UserDefaults.standard.string(forKey: "com.aiguide.settings.language")

        switch rawValue {
        case SettingsService.AppLanguage.system.rawValue:
            return systemPreferredLocale
        case SettingsService.AppLanguage.chinese.rawValue, "中文":
            return Locale(identifier: "zh-Hans_CN")
        case SettingsService.AppLanguage.traditionalChinese.rawValue:
            return Locale(identifier: "zh-Hant_TW")
        case SettingsService.AppLanguage.english.rawValue:
            return Locale(identifier: "en_US")
        case SettingsService.AppLanguage.japanese.rawValue:
            return Locale(identifier: "ja_JP")
        case SettingsService.AppLanguage.korean.rawValue:
            return Locale(identifier: "ko_KR")
        default:
            return systemPreferredLocale
        }
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
        let rawValue = UserDefaults.standard.string(forKey: "com.aiguide.settings.language")

        switch rawValue {
        case SettingsService.AppLanguage.chinese.rawValue, "中文":
            return "zh-Hans"
        case SettingsService.AppLanguage.traditionalChinese.rawValue:
            return "zh-Hant"
        case SettingsService.AppLanguage.english.rawValue:
            return "en"
        case SettingsService.AppLanguage.japanese.rawValue:
            return "ja"
        case SettingsService.AppLanguage.korean.rawValue:
            return "ko"
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
