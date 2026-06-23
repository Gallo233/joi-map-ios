// UI Helpers - Common UI Components

import SwiftUI

// MARK: - Loading States
struct LoadingOverlay: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated loading indicator
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                }
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Progress Indicator
struct CircularProgressView: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    
    init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6, color: Color = .blue) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            
            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let count: Int
    let color: Color
    
    init(count: Int, color: Color = .red) {
        self.count = count
        self.color = color
    }
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Tag View
struct TagView: View {
    let text: String
    let color: Color
    let icon: String?
    
    init(_ text: String, color: Color = .blue, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Divider with Text
struct TextDivider: View {
    let text: String
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(height: 1)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            
            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Card Style
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Section Header
struct SectionHeaderView: View {
    let title: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if let action = action, let title = actionTitle {
                Button(action: action) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let buttonAction: (() -> Void)?
    
    init(icon: String, title: String, message: String, buttonTitle: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = buttonAction, let title = buttonTitle {
                Button(action: action) {
                    Text(title)
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    init(icon: String, title: String, value: String, color: Color = .blue) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Toggle Row
struct ToggleRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool
    
    init(icon: String, title: String, color: Color = .blue, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self.color = color
        self._isOn = isOn
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                
                Text(title)
            }
        }
    }
}
