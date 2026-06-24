import SwiftUI

@main
struct AIGuideApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var settingsService = SettingsService.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                } else {
                    ContentView()
                }
            }
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environmentObject(settingsService)
            .environment(\.locale, settingsService.language.locale)
            .preferredColorScheme(themeManager.colorScheme)
            .task {
                await appState.initialize()
            }
            .onAppear {
                // Hide splash after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var isLocationAuthorized = false
    @Published var isCameraAuthorized = false
    @Published var currentPOI: POI?
    @Published var visualConfirmation: VisualPOIConfirmation?
    @Published var isPlaying = false
    @Published var isBackendConnected = false
    @Published var isInitializing = true
    @Published var isBottomNavigationHidden = false

    private let apiClient = APIClient()

    struct VisualPOIConfirmation: Identifiable {
        let id = UUID()
        let poi: POI
        let confidence: Double
        let timestamp: Date
        let source: String
    }

    func initialize() async {
        isInitializing = true
        defer { isInitializing = false }

        // Check backend connection
        isBackendConnected = await apiClient.checkHealth()

        // Check permissions
        await checkPermissions()
    }

    func checkPermissions() async {
        // TODO: Implement permission checks
    }

    func reconnectBackend() async {
        isBackendConnected = await apiClient.checkHealth()
    }

    func confirmPOIFromPhoto(_ poi: POI, confidence: Double, source: String = L10n.string("see.source.photoRecognition")) {
        visualConfirmation = VisualPOIConfirmation(
            poi: poi,
            confidence: confidence,
            timestamp: Date(),
            source: source
        )
    }
}
