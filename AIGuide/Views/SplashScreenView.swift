// Splash Screen View - App Launch Animation

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.2, blue: 0.4),
                    Color(red: 0.2, green: 0.4, blue: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // App icon
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 160, height: 160)
                    
                    // Icon background
                    RoundedRectangle(cornerRadius: 36)
                        .fill(.white)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    
                    // Icon
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                
                // App name
                VStack(spacing: 8) {
                    Text("随身讲解")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("AI 实时景区导览")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .opacity(textOpacity)
                
                // Features
                VStack(spacing: 16) {
                    featureRow(icon: "location.fill", text: "智能定位讲解")
                    featureRow(icon: "speaker.wave.2.fill", text: "多种语音风格")
                    featureRow(icon: "arkit", text: "AR 实景导览")
                }
                .padding(.top, 40)
                .opacity(subtitleOpacity)
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    
                    Text("正在加载...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimation()
        }
        .fullScreenCover(isPresented: $isActive) {
            ContentView()
                .environmentObject(AppState())
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private func startAnimation() {
        // Icon animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Text animation
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            textOpacity = 1.0
        }
        
        // Subtitle animation
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            subtitleOpacity = 1.0
        }
        
        // Navigate to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isActive = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SplashScreenView()
}
