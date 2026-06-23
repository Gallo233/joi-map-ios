// Toast View - Custom Toast Notification

import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let style: ToastStyle
    
    enum ToastStyle {
        case success
        case error
        case info
        case warning
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            case .warning: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    init(_ message: String, icon: String? = nil, style: ToastStyle = .info) {
        self.message = message
        self.icon = icon ?? style.icon
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(style.color)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

// MARK: - Toast Modifier
struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let style: ToastView.ToastStyle
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if isPresented {
                ToastView(message, style: style)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, style: ToastView.ToastStyle = .info, duration: TimeInterval = 2) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, style: style, duration: duration))
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    init(_ message: String = "加载中...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.8))
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
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
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let action = action, let title = actionTitle {
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

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("出错了")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let retry = retryAction {
                Button(action: retry) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .fontWeight(.medium)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }
}

// MARK: - Haptic Feedback
enum HapticManager {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Preview
#Preview("Toast Styles") {
    VStack(spacing: 20) {
        ToastView("操作成功", style: .success)
        ToastView("网络错误", style: .error)
        ToastView("正在加载", style: .info)
        ToastView("电量不足", style: .warning)
    }
    .padding()
}
