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
    @Published var language: AppLanguage = .system
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
            switch self {
            case .system: return AIGuideLocalization.systemPreferredLocale
            case .chinese: return Locale(identifier: "zh-Hans_CN")
            case .traditionalChinese: return Locale(identifier: "zh-Hant_TW")
            case .english: return Locale(identifier: "en_US")
            case .japanese: return Locale(identifier: "ja_JP")
            case .korean: return Locale(identifier: "ko_KR")
            }
        }

        var localizedTitleKey: LocalizedStringKey {
            switch self {
            case .system: return "language.system"
            case .chinese: return "language.simplifiedChinese"
            case .traditionalChinese: return "language.traditionalChinese"
            case .english: return "language.english"
            case .japanese: return "language.japanese"
            case .korean: return "language.korean"
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
        autoPlayGuide = defaults.bool(forKey: autoPlayKey)
        wifiOnlyDownload = defaults.bool(forKey: wifiOnlyKey)
        hapticFeedback = defaults.bool(forKey: hapticKey)
        notificationEnabled = defaults.bool(forKey: notificationKey)
        offlineMode = defaults.bool(forKey: offlineKey)
        
        if let styleRaw = defaults.string(forKey: styleKey),
           let style = GuideStyle(rawValue: styleRaw) {
            guideStyle = style
        }
        
        if let langRaw = defaults.string(forKey: languageKey),
           let lang = AppLanguage(rawValue: langRaw) {
            language = lang
        } else if defaults.string(forKey: languageKey) == "中文" {
            language = .chinese
        }
        
        if let mapRaw = defaults.string(forKey: mapStyleKey),
           let map = MapStyle(rawValue: mapRaw) {
            mapStyle = map
        }
    }
}
