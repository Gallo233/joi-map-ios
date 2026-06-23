// Onboarding View - New User Guide

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(icon: "location.fill", titleKey: "onboarding.location.title", descriptionKey: "onboarding.location.description", color: .blue),
        OnboardingPage(icon: "speaker.wave.2.fill", titleKey: "onboarding.styles.title", descriptionKey: "onboarding.styles.description", color: .purple),
        OnboardingPage(icon: "person.wave.2.fill", titleKey: "onboarding.voice.title", descriptionKey: "onboarding.voice.description", color: .orange),
        OnboardingPage(icon: "camera.viewfinder", titleKey: "onboarding.photo.title", descriptionKey: "onboarding.photo.description", color: .green)
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("common.skip") {
                        isPresented = false
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
                
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageContent(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                Spacer()
                
                // Page indicator & buttons
                VStack(spacing: 24) {
                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[currentPage].color : .gray.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Button
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation {
                                currentPage += 1 }
                        } else {
                            isPresented = false
                        }
                    }) {
                        Text(currentPage < pages.count - 1 ? "common.next" : "onboarding.getStarted")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pages[currentPage].color)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(page.color)
            }
            
            // Title
            Text(page.titleKey)
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            Text(page.descriptionKey)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

struct OnboardingPage {
    let icon: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    let color: Color
}

// MARK: - Preview
#Preview {
    OnboardingView(isPresented: .constant(true))
}
