// Settings Service - App Settings Management

import Foundation
import SwiftUI

@MainActor
class SettingsService: ObservableObject {
    // MARK: - Published Properties
    @Published var autoPlayGuide: Bool = true
    @Published var wifiOnlyDownload: Bool = false
    @Published var preferredVoice: EdgeVoice = .default
    @Published var guideStyle: GuideStyle = .history
    @Published var language: AppLanguage = .system {
        didSet {
            AIGuideLocalization.setSelectedLanguage(language)
        }
    }
    @Published var mapStyle: MapStyle = .standard
    @Published var notificationEnabled: Bool = true
    @Published var hapticFeedback: Bool = true
    @Published var offlineMode: Bool = false
    
    // MARK: - Types
    enum AppLanguage: String, CaseIterable {
        case system = "跟随系统"
        case chinese = "简体中文"
        case traditionalChinese = "繁體中文"
        case english = "English"
        case japanese = "日本語"
        case korean = "한국어"
        
        var locale: Locale {
            AIGuideLocalization.locale(for: self)
        }

        var localizedTitle: String {
            switch self {
            case .system: return L10n.string("language.system")
            case .chinese: return L10n.string("language.simplifiedChinese")
            case .traditionalChinese: return L10n.string("language.traditionalChinese")
            case .english: return L10n.string("language.english")
            case .japanese: return L10n.string("language.japanese")
            case .korean: return L10n.string("language.korean")
            }
        }
    }
    
    enum MapStyle: String, CaseIterable {
        case standard = "标准"
        case satellite = "卫星"
        case hybrid = "混合"

        var localizedTitle: String {
            switch self {
            case .standard: return L10n.string("settings.mapStyle.standard")
            case .satellite: return L10n.string("settings.mapStyle.satellite")
            case .hybrid: return L10n.string("settings.mapStyle.hybrid")
            }
        }
        
        var mapType: Int {
            switch self {
            case .standard: return 0
            case .satellite: return 1
            case .hybrid: return 2
            }
        }
    }
    
    // MARK: - Private Properties
    private let defaults = UserDefaults.standard
    
    // Keys
    private let autoPlayKey = "com.aiguide.settings.autoPlay"
    private let wifiOnlyKey = "com.aiguide.settings.wifiOnly"
    private let voiceKey = "com.aiguide.settings.voice"
    private let styleKey = "com.aiguide.settings.style"
    private let languageKey = "com.aiguide.settings.language"
    private let mapStyleKey = "com.aiguide.settings.mapStyle"
    private let notificationKey = "com.aiguide.settings.notification"
    private let hapticKey = "com.aiguide.settings.haptic"
    private let offlineKey = "com.aiguide.settings.offline"
    
    // MARK: - Singleton
    static let shared = SettingsService()
    
    // MARK: - Initialization
    init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Save all settings
    func saveSettings() {
        AIGuideLocalization.setSelectedLanguage(language)
        defaults.set(autoPlayGuide, forKey: autoPlayKey)
        defaults.set(wifiOnlyDownload, forKey: wifiOnlyKey)
        defaults.set(guideStyle.rawValue, forKey: styleKey)
        defaults.set(language.rawValue, forKey: languageKey)
        defaults.set(mapStyle.rawValue, forKey: mapStyleKey)
        defaults.set(notificationEnabled, forKey: notificationKey)
        defaults.set(hapticFeedback, forKey: hapticKey)
        defaults.set(offlineMode, forKey: offlineKey)
    }
    
    /// Reset all settings
    func resetSettings() {
        autoPlayGuide = true
        wifiOnlyDownload = false
        guideStyle = .history
        language = .system
        mapStyle = .standard
        notificationEnabled = true
        hapticFeedback = true
        offlineMode = false
        saveSettings()
    }
    
    /// Clear all cached data
    func clearCache() {
        // Clear image cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear offline data
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent("OfflineData"))
    }
    
    /// Get cache size
    func getCacheSize() -> String {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let offlineCache = cacheDirectory.appendingPathComponent("OfflineData")
        
        guard let size = try? FileManager.default.attributesOfItem(atPath: offlineCache.path)[.size] as? Int else {
            return "0 MB"
        }
        
        let mb = Double(size) / 1024 / 1024
        return String(format: "%.1f MB", mb)
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        autoPlayGuide = boolValue(forKey: autoPlayKey, defaultValue: true)
        wifiOnlyDownload = defaults.bool(forKey: wifiOnlyKey)
        hapticFeedback = boolValue(forKey: hapticKey, defaultValue: true)
        notificationEnabled = boolValue(forKey: notificationKey, defaultValue: true)
        offlineMode = defaults.bool(forKey: offlineKey)
        
        if let styleRaw = defaults.string(forKey: styleKey),
           let style = GuideStyle(rawValue: styleRaw) {
            guideStyle = style
        }

        if let qaLanguage = Self.qaLanguageOverride {
            language = qaLanguage
        } else if let langRaw = defaults.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: langRaw) {
            language = lang
        } else if defaults.string(forKey: languageKey) == "中文" {
            language = .chinese
        }
        
        if let mapRaw = defaults.string(forKey: mapStyleKey),
           let map = MapStyle(rawValue: mapRaw) {
            mapStyle = map
        }

        AIGuideLocalization.setSelectedLanguage(language)
    }

    private func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }

    private static var qaLanguageOverride: AppLanguage? {
        let prefix = "AIGUIDE_QA_LANGUAGE="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }

        switch String(argument.dropFirst(prefix.count)) {
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
}
