// Accessibility Manager - VoiceOver Support

import SwiftUI

// MARK: - Accessibility Extensions
extension View {
    // Standard accessibility labels
    func guideAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    // Button accessibility
    func buttonAccessibility(label: String, hint: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
    
    // Image accessibility
    func imageAccessibility(label: String, isDecorative: Bool = false) -> some View {
        self
            .accessibilityLabel(isDecorative ? "" : label)
            .accessibilityHidden(isDecorative)
    }
}

// MARK: - Dynamic Type Support
struct AdaptiveFont: ViewModifier {
    let style: Font.TextStyle
    let size: CGFloat
    let weight: Font.Weight
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}

extension View {
    func adaptiveFont(
        style: Font.TextStyle = .body,
        size: CGFloat = 16,
        weight: Font.Weight = .regular
    ) -> some View {
        modifier(AdaptiveFont(style: style, size: size, weight: weight))
    }
}

// MARK: - Contrast Support
struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(differentiateWithoutColor ? 1.0 : 0.9)
    }
}

extension View {
    func highContrastSupport() -> some View {
        modifier(HighContrastModifier())
    }
}

// MARK: - Reduce Motion Support
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? .none : .default, value: UUID())
    }
}

extension View {
    func reduceMotionSupport() -> some View {
        modifier(ReduceMotionModifier())
    }
}

// MARK: - Accessibility Announcement
struct AccessibilityAnnouncement: ViewModifier {
    let message: String
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: message
                    )
                }
            }
    }
}

extension View {
    func announce(_ message: String, delay: Double = 0.5) -> some View {
        modifier(AccessibilityAnnouncement(message: message, delay: delay))
    }
}

// MARK: - Semantic Colors for Accessibility
extension Color {
    // High contrast versions
    static let accessibleRed = Color(red: 0.9, green: 0.1, blue: 0.1)
    static let accessibleGreen = Color(red: 0.1, green: 0.7, blue: 0.2)
    static let accessibleBlue = Color(red: 0.1, green: 0.4, blue: 0.9)
    static let accessibleOrange = Color(red: 0.9, green: 0.5, blue: 0.0)
    
    // Semantic colors
    static let successColor = Color.accessibleGreen
    static let errorColor = Color.accessibleRed
    static let warningColor = Color.accessibleOrange
    static let infoColor = Color.accessibleBlue
}

// MARK: - Accessibility Helpers
enum AccessibilityHelper {
    /// Check if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    /// Check if reduce motion is enabled
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Check if bold text is enabled
    static var isBoldTextEnabled: Bool {
        UIAccessibility.isBoldTextEnabled
    }
    
    /// Check if invert colors is enabled
    static var isInvertColorsEnabled: Bool {
        UIAccessibility.isInvertColorsEnabled
    }
    
    /// Announce message to VoiceOver
    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    /// Announce layout change
    static func layoutChanged() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
    
    /// Announce screen change
    static func screenChanged() {
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}

// MARK: - Accessibility Presets
struct AccessibilityPresets {
    // Standard button
    static func button(label: String, hint: String) -> some View {
        EmptyView()
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
    
    // Standard image
    static func image(label: String) -> some View {
        EmptyView()
            .accessibilityLabel(label)
    }
    
    // Decorative image
    static func decorativeImage() -> some View {
        EmptyView()
            .accessibilityHidden(true)
    }
    
    // Header
    static func header(_ text: String) -> some View {
        Text(text)
            .accessibilityAddTraits(.isHeader)
    }
}
