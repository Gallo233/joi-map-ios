// Haptic Feedback Manager

import UIKit

// MARK: - Haptic Manager
enum HapticManager {
    // MARK: - Impact Feedback
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func lightImpact() {
        impact(.light)
    }
    
    static func mediumImpact() {
        impact(.medium)
    }
    
    static func heavyImpact() {
        impact(.heavy)
    }
    
    static func softImpact() {
        if #available(iOS 13.0, *) {
            impact(.soft)
        } else {
            impact(.light)
        }
    }
    
    static func rigidImpact() {
        if #available(iOS 13.0, *) {
            impact(.rigid)
        } else {
            impact(.heavy)
        }
    }
    
    // MARK: - Notification Feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    // MARK: - Custom Patterns
    static func doubleTap() {
        impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact(.light)
        }
    }
    
    static func longPress() {
        impact(.medium)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact(.heavy)
        }
    }
    
    static func tripleTap() {
        impact(.light)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            impact(.light)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impact(.light)
        }
    }
}

// MARK: - Haptic Settings
extension HapticManager {
    private static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "hapticFeedback")
    }
    
    static func perform(_ action: () -> Void) {
        guard isEnabled else { return }
        action()
    }
}
