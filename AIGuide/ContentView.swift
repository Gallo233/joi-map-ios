import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var settingsService = SettingsService.shared
    @State private var selectedTab = Self.initialSelectedTab()
    @State private var showOnboarding = false
    @State private var showSearch = false
    @State private var showTours = false
    @State private var showAR = false
    @State private var showNumberInput = false
    @State private var showIndoor = false
    @State private var didApplyQAOpenActions = false

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

            // Onboarding overlay
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !appState.isBottomNavigationHidden && !showOnboarding {
                AppFloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.isBottomNavigationHidden)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: showOnboarding)
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
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showIndoor) {
            IndoorLocationView()
                .presentationDetents([.large])
        }
        .environment(\.locale, settingsService.language.locale)
        .onAppear {
            if let qaTab = Self.qaInitialSelectedTab {
                guard !didApplyQAOpenActions else { return }
                didApplyQAOpenActions = true
                showOnboarding = false
                selectedTab = qaTab
                showSearch = false
                showNumberInput = Self.opensNumberInputForQA
                showIndoor = Self.opensIndoorForQA
                if Self.opensSearchForQA {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showSearch = true
                    }
                }
                return
            }

            let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            if !hasSeenOnboarding {
                showOnboarding = true
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            }
        }
    }

    private static var opensScanForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_SCAN")
    }

    private static var opensSearchForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_SEARCH")
    }

    private static var opensSettingsForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_SETTINGS")
            || ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_OFFLINE_CONTENT")
    }

    private static var opensTripsForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_TRIPS")
            || ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_TRIP_SEARCH")
    }

    private static var opensNumberInputForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_NUMBER_INPUT")
    }

    private static var opensIndoorForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_INDOOR")
    }

    private static var qaInitialSelectedTab: Int? {
        if opensSettingsForQA { return 3 }
        if opensTripsForQA { return 2 }
        if opensScanForQA { return 1 }
        if opensSearchForQA { return 0 }
        if opensIndoorForQA { return 0 }
        if opensNumberInputForQA { return 0 }
        return nil
    }

    private static func initialSelectedTab() -> Int {
        qaInitialSelectedTab ?? 0
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
                        Text(L10n.string(item.titleKey))
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
                .accessibilityLabel(Text(L10n.string(item.titleKey)))
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
    let titleKey: String
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
private enum BackendConnectionStatus {
    case idle
    case saved
    case checking
    case connected
    case disconnected
    case invalid
    case reset

    var icon: String {
        switch self {
        case .idle:
            return "server.rack"
        case .saved:
            return "checkmark.circle"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .connected:
            return "checkmark.seal.fill"
        case .disconnected:
            return "exclamationmark.triangle.fill"
        case .invalid:
            return "xmark.octagon.fill"
        case .reset:
            return "arrow.counterclockwise.circle"
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .saved, .connected:
            return .green
        case .checking:
            return .blue
        case .disconnected:
            return .orange
        case .invalid:
            return .red
        case .reset:
            return .secondary
        }
    }

    var localizedMessage: String {
        switch self {
        case .idle:
            return L10n.string("settings.backend.status.idle")
        case .saved:
            return L10n.string("settings.backend.status.saved")
        case .checking:
            return L10n.string("settings.backend.status.checking")
        case .connected:
            return L10n.string("settings.backend.status.connected")
        case .disconnected:
            return L10n.string("settings.backend.status.disconnected")
        case .invalid:
            return L10n.string("settings.backend.status.invalidURL")
        case .reset:
            return L10n.string("settings.backend.status.reset")
        }
    }
}

struct SettingsView: View {
    @StateObject private var settingsService = SettingsService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var backendClient = APIClient()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showShareSheet = false
    @State private var showClearCacheAlert = false
    @State private var showResetAlert = false
    @State private var showOfflineContent = false
    @State private var cacheSize = ""
    @State private var backendServerURLDraft = APIConfig.serverURLOverride ?? ""
    @State private var backendStatus: BackendConnectionStatus = .idle
    @State private var backendStatusMessage = BackendConnectionStatus.idle.localizedMessage

    private let bottomNavigationClearance: CGFloat = 128
    private let resetSectionID = "settings-reset-section"
    private let bottomSpacerID = "settings-bottom-spacer"

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
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
                                Text(L10n.string("settings.profile.name"))
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Text(L10n.string("settings.profile.subtitle"))
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

                    // Backend settings
                    Section(L10n.string("settings.backend")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(L10n.string("settings.backend.currentAPI"), systemImage: "network")
                                .font(.subheadline)
                            Text(APIConfig.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            Label(L10n.string("settings.backend.serverURL"), systemImage: "link")
                                .font(.subheadline)
                            TextField(
                                L10n.string("settings.backend.server.placeholder"),
                                text: $backendServerURLDraft
                            )
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        }
                        .padding(.vertical, 2)

                        HStack(spacing: 12) {
                            Button(L10n.string("settings.backend.save")) {
                                saveBackendServerURL()
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                Task {
                                    await checkBackendHealth()
                                }
                            } label: {
                                if backendStatus == .checking {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(L10n.string("settings.backend.check"))
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(backendStatus == .checking)

                            Button(L10n.string("settings.backend.reset")) {
                                resetBackendServerURL()
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.subheadline.weight(.semibold))

                        HStack(spacing: 10) {
                            Image(systemName: backendStatus.icon)
                                .foregroundStyle(backendStatus.color)
                            Text(backendStatusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(L10n.string("settings.backend.help"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    Section(L10n.string("settings.narration")) {
                        Toggle(isOn: $settingsService.autoPlayGuide) {
                            Label(L10n.string("settings.autoPlayGuide"), systemImage: "play.circle")
                        }
                        .onChange(of: settingsService.autoPlayGuide) { _, _ in
                            settingsService.saveSettings()
                        }

                        NavigationLink {
                            VoicePickerView(selectedVoice: $settingsService.preferredVoice)
                        } label: {
                            HStack {
                                Label(L10n.string("settings.voiceSettings"), systemImage: "person.wave.2")
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
                            Label(L10n.string("settings.defaultStyle"), systemImage: "text.quote")
                        }
                        .onChange(of: settingsService.guideStyle) { _, _ in
                            settingsService.saveSettings()
                        }
                    }

                    // Map settings
                    Section(L10n.string("settings.map")) {
                        Picker(selection: $settingsService.mapStyle) {
                            ForEach(SettingsService.MapStyle.allCases, id: \.self) { style in
                                Text(style.localizedTitle).tag(style)
                            }
                        } label: {
                            Label(L10n.string("settings.mapStyle"), systemImage: "map")
                        }
                        .onChange(of: settingsService.mapStyle) { _, _ in
                            settingsService.saveSettings()
                        }
                    }

                    Section(L10n.string("settings.appearance")) {
                        Picker(selection: Binding(
                            get: { themeManager.appearanceMode },
                            set: { themeManager.setAppearanceMode($0) }
                        )) {
                            ForEach(ThemeManager.AppearanceMode.allCases) { mode in
                                Label(mode.title, systemImage: mode.icon).tag(mode)
                            }
                        } label: {
                            Label(L10n.string("settings.interfaceMode"), systemImage: "circle.lefthalf.filled")
                        }
                        .pickerStyle(.menu)
                    }

                    // Download settings
                    Section(L10n.string("settings.download")) {
                        Toggle(isOn: $settingsService.wifiOnlyDownload) {
                            Label(L10n.string("settings.wifiOnly"), systemImage: "wifi")
                        }
                        .onChange(of: settingsService.wifiOnlyDownload) { _, _ in
                            settingsService.saveSettings()
                        }

                        NavigationLink {
                            OfflineContentView()
                        } label: {
                            Label(L10n.string("settings.offlineContent"), systemImage: "arrow.down.circle")
                        }
                    }

                    // Notification settings
                    Section(L10n.string("settings.notifications")) {
                        Toggle(isOn: $settingsService.notificationEnabled) {
                            Label(L10n.string("settings.enableNotifications"), systemImage: "bell")
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
                                Label(L10n.string("settings.enableDailyTips"), systemImage: "lightbulb")
                            }
                        }
                    }

                    // Feedback settings
                    Section(L10n.string("settings.feedback")) {
                        Toggle(isOn: $settingsService.hapticFeedback) {
                            Label(L10n.string("settings.hapticFeedback"), systemImage: "iphone.radiowaves.left.and.right")
                        }
                        .onChange(of: settingsService.hapticFeedback) { _, _ in
                            settingsService.saveSettings()
                        }
                    }

                    // Language settings
                    Section(L10n.string("settings.language")) {
                        Picker(selection: $settingsService.language) {
                            ForEach(SettingsService.AppLanguage.allCases, id: \.self) { lang in
                                Text(lang.localizedTitle).tag(lang)
                            }
                        } label: {
                            Label(L10n.string("settings.language"), systemImage: "globe")
                        }
                        .onChange(of: settingsService.language) { _, _ in
                            settingsService.saveSettings()
                        }
                    }

                    // Cache section
                    Section(L10n.string("settings.storage")) {
                        HStack {
                            Label(L10n.string("settings.cacheSize"), systemImage: "internaldrive")
                            Spacer()
                            Text(cacheSize)
                                .foregroundStyle(.secondary)
                        }

                        Button(action: { showClearCacheAlert = true }) {
                            Label(L10n.string("settings.clearCache"), systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }

                    // About section
                    Section(L10n.string("settings.about")) {
                        NavigationLink {
                            Text(L10n.string("settings.version.value"))
                        } label: {
                            Label(L10n.string("settings.version"), systemImage: "info.circle")
                        }

                        NavigationLink {
                            Text(L10n.string("settings.privacy.placeholder"))
                        } label: {
                            Label(L10n.string("settings.privacyPolicy"), systemImage: "hand.raised")
                        }

                        NavigationLink {
                            Text(L10n.string("settings.terms.placeholder"))
                        } label: {
                            Label(L10n.string("settings.terms"), systemImage: "doc.text")
                        }

                        Button(action: {
                            if let url = URL(string: "mailto:support@aiguide.app") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label(L10n.string("settings.feedback"), systemImage: "envelope")
                        }

                        Button(action: { showShareSheet = true }) {
                            Label(L10n.string("settings.recommend"), systemImage: "square.and.arrow.up")
                        }
                    }

                    // Reset section
                    Section {
                        Button(action: { showResetAlert = true }) {
                            Label(L10n.string("settings.resetAll"), systemImage: "arrow.counterclockwise")
                                .foregroundStyle(.red)
                        }

                        Button(action: {
                            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        }) {
                            Label(L10n.string("settings.showOnboarding"), systemImage: "questionmark.circle")
                        }
                    }
                    .id(resetSectionID)

                    Color.clear
                        .frame(height: bottomNavigationClearance)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityHidden(true)
                        .id(bottomSpacerID)
                }
                .navigationTitle(L10n.string("settings.title"))
                .onAppear {
                    cacheSize = settingsService.getCacheSize()
                    backendServerURLDraft = APIConfig.serverURLOverride ?? ""
                    backendStatusMessage = backendStatus.localizedMessage
                    scrollToBottomIfNeeded(using: scrollProxy)
                }
                .alert(L10n.string("settings.clearCache"), isPresented: $showClearCacheAlert) {
                    Button(L10n.string("common.cancel"), role: .cancel) {}
                    Button(L10n.string("settings.clear"), role: .destructive) {
                        settingsService.clearCache()
                        cacheSize = "0 MB"
                    }
                } message: {
                    Text(L10n.string("settings.alert.clearCache.message"))
                }
                .alert(L10n.string("settings.resetAll"), isPresented: $showResetAlert) {
                    Button(L10n.string("common.cancel"), role: .cancel) {}
                    Button(L10n.string("settings.reset"), role: .destructive) {
                        settingsService.resetSettings()
                    }
                } message: {
                    Text(L10n.string("settings.alert.reset.message"))
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(items: [
                        L10n.string("settings.share.message"),
                        URL(string: "https://apps.apple.com/app/aiguide")!
                    ])
                }
                .sheet(isPresented: $showOfflineContent) {
                    NavigationStack {
                        OfflineContentView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(L10n.string("common.done")) {
                                        showOfflineContent = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    private static var opensOfflineContentForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_OFFLINE_CONTENT")
    }

    private static var scrollsToBottomForQA: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_SCROLL_SETTINGS_BOTTOM")
    }

    private func scrollToBottomIfNeeded(using proxy: ScrollViewProxy) {
        if Self.opensOfflineContentForQA {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                showOfflineContent = true
            }
        }

        guard Self.scrollsToBottomForQA else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            proxy.scrollTo(bottomSpacerID, anchor: .bottom)
        }
    }

    @discardableResult
    private func saveBackendServerURL() -> Bool {
        guard APIConfig.setServerURLOverride(backendServerURLDraft) else {
            backendStatus = .invalid
            backendStatusMessage = backendStatus.localizedMessage
            return false
        }

        backendServerURLDraft = APIConfig.serverURLOverride ?? ""
        backendStatus = backendServerURLDraft.isEmpty ? .reset : .saved
        backendStatusMessage = backendStatus.localizedMessage
        return true
    }

    private func resetBackendServerURL() {
        APIConfig.clearServerURLOverride()
        backendServerURLDraft = ""
        backendStatus = .reset
        backendStatusMessage = backendStatus.localizedMessage
    }

    private func checkBackendHealth() async {
        guard saveBackendServerURL() else { return }
        backendStatus = .checking
        backendStatusMessage = backendStatus.localizedMessage

        if await backendClient.checkHealth() {
            backendStatus = .connected
            backendStatusMessage = backendStatus.localizedMessage
        } else {
            backendStatus = .disconnected
            backendStatusMessage = backendClient.lastError?.localizedDescription ?? backendStatus.localizedMessage
        }
    }
}

private struct OfflineContentView: View {
    @StateObject private var settingsService = SettingsService.shared
    @State private var cacheSize = ""
    @State private var lastUpdated = Date()
    @State private var showClearCacheAlert = false

    var body: some View {
        List {
            Section(L10n.string("offline.content.status")) {
                OfflineStatusRow(
                    icon: "map.fill",
                    titleKey: "offline.content.localGuide.title",
                    subtitleKey: "offline.content.localGuide.subtitle",
                    badgeKey: "offline.content.ready",
                    tint: Color(red: 0.12, green: 0.40, blue: 0.24)
                )

                OfflineStatusRow(
                    icon: "internaldrive.fill",
                    titleKey: "offline.content.cache.title",
                    subtitleKey: "offline.content.cache.subtitle",
                    badgeText: cacheSize,
                    tint: .blue
                )
            }

            Section(L10n.string("offline.content.settings")) {
                Toggle(isOn: $settingsService.wifiOnlyDownload) {
                    Label(L10n.string("settings.wifiOnly"), systemImage: "wifi")
                }
                .onChange(of: settingsService.wifiOnlyDownload) { _, _ in
                    settingsService.saveSettings()
                }

                Toggle(isOn: $settingsService.offlineMode) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(L10n.string("offline.content.preferOffline"), systemImage: "wifi.slash")
                        Text(L10n.string("offline.content.preferOffline.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: settingsService.offlineMode) { _, _ in
                    settingsService.saveSettings()
                }
            }

            Section(L10n.string("offline.content.storage")) {
                HStack {
                    Label(L10n.string("settings.cacheSize"), systemImage: "externaldrive")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label(L10n.string("offline.content.lastUpdated"), systemImage: "clock")
                    Spacer()
                    Text(Self.timeString(from: lastUpdated))
                        .foregroundStyle(.secondary)
                }

                Button {
                    refreshCacheSize()
                } label: {
                    Label(L10n.string("offline.content.refresh"), systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    showClearCacheAlert = true
                } label: {
                    Label(L10n.string("settings.clearCache"), systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(L10n.string("settings.offlineContent"))
        .onAppear(perform: refreshCacheSize)
        .alert(L10n.string("settings.clearCache"), isPresented: $showClearCacheAlert) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("settings.clear"), role: .destructive) {
                settingsService.clearCache()
                refreshCacheSize()
            }
        } message: {
            Text(L10n.string("settings.alert.clearCache.message"))
        }
    }

    private func refreshCacheSize() {
        cacheSize = settingsService.getCacheSize()
        lastUpdated = Date()
    }

    private static func timeString(from date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

private struct OfflineStatusRow: View {
    let icon: String
    let titleKey: String
    let subtitleKey: String
    let badgeKey: String?
    let badgeText: String?
    let tint: Color

    init(
        icon: String,
        titleKey: String,
        subtitleKey: String,
        badgeKey: String? = nil,
        badgeText: String? = nil,
        tint: Color
    ) {
        self.icon = icon
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.badgeKey = badgeKey
        self.badgeText = badgeText
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.string(titleKey))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Text(L10n.string(subtitleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }

    private var badge: String? {
        if let badgeText {
            return badgeText
        }
        if let badgeKey {
            return L10n.string(badgeKey)
        }
        return nil
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
    let labelKey: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(L10n.string(labelKey))
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
