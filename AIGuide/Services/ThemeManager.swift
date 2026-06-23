// Theme Manager - Appearance Settings

import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    enum AppearanceMode: Int, CaseIterable, Identifiable {
        case system = 0
        case light = 1
        case dark = 2

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .system: return L10n.string("appearance.system")
            case .light: return L10n.string("appearance.light")
            case .dark: return L10n.string("appearance.dark")
            }
        }

        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // MARK: - Published Properties
    @Published var colorScheme: ColorScheme? = nil // nil = system
    @Published var accentColor: Color = .blue
    @Published var useHaptics: Bool = true
    @Published var useAnimations: Bool = true
    
    // MARK: - Singleton
    static let shared = ThemeManager()
    
    // MARK: - Private Properties
    private let defaults = UserDefaults.standard
    private let schemeKey = "com.aiguide.theme.scheme"
    private let hapticsKey = "com.aiguide.theme.haptics"
    private let animationsKey = "com.aiguide.theme.animations"
    
    // MARK: - Initialization
    init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Set color scheme
    func setColorScheme(_ scheme: ColorScheme?) {
        colorScheme = scheme
        saveSettings()
    }

    var appearanceMode: AppearanceMode {
        switch colorScheme {
        case .light: return .light
        case .dark: return .dark
        default: return .system
        }
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        setColorScheme(mode.colorScheme)
    }
    
    /// Toggle haptics
    func toggleHaptics() {
        useHaptics.toggle()
        saveSettings()
    }
    
    /// Toggle animations
    func toggleAnimations() {
        useAnimations.toggle()
        saveSettings()
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        // Load color scheme
        let schemeRaw = defaults.integer(forKey: schemeKey)
        switch schemeRaw {
        case 1: colorScheme = .light
        case 2: colorScheme = .dark
        default: colorScheme = nil // system
        }
        
        // Load haptics
        if defaults.object(forKey: hapticsKey) != nil {
            useHaptics = defaults.bool(forKey: hapticsKey)
        }
        
        // Load animations
        if defaults.object(forKey: animationsKey) != nil {
            useAnimations = defaults.bool(forKey: animationsKey)
        }
    }
    
    private func saveSettings() {
        // Save color scheme
        let schemeRaw: Int
        switch colorScheme {
        case .light: schemeRaw = 1
        case .dark: schemeRaw = 2
        default: schemeRaw = 0
        }
        defaults.set(schemeRaw, forKey: schemeKey)
        
        // Save haptics
        defaults.set(useHaptics, forKey: hapticsKey)
        
        // Save animations
        defaults.set(useAnimations, forKey: animationsKey)
    }
}

// MARK: - Color Extensions
extension Color {
    // App Colors
    static let appPrimary = Color("AccentColor")
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appTertiaryBackground = Color(.tertiarySystemBackground)
    
    // Semantic Colors
    static let successGreen = Color.green
    static let warningOrange = Color.orange
    static let errorRed = Color.red
    static let infoBlue = Color.blue
}

// MARK: - View Extensions
extension View {
    func appStyle() -> some View {
        self
            .tint(.blue)
    }
    
    func cardStyle() -> some View {
        self
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    func primaryButtonStyle() -> some View {
        self
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.gray.opacity(0.15))
            .foregroundStyle(.primary)
            .clipShape(Capsule())
    }
}

// MARK: - Animation Extensions
extension Animation {
    static let appSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let appEaseOut = Animation.easeOut(duration: 0.3)
    static let appEaseIn = Animation.easeIn(duration: 0.2)
}
