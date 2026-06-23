import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settingsService = SettingsService.shared
    @State private var selectedTab = 0
    @State private var showOnboarding = false
    @State private var showSearch = false
    @State private var showTours = false
    @State private var showAR = false
    @State private var showNumberInput = false
    @State private var showIndoor = false

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case 0:
                GuideTabView(
                    showSearch: $showSearch,
                    showTours: $showTours,
                    showAR: $showAR,
                    showNumberInput: $showNumberInput,
                    showIndoor: $showIndoor
                )
                case 1:
                SeeAndAskView()
                case 2:
                TripPlannerView()
                default:
                SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                AppFloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .opacity(appState.isBottomNavigationHidden ? 0 : 1)
                    .offset(y: appState.isBottomNavigationHidden ? 96 : 0)
                    .scaleEffect(appState.isBottomNavigationHidden ? 0.96 : 1, anchor: .bottom)
                    .allowsHitTesting(!appState.isBottomNavigationHidden)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.isBottomNavigationHidden)
            }
            .ignoresSafeArea(.keyboard)
            .zIndex(0.5)

            // Onboarding overlay
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView()
        }
        .sheet(isPresented: $showTours) {
            TourListView()
        }
        .fullScreenCover(isPresented: $showAR) {
            ARGuideView()
        }
        .sheet(isPresented: $showNumberInput) {
            NumberInputView()
        }
        .sheet(isPresented: $showIndoor) {
            IndoorLocationView()
        }
        .environment(\.locale, settingsService.language.locale)
        .onAppear {
            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            if !hasSeenOnboarding {
                showOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            }
        }
    }
}

// MARK: - Floating Tab Bar
private struct AppFloatingTabBar: View {
    @Binding var selectedTab: Int

    private let items: [AppTabItem] = [
        AppTabItem(index: 0, titleKey: "tab.guide", icon: "map.fill"),
        AppTabItem(index: 1, titleKey: "tab.see", icon: "eye.fill"),
        AppTabItem(index: 2, titleKey: "tab.trip", icon: "book.fill"),
        AppTabItem(index: 3, titleKey: "tab.settings", icon: "gearshape.fill")
    ]

