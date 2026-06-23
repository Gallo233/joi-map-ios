import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue.opacity(0.8), .blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon
                Image(systemName: "building.2.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.white)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // App name
                Text("app.name")
                    .font(.largeTitle)
                    .fontWeight(.bold)
.foregroundStyle(Color.white)
                
                // Loading
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.8))
                
                // Loading indicator
                ProgressView()
                    .tint(.white)
                    .padding(.top, 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LaunchScreenView()
}
