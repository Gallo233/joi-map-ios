// Animation Manager - Unified Animation System

import SwiftUI

// MARK: - Animation Presets
extension Animation {
    // Standard animations
    static let appQuick = Animation.easeOut(duration: 0.2)
    static let appNormal = Animation.easeOut(duration: 0.3)
    static let appSlow = Animation.easeOut(duration: 0.5)
    
    // Spring animations
    static let appBouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let appSmooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let appSnappy = Animation.spring(response: 0.2, dampingFraction: 0.9)
    
    // Special animations
    static let appPulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    static let appShake = Animation.default.repeatCount(3, autoreverses: true)
}

// MARK: - Animated Transition
struct SlideInTransition: ViewModifier {
    let edge: Edge
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity),
                removal: .move(edge: edge == .leading ? .trailing : .leading).combined(with: .opacity)
            ))
    }
}

extension View {
    func slideIn(from edge: Edge = .trailing) -> some View {
        modifier(SlideInTransition(edge: edge))
    }
}

// MARK: - Pulse Effect
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                    .animation(.appPulse, value: isPulsing)
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulse(color: Color = .blue) -> some View {
        modifier(PulseEffect(color: color))
    }
}

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: phase
                    )
                }
                .mask(content)
            )
            .onAppear { phase = 1 }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Bounce Effect
struct BounceEffect: ViewModifier {
    @State private var isBouncing = false
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 0.95 : 1.0)
            .animation(.appBouncy, value: isBouncing)
            .onChange(of: trigger) { _, _ in
                withAnimation {
                    isBouncing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        isBouncing = false
                    }
                }
            }
    }
}

extension View {
    func bounce(trigger: Bool) -> some View {
        modifier(BounceEffect(trigger: trigger))
    }
}

// MARK: - Fade In Animation
struct FadeInView: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(.appNormal.delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

extension View {
    func fadeIn(delay: Double = 0) -> some View {
        modifier(FadeInView(delay: delay))
    }
}

// MARK: - Slide Up Animation
struct SlideUpView: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isVisible ? 0 : 20)
            .opacity(isVisible ? 1 : 0)
            .animation(.appNormal.delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

extension View {
    func slideUp(delay: Double = 0) -> some View {
        modifier(SlideUpView(delay: delay))
    }
}

// MARK: - Scale Animation
struct ScaleInView: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
            .animation(.appBouncy.delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}

extension View {
    func scaleIn(delay: Double = 0) -> some View {
        modifier(ScaleInView(delay: delay))
    }
}

// MARK: - Staggered Animation
struct StaggeredAnimation: ViewModifier {
    let index: Int
    let baseDelay: Double
    
    func body(content: Content) -> some View {
        content
            .fadeIn(delay: Double(index) * baseDelay)
            .slideUp(delay: Double(index) * baseDelay)
    }
}

extension View {
    func staggered(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredAnimation(index: index, baseDelay: baseDelay))
    }
}