    private let accent = Color(red: 0.12, green: 0.40, blue: 0.24)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = item.index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(item.titleKey)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(selectedTab == item.index ? accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background {
                        if selectedTab == item.index {
                            Capsule(style: .continuous)
                                .fill(accent.opacity(0.11))
                                .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(item.titleKey))
                .accessibilityAddTraits(selectedTab == item.index ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }

    @Namespace private var tabNamespace
}

private struct AppTabItem: Identifiable {
    let index: Int
    let titleKey: LocalizedStringKey
    let icon: String

    var id: Int { index }
}

// MARK: - Guide Tab View
struct GuideTabView: View {
    @Binding var showSearch: Bool
    @Binding var showTours: Bool
    @Binding var showAR: Bool
    @Binding var showNumberInput: Bool
    @Binding var showIndoor: Bool

    var body: some View {
        GuideView(
            onSearch: { showSearch = true },
            onTours: { showTours = true },
            onAR: { showAR = true },
            onNumberInput: { showNumberInput = true },
            onIndoor: { showIndoor = true }
        )
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var notificationService = NotificationService.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showShareSheet = false
    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    @State private var cacheSize = ""

    var body: some View {
        NavigationStack {
            List {
                // User profile section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(.blue.gradient)
                                .frame(width: 60, height: 60)

                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.profile.name")
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("settings.profile.subtitle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Stats section
                Section {
                    HStack {
                        StatItem(value: "\(historyService.totalVisits)", labelKey: "settings.stat.visits", icon: "map.fill")
                        StatItem(value: "\(historyService.uniquePOIsVisited)", labelKey: "settings.stat.places", icon: "building.2.fill")
                        StatItem(value: "\(historyService.favoritePOIs.count)", labelKey: "settings.stat.favorites", icon: "heart.fill")
                    }
                    .padding(.vertical, 8)
                }

                // Guide settings
                Section("settings.narration") {
                    Toggle(isOn: $settingsService.autoPlayGuide) {
                        Label("settings.autoPlayGuide", systemImage: "play.circle")
                    }
                    .onChange(of: settingsService.autoPlayGuide) { _, _ in
                        settingsService.saveSettings()
                    }

                    NavigationLink {
                        VoicePickerView(selectedVoice: $settingsService.preferredVoice)
                    } label: {
                        HStack {
                            Label("settings.voiceSettings", systemImage: "person.wave.2")
                            Spacer()
                            Text(settingsService.preferredVoice.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker(selection: $settingsService.guideStyle) {
                        ForEach(GuideStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    } label: {
                        Label("settings.defaultStyle", systemImage: "text.quote")
                    }
                    .onChange(of: settingsService.guideStyle) { _, _ in
                        settingsService.saveSettings()
                    }
                }

                // Map settings
                Section("settings.map") {
                    Picker(selection: $settingsService.mapStyle) {
                        ForEach(SettingsService.MapStyle.allCases, id: \.self) { style in
                            Text(style.localizedTitle).tag(style)
                        }
                    } label: {
                        Label("settings.mapStyle", systemImage: "map")
                    }
                    .onChange(of: settingsService.mapStyle) { _, _ in
                        settingsService.saveSettings()
                    }
                }

                Section("settings.appearance") {
                    Picker(selection: Binding(
                        get: { themeManager.appearanceMode },
                        set: { themeManager.setAppearanceMode($0) }
                    )) {
                        ForEach(ThemeManager.AppearanceMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.icon).tag(mode)
                        }
                    } label: {
                        Label("settings.interfaceMode", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                }

                // Download settings
                Section("settings.download") {
                    Toggle(isOn: $settingsService.wifiOnlyDownload) {
                        Label("settings.wifiOnly", systemImage: "wifi")
                    }
                    .onChange(of: settingsService.wifiOnlyDownload) { _, _ in
                        settingsService.saveSettings()
                    }

                    NavigationLink {
                        Text("settings.offlineContent.placeholder")
                    } label: {
                        Label("settings.offlineContent", systemImage: "arrow.down.circle")
                    }
                }

                // Notification settings
                Section("settings.notifications") {
                    Toggle(isOn: $settingsService.notificationEnabled) {
                        Label("settings.enableNotifications", systemImage: "bell")
                    }
                    .onChange(of: settingsService.notificationEnabled) { _, newValue in
                        settingsService.saveSettings()
                        if newValue {
                            Task {
                                _ = await notificationService.requestPermission()
                            }
                        }
                    }

                    if settingsService.notificationEnabled {
                        Button(action: {
                            notificationService.scheduleDailyTip()
                        }) {
                            Label("settings.enableDailyTips", systemImage: "lightbulb")
                        }
                    }
                }

                // Feedback settings
                Section("settings.feedback") {
                    Toggle(isOn: $settingsService.hapticFeedback) {
                        Label("settings.hapticFeedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .onChange(of: settingsService.hapticFeedback) { _, _ in
                        settingsService.saveSettings()
                    }
                }

                // Language settings
                Section("settings.language") {
                    Picker(selection: $settingsService.language) {
                        ForEach(SettingsService.AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.localizedTitleKey).tag(lang)
                        }
                    } label: {
                        Label("settings.language", systemImage: "globe")
                    }
                    .onChange(of: settingsService.language) { _, _ in
                        settingsService.saveSettings()
                    }
                }

                // Cache section
                Section("settings.storage") {
                    HStack {
                        Label("settings.cacheSize", systemImage: "internaldrive")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { showClearCacheAlert = true }) {
                        Label("settings.clearCache", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // About section
                Section("settings.about") {
                    NavigationLink {
                        Text("settings.version.value")
                    } label: {
                        Label("settings.version", systemImage: "info.circle")
                    }

                    NavigationLink {
                        Text("settings.privacy.placeholder")
                    } label: {
                        Label("settings.privacyPolicy", systemImage: "hand.raised")
                    }

                    NavigationLink {
                        Text("settings.terms.placeholder")
                    } label: {
                        Label("settings.terms", systemImage: "doc.text")
                    }

                    Button(action: {
                        if let url = URL(string: "mailto:support@aiguide.app") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("settings.feedback", systemImage: "envelope")
                    }

                    Button(action: { showShareSheet = true }) {
                        Label("settings.recommend", systemImage: "square.and.arrow.up")
                    }
                }

                // Reset section
                Section {
                    Button(action: { showResetAlert = true }) {
                        Label("settings.resetAll", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }

                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                    }) {
                        Label("settings.showOnboarding", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("settings.title")
            .onAppear {
                cacheSize = settingsService.getCacheSize()
            }
            .alert("settings.clearCache", isPresented: $showClearCacheAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.clear", role: .destructive) {
                    settingsService.clearCache()
                    cacheSize = "0 MB"
                }
            } message: {
                Text("settings.alert.clearCache.message")
            }
            .alert("settings.resetAll", isPresented: $showResetAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.reset", role: .destructive) {
                    settingsService.resetSettings()
                }
            } message: {
                Text("settings.alert.reset.message")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [
                    L10n.string("settings.share.message"),
                    URL(string: "https://apps.apple.com/app/aiguide")!
                ])
            }
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let labelKey: LocalizedStringKey
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(labelKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ThemeManager.shared)
}
