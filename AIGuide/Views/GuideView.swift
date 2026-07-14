// Guide View - Optimized Layout

import SwiftUI
import MapKit
import UIKit
import AVFoundation
import Speech

struct GuideView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var joiSession: JoiCharacterSession
    @StateObject private var guideVM = GuideViewModel()
    @State private var sheetType: SheetType?
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var showPOIIntro = false
    @State private var showMapModeSheet = false
    @State private var isMap3D = true
    @State private var mapMode: GuideMapMode = .explore
    @GestureState private var sheetDragTranslation: CGFloat = 0

    var onSearch: () -> Void = {}
    var onTours: () -> Void = {}
    var onAR: () -> Void = {}
    var onNumberInput: () -> Void = {}
    var onIndoor: () -> Void = {}

    enum SheetPosition: Equatable {
        case collapsed
        case half
        case expanded
    }

    enum SheetType: Identifiable {
        case ask, answer, route, source, style, roadmap, correct, voice

        var id: String {
            switch self {
            case .ask: return "ask"
            case .answer: return "answer"
            case .route: return "route"
            case .source: return "source"
            case .style: return "style"
            case .roadmap: return "roadmap"
            case .correct: return "correct"
            case .voice: return "voice"
            }
        }
    }

    // MARK: - Colors
    let primaryColor = Color(red: 0.85, green: 0.35, blue: 0.15)
    let secondaryColor = Color(red: 0.95, green: 0.75, blue: 0.2)

    var body: some View {
        GeometryReader { geometry in
            let sheetHeight = currentSheetHeight(in: geometry)
            let bottomClearance = bottomChromeClearance(in: geometry)
            let mapHeight = mapAreaHeight(
                in: geometry,
                sheetHeight: sheetHeight,
                bottomClearance: bottomClearance
            )

            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    mapPanel(height: mapHeight)
                    Spacer()
                }

                // Bottom sheet
                bottomSheet
                    .frame(height: sheetHeight)
                    .padding(.bottom, bottomClearance)
                    .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.86), value: sheetPosition)
                    .gesture(sheetDragGesture(in: geometry))
            }
        }
        .sheet(item: $sheetType) { type in
            switch type {
            case .ask:
                AskSheetView(guideVM: guideVM)
            case .answer:
                AnswerSheetView()
            case .route:
                RouteSheetView(route: guideVM.currentRoute)
            case .source:
                SourceSheetView(source: guideVM.currentGuide?.source)
            case .style:
                StyleSheetView(selectedStyle: $guideVM.selectedStyle)
            case .roadmap:
                RoadmapSheetView()
            case .correct:
                CorrectSheetView(
                    pois: guideVM.nearbyPOIs,
                    currentPOI: guideVM.currentPOI,
                    currentLocation: guideVM.currentUserLocation,
                    onSelect: { poi in
                        guideVM.selectPOI(poi)
                    },
                    onCreate: { name, description in
                        guideVM.addCustomPOI(name: name, description: description)
                    }
                )
            case .voice:
                VoicePickerView(selectedVoice: $guideVM.selectedVoice) {
                    guideVM.changeVoice(guideVM.selectedVoice)
                }
            }
        }
        .sheet(isPresented: $showMapModeSheet) {
            GuideMapModeSheet(selectedMode: $mapMode)
                .presentationDetents([.height(318)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(
            isPresented: $showPOIIntro,
            onDismiss: {
                updateBottomNavigationVisibility(for: sheetPosition)
            }
        ) {
            POIIntroChatView(
                guideVM: guideVM,
                accent: primaryColor,
                onClose: {
                    showPOIIntro = false
                }
            )
        }
        .onAppear {
            guideVM.startLocationUpdates()
            updateBottomNavigationVisibility(for: sheetPosition)
            syncJoiSession()
        }
        .task {
            await guideVM.loadPOIs()
            await guideVM.checkBackendConnection()
        }
        .onDisappear {
            guideVM.stopLocationUpdates()
            updateBottomNavigationVisibility(for: .collapsed)
        }
        .onChange(of: sheetPosition) { _, newPosition in
            updateBottomNavigationVisibility(for: newPosition)
        }
        .onChange(of: appState.visualConfirmation?.id) { _, _ in
            guard let confirmation = appState.visualConfirmation else { return }
            guideVM.applyVisualConfirmation(confirmation)
        }
        .onChange(of: guideVM.contextPhase) { _, _ in
            syncJoiSession()
        }
        .onChange(of: guideVM.isLoading) { _, _ in
            syncJoiSession()
        }
        .onChange(of: guideVM.isPlaying) { _, _ in
            syncJoiSession()
        }
        .onChange(of: guideVM.currentPOI?.id) { _, _ in
            syncJoiSession()
        }
    }

    private func mapPanel(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            MapViewContainer(
                currentPOI: guideVM.currentPOI,
                initialRegion: guideVM.region,
                route: guideVM.currentRoute,
                nearbyPOIs: guideVM.nearbyPOIs,
                mapType: mapMode.mapType,
                isMap3D: isMap3D,
                onUserLocationUpdate: { location in
                    guideVM.updateFromMapUserLocation(location)
                }
            )
            .frame(height: height)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(.systemGroupedBackground).opacity(0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 34)
                .allowsHitTesting(false)
            }

            topBar

            mapControlStack
                .padding(.trailing, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(sheetPosition == .collapsed ? 1 : 0)
                .allowsHitTesting(sheetPosition == .collapsed)
                .animation(.easeInOut(duration: 0.16), value: sheetPosition)
        }
        .frame(height: height)
        .clipped()
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 8) {
            mapWeatherBadge

            Button(action: onSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(L10n.string("guide.search.placeholder"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 4)

                    Image(systemName: "mic.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.72))
                }
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.42), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("guide.search.placeholder"))

            connectionStatusPill
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var mapWeatherBadge: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "cloud.sun.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text(L10n.string("guide.weather.temperature.placeholder"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            HStack(spacing: 4) {
                Text(L10n.string("guide.weather.aqi.placeholder"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 74, height: 52, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.42), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var connectionStatusPill: some View {
        HStack(spacing: 4) {
            Image(systemName: guideVM.isConnectedToBackend ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.caption2.weight(.semibold))
            Text(guideVM.isConnectedToBackend ? L10n.string("guide.connected") : L10n.string("guide.localMode"))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(guideVM.isConnectedToBackend ? .green : Color(red: 0.12, green: 0.40, blue: 0.24))
        .padding(.horizontal, 9)
        .frame(height: 36)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.42), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Route Status Overlay
    private var routeStatusOverlay: some View {
        Button {
            sheetType = .route
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.40, blue: 0.24).opacity(0.12))
                    Image(systemName: "figure.walk")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.24))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(guideVM.currentRoute.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(routeProgressText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(primaryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(primaryColor.opacity(0.08), in: Capsule())
                    }

                    HStack(spacing: 8) {
                        ProgressView(value: routeCompletionFraction)
                            .tint(Color(red: 0.12, green: 0.40, blue: 0.24))
                            .frame(width: 96)

                        Text(routeRemainingText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("guide.nextStop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(nextStopTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.format("guide.viewRoute.format", guideVM.currentRoute.name))
    }

    // MARK: - Map Controls
    private var mapControlStack: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isMap3D.toggle()
                }
            } label: {
                Text(isMap3D ? "2D" : "3D")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("guide.mapMode.toggle3D"))

            Button {
                showMapModeSheet = true
            } label: {
                Image(systemName: "map.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.24))
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("guide.mapMode.open"))
        }
    }

    private var workbenchActions: [(icon: String, title: String, color: Color, action: () -> Void)] {
        [
            ("map", L10n.string("guide.workbench.route"), Color(red: 0.12, green: 0.40, blue: 0.24), onTours),
            ("arkit", L10n.string("guide.workbench.arScan"), primaryColor, onAR),
            ("number", L10n.string("guide.workbench.number"), .blue, onNumberInput),
            ("building.2", L10n.string("guide.workbench.indoor"), .purple, onIndoor)
        ]
    }

    private func currentSheetHeight(in geometry: GeometryProxy) -> CGFloat {
        let baseHeight = sheetHeight(for: sheetPosition, in: geometry)
        let liveHeight = baseHeight - sheetDragTranslation
        return min(max(liveHeight, minSheetHeight(in: geometry)), maxSheetHeight(in: geometry))
    }

    private func sheetHeight(for position: SheetPosition, in geometry: GeometryProxy) -> CGFloat {
        let availableHeight = availableSheetArea(in: geometry)

        switch position {
        case .collapsed:
            return min(max(228, availableHeight * 0.29), 252)
        case .half:
            return min(max(368, availableHeight * 0.48), maxSheetHeight(in: geometry))
        case .expanded:
            return maxSheetHeight(in: geometry)
        }
    }

    private func minSheetHeight(in geometry: GeometryProxy) -> CGFloat {
        let availableHeight = availableSheetArea(in: geometry)
        return min(max(104, availableHeight * 0.13), maxSheetHeight(in: geometry))
    }

    private func maxSheetHeight(in geometry: GeometryProxy) -> CGFloat {
        let availableHeight = availableSheetArea(in: geometry)
        return min(availableHeight * 0.78, availableHeight - geometry.safeAreaInsets.top - 56)
    }

    private func availableSheetArea(in geometry: GeometryProxy) -> CGFloat {
        max(360, geometry.size.height - bottomChromeClearance(in: geometry))
    }

    private func mapAreaHeight(in geometry: GeometryProxy, sheetHeight: CGFloat, bottomClearance: CGFloat) -> CGFloat {
        let sheetTop = geometry.size.height - sheetHeight - bottomClearance
        let minimumHeight = min(360, geometry.size.height * 0.54)
        let maximumHeight = geometry.size.height * 0.68
        return min(max(sheetTop + 10, minimumHeight), maximumHeight)
    }

    private func bottomChromeClearance(in geometry: GeometryProxy) -> CGFloat {
        guard sheetPosition != .collapsed else { return 8 }

        let bottomInset = geometry.safeAreaInsets.bottom
        return max(12, bottomInset + 8)
    }

    private func nearestSheetPosition(for projectedHeight: CGFloat, in geometry: GeometryProxy) -> SheetPosition {
        let targets: [(position: SheetPosition, height: CGFloat)] = [
            (.collapsed, sheetHeight(for: .collapsed, in: geometry)),
            (.half, sheetHeight(for: .half, in: geometry)),
            (.expanded, sheetHeight(for: .expanded, in: geometry))
        ]

        return targets.min { first, second in
            abs(first.height - projectedHeight) < abs(second.height - projectedHeight)
        }?.position ?? sheetPosition
    }

    private func sheetDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .updating($sheetDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let baseHeight = sheetHeight(for: sheetPosition, in: geometry)
                let projectedHeight = baseHeight - value.predictedEndTranslation.height

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                    let targetPosition = nearestSheetPosition(for: projectedHeight, in: geometry)
                    if targetPosition != sheetPosition {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    sheetPosition = targetPosition
                }
            }
    }

    // MARK: - Bottom Sheet
    private var bottomSheet: some View {
        VStack(spacing: 0) {
            drawerHandle
            drawerBody
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, y: -6)
        .contentShape(Rectangle())
    }

    private var drawerHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.28))
                .frame(width: 42, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, isMiniDrawer ? 4 : 10)
        .contentShape(Rectangle())
        .onTapGesture {
            advanceSheet()
        }
    }

    @ViewBuilder
    private var drawerBody: some View {
        if isMiniDrawer {
            miniDrawerContent
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            detailDrawerContent
                .transition(.opacity)
        }
    }

    private var miniDrawerContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(primaryColor.opacity(0.12))
                    JoiCharacterView(session: joiSession, framing: .avatar)
                        .allowsHitTesting(false)
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(primaryColor.opacity(0.16), lineWidth: 1)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(miniStatusText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(routeProgressText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(primaryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(primaryColor.opacity(0.08), in: Capsule())
                    }

                    Text(guideVM.currentPOI?.name ?? L10n.string("guide.locating"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("\(L10n.string("guide.nextStop")) \(nextStopTitle) · \(nextStopDistanceText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                .contentShape(Rectangle())
                .onTapGesture {
                    advanceSheet()
                }

                Spacer(minLength: 4)

                Button(action: { advanceSheet() }) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(primaryColor)
                        .frame(width: 38, height: 38)
                        .background(primaryColor.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("guide.expandDetails"))

                Button(action: { guideVM.togglePlayback() }) {
                    Image(systemName: guideVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(primaryColor, in: Circle())
                        .shadow(color: primaryColor.opacity(0.22), radius: 8, y: 4)
                }
                .accessibilityLabel(guideVM.isPlaying ? L10n.string("guide.pauseNarration") : L10n.string("guide.playNarration"))
            }

            miniRouteProgressRow
            workbenchToolRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    private var miniRouteProgressRow: some View {
        Button {
            sheetType = .route
        } label: {
            HStack(spacing: 10) {
                Text(routeProgressText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(primaryColor.opacity(0.09), in: Capsule())

                ProgressView(value: routeCompletionFraction)
                    .tint(Color(red: 0.12, green: 0.40, blue: 0.24))
                    .frame(maxWidth: .infinity)

                Text(nextStopTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.format("guide.viewRoute.format", guideVM.currentRoute.name))
    }

    private var workbenchToolRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(workbenchActions.enumerated()), id: \.offset) { _, item in
                WorkbenchToolButton(
                    title: item.title,
                    icon: item.icon,
                    color: item.color,
                    action: item.action
                )
            }
        }
    }

    private var detailDrawerContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                joiGuideCompanionRow
                currentPOISection
                drawerActionRow
                confidenceSection

                if showsFullSections {
                    playerSection
                    sourceSection
                } else {
                    compactPlayerSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    private var joiGuideCompanionRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(primaryColor.opacity(0.08))

                JoiCharacterView(session: joiSession, framing: .bust)
                    .allowsHitTesting(false)
            }
            .frame(width: 78, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text("Joi")
                        .font(.headline.weight(.bold))

                    Text(L10n.string("joi.guide.companion"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(primaryColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(primaryColor.opacity(0.09), in: Capsule())

                    Spacer(minLength: 0)

                    if joiSession.isSpeaking {
                        Image(systemName: "waveform")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(primaryColor)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    }
                }

                Text(L10n.string(joiSession.messageKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(primaryColor.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var isMiniDrawer: Bool {
        sheetPosition == .collapsed && sheetDragTranslation > -88
    }

    private var showsFullSections: Bool {
        sheetPosition == .expanded || sheetDragTranslation < -72
    }

    private var miniStatusText: String {
        if guideVM.confidenceList.isEmpty {
            return contextPhaseTitle
        }
        if guideVM.topConfidence < 0.45 {
            return L10n.string("guide.calibratingLocation")
        }
        return guideVM.positioningSummary
    }

    private var contextPhaseTitle: String {
        switch guideVM.contextPhase {
        case .locating:
            return L10n.string("guide.locating")
        case .nearbyMatch:
            return L10n.string("guide.matchedNearby")
        case .visualConfirmed:
            return L10n.string("guide.photoConfirmed")
        case .manual:
            return L10n.string("guide.manualCalibration")
        case .recommending:
            return L10n.string("guide.findingNearby")
        case .recommended:
            return L10n.string("guide.nearbyRecommended")
        case .empty:
            return L10n.string("guide.nearbyEmpty")
        case .offline:
            return L10n.string("guide.offlineMode")
        }
    }

    private var contextPhaseIcon: String {
        switch guideVM.contextPhase {
        case .locating:
            return "location"
        case .nearbyMatch:
            return "location.fill"
        case .visualConfirmed:
            return "camera.viewfinder"
        case .manual:
            return "scope"
        case .recommending:
            return "magnifyingglass"
        case .recommended:
            return "star.circle.fill"
        case .empty:
            return "mappin.slash"
        case .offline:
            return "wifi.slash"
        }
    }

    private var contextPhaseColor: Color {
        switch guideVM.contextPhase {
        case .locating, .recommending:
            return .blue
        case .nearbyMatch, .visualConfirmed, .manual:
            return Color(red: 0.12, green: 0.40, blue: 0.24)
        case .recommended:
            return primaryColor
        case .empty, .offline:
            return .secondary
        }
    }

    private var emptyConfidenceMessage: String {
        switch guideVM.contextPhase {
        case .locating:
            return L10n.string("guide.empty.gps")
        case .recommending:
            return L10n.string("guide.empty.searching")
        case .empty:
            return L10n.string("guide.empty.move")
        case .offline:
            return L10n.string("guide.empty.offline")
        default:
            return L10n.string("guide.empty.signals")
        }
    }

    private func advanceSheet() {
        let next: SheetPosition
        switch sheetPosition {
        case .collapsed:
            next = .half
        case .half:
            next = .expanded
        case .expanded:
            next = .half
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
            sheetPosition = next
        }
    }

    private func syncJoiSession() {
        joiSession.syncGuide(
            phase: guideVM.contextPhase,
            isLoading: guideVM.isLoading,
            isSpeaking: guideVM.isPlaying,
            hasPOI: guideVM.currentPOI != nil
        )
    }

    private func updateBottomNavigationVisibility(for position: SheetPosition) {
        let shouldHide = position != .collapsed
        guard appState.isBottomNavigationHidden != shouldHide else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            appState.isBottomNavigationHidden = shouldHide
        }
    }

    private var drawerActionRow: some View {
        HStack(spacing: 8) {
            DrawerActionButton(title: L10n.string("guide.ask"), icon: "mic.fill", color: primaryColor) {
                openPOIIntro()
            }

            DrawerActionButton(title: L10n.string("guide.source"), icon: "shield.checkered", color: Color(red: 0.12, green: 0.40, blue: 0.24)) {
                sheetType = .source
            }

            DrawerActionButton(title: L10n.string("guide.correct"), icon: "scope", color: .blue) {
                sheetType = .correct
            }
            .disabled(guideVM.nearbyPOIs.isEmpty)
            .opacity(guideVM.nearbyPOIs.isEmpty ? 0.45 : 1)

            DrawerActionButton(title: L10n.string("guide.style"), icon: "slider.horizontal.3", color: .purple) {
                sheetType = .style
            }
        }
    }

    private func openPOIIntro() {
        guard guideVM.currentPOI != nil else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            appState.isBottomNavigationHidden = true
        }
        showPOIIntro = true
    }

    // MARK: - Current POI Section
    private var currentPOISection: some View {
        Button {
            openPOIIntro()
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Status
                    HStack(spacing: 6) {
                        Image(systemName: contextPhaseIcon)
                            .font(.caption)
                            .foregroundStyle(contextPhaseColor)
                        Text(contextPhaseTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(contextPhaseColor)
                            .lineLimit(1)

                        Text(routeProgressText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(primaryColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(primaryColor.opacity(0.08), in: Capsule())
                    }

                    // POI Name
                    Text(guideVM.currentPOI?.name ?? L10n.string("guide.findingNearbyPOI"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    // Description
                    Text(guideVM.currentPOI?.description ?? L10n.string("guide.findingNearbyPOIDesc"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if guideVM.isRefreshingNearbyPlaces {
                            ProgressView()
                                .controlSize(.mini)
                        }

                        Text(guideVM.positioningSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if guideVM.currentPOI != nil {
                            Label("guide.viewIntro", systemImage: "arrow.up.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(primaryColor)
                        }
                    }
                }
                .layoutPriority(1)

                Spacer()

                // Next stop
                VStack(spacing: 4) {
                    Text("guide.nextStop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(nextStopTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                        Text(nextStopDistanceText)
                            .font(.caption2)
                    }
                    .foregroundStyle(primaryColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(primaryColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 96)
            }
        }
        .buttonStyle(.plain)
        .disabled(guideVM.currentPOI == nil)
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var nextRouteStop: RouteStop? {
        guard let currentPOI = guideVM.currentPOI,
              let currentIndex = guideVM.currentRoute.stops.firstIndex(where: { $0.poiId == currentPOI.id }) else {
            return guideVM.currentRoute.stops.first { $0.state == .upcoming }
        }

        let nextIndex = guideVM.currentRoute.stops.index(after: currentIndex)
        guard nextIndex < guideVM.currentRoute.stops.endIndex else { return nil }
        return guideVM.currentRoute.stops[nextIndex]
    }

    private var nextStopTitle: String {
        if let nextRouteStop {
            return nextRouteStop.name
        }
        return guideVM.currentRoute.stops.isEmpty ? L10n.string("guide.nearbyRecommended") : L10n.string("trip.detail.routeWrap")
    }

    private var nextStopDistanceText: String {
        guard let distance = nextRouteStop?.distanceFromPrevious else { return L10n.string("guide.arrived") }
        return "\(Int(distance))m"
    }

    private var routeProgressText: String {
        guard !guideVM.currentRoute.stops.isEmpty else {
            return L10n.string("guide.searching")
        }

        guard let currentPOI = guideVM.currentPOI,
              let currentIndex = guideVM.currentRoute.stops.firstIndex(where: { $0.poiId == currentPOI.id }) else {
            return L10n.string("guide.onRoute")
        }

        return L10n.format("guide.routeProgress", currentIndex + 1, guideVM.currentRoute.stops.count)
    }

    private var routeCompletionFraction: Double {
        guard !guideVM.currentRoute.stops.isEmpty else { return 0 }
        guard let currentPOI = guideVM.currentPOI,
              let currentIndex = guideVM.currentRoute.stops.firstIndex(where: { $0.poiId == currentPOI.id }) else {
            return 0
        }

        return min(1, Double(currentIndex + 1) / Double(guideVM.currentRoute.stops.count))
    }

    private var routeRemainingText: String {
        guard !guideVM.currentRoute.stops.isEmpty else {
            return L10n.string("guide.waitingLocation")
        }

        guard let currentPOI = guideVM.currentPOI,
              let currentIndex = guideVM.currentRoute.stops.firstIndex(where: { $0.poiId == currentPOI.id }) else {
            return L10n.string("guide.searchingRoute")
        }

        let remainingStops = guideVM.currentRoute.stops.dropFirst(currentIndex + 1)
        let remainingDistance = remainingStops.compactMap(\.distanceFromPrevious).reduce(0, +)
        guard remainingDistance > 0 else { return L10n.string("guide.arrivedDestination") }

        return L10n.format("guide.remainingMeters", Int(remainingDistance))
    }

    // MARK: - Confidence Section
    private var confidenceSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("guide.nearbyResults")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    sheetType = .correct
                } label: {
                    Label("guide.correct", systemImage: "scope")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(primaryColor)
                }
                .buttonStyle(.plain)
                .disabled(guideVM.nearbyPOIs.isEmpty)

                Text("guide.confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if guideVM.confidenceList.isEmpty {
                HStack(spacing: 10) {
                    if guideVM.isRefreshingNearbyPlaces {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: contextPhaseIcon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(contextPhaseColor)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(contextPhaseTitle)
                            .font(.caption.weight(.semibold))
                        Text(emptyConfidenceMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(guideVM.confidenceList.prefix(3)) { item in
                    Button {
                        guideVM.selectPOI(item.poi)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text("\(item.rank)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.poi.name)
                                        .font(.caption)
                                        .fontWeight(item.rank == 1 ? .medium : .regular)
                                        .lineLimit(1)

                                    if let distanceText = item.distanceText {
                                        Text(distanceText)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(.gray.opacity(0.15))
                                            .frame(height: 3)
                                        Capsule()
                                            .fill(item.rank == 1 ? primaryColor : .gray.opacity(0.4))
                                            .frame(width: geo.size.width * item.confidence, height: 3)
                                    }
                                }
                                .frame(width: 48, height: 3)

                                Text("\(Int(item.confidence * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(item.rank == 1 ? primaryColor : .secondary)
                                    .frame(width: 28, alignment: .trailing)
                            }

                            if !item.evidence.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 5) {
                                        ForEach(Array(item.evidence.prefix(4)), id: \.self) { evidence in
                                            ConfidenceEvidenceChip(text: evidence, highlighted: item.rank == 1)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.format("guide.selectPOIConfidence.format", item.poi.name, Int(item.confidence * 100)))
                }
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compact Player Section
    private var compactPlayerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primaryColor.opacity(0.1))
                Image(systemName: "headphones")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(primaryColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("guide.nowNarrating")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(guideVM.currentTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(guideVM.currentPOI?.name ?? L10n.string("guide.currentLocation"))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                WaveformView(progress: guideVM.progress, isPlaying: guideVM.isPlaying, color: primaryColor)
                    .frame(maxWidth: 180, minHeight: 16, maxHeight: 16, alignment: .leading)
                    .clipped()
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Button(action: { guideVM.togglePlayback() }) {
                Image(systemName: guideVM.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(primaryColor, in: Circle())
            }
            .accessibilityLabel(guideVM.isPlaying ? L10n.string("guide.pauseNarration") : L10n.string("guide.playNarration"))
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Player Section
    private var playerSection: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Image(systemName: "headphones")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.format("guide.nowNarrating.format", guideVM.currentPOI?.name ?? ""))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                    Text(guideVM.currentTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                Spacer()

                // Duration toggle
                HStack(spacing: 0) {
                    ForEach(GuideDuration.allCases, id: \.self) { d in
                        Button(action: { guideVM.selectedDuration = d }) {
                            Text(d.displayText)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(guideVM.selectedDuration == d ? primaryColor : .clear)
                                .foregroundStyle(guideVM.selectedDuration == d ? .white : .primary)
                        }
                    }
                }
                .background(.gray.opacity(0.1))
                .clipShape(Capsule())
                .fixedSize(horizontal: true, vertical: false)
            }

            // Waveform
            WaveformView(progress: guideVM.progress, isPlaying: guideVM.isPlaying, color: primaryColor)
                .frame(height: 24)

            // Controls
            HStack(spacing: 32) {
                Button(action: { guideVM.seek(by: -15) }) {
                    VStack(spacing: 1) {
                        Image(systemName: "gobackward")
                            .font(.callout)
                        Text("15")
                            .font(.system(size: 9))
                    }
                }

                Button(action: { guideVM.togglePlayback() }) {
                    Image(systemName: guideVM.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(primaryColor)
                        .clipShape(Circle())
                }

                Button(action: { guideVM.seek(by: 15) }) {
                    VStack(spacing: 1) {
                        Image(systemName: "goforward")
                            .font(.callout)
                        Text("15")
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .padding(14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Source Section
    private var sourceSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "shield.checkered")
                .font(.caption)
                .foregroundStyle(primaryColor)
            Text(L10n.format("guide.source.format", guideVM.currentGuide?.source.name ?? guideVM.currentPOI?.source.name ?? L10n.string("guide.source.afterLocation")))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(primaryColor.opacity(0.06))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct POIIntroChatView: View {
    @ObservedObject var guideVM: GuideViewModel
    let accent: Color
    let onClose: () -> Void

    @StateObject private var speechInput = SpeechInputController()
    @State private var question = ""
    @State private var messages: [POIIntroChatMessage] = []
    @State private var speechBaseQuestion = ""
    @FocusState private var isQuestionFocused: Bool

    private let forest = Color(red: 0.12, green: 0.40, blue: 0.24)
    private let paper = Color(red: 0.99, green: 0.98, blue: 0.95)

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.96, blue: 0.91),
                        Color(red: 0.91, green: 0.96, blue: 0.88),
                        Color(red: 0.94, green: 0.96, blue: 0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            introCard
                            transcriptCard
                            chatSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 118)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _, _ in
                        guard let lastID = messages.last?.id else { return }
                        withAnimation(.easeOut(duration: 0.22)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle(guideVM.currentPOI?.name ?? L10n.string("guide.poiIntro.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.82), in: Circle())
                    }
                    .accessibilityLabel(L10n.string("guide.closeIntro"))
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .onAppear {
                seedIntroMessageIfNeeded()
            }
            .onChange(of: speechInput.transcript) { _, transcript in
                applySpeechTranscript(transcript)
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.12))
                    Image(systemName: "building.columns.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 6) {
                    Text(guideVM.currentPOI?.name ?? L10n.string("guide.findingNearbyPOI"))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 8) {
                        Text(categoryText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(forest)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(forest.opacity(0.12), in: Capsule())

                        Text(guideVM.positioningSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(guideVM.currentPOI?.description ?? L10n.string("guide.poiIntro.placeholderDesc"))
                .font(.body)
                .lineSpacing(7)
                .foregroundStyle(.primary)

            sourceRow
        }
        .padding(18)
        .background(paper, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(accent)
                Text("guide.currentNarration")
                    .font(.headline)
                Spacer()
                Text(guideVM.selectedStyle.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.10), in: Capsule())
            }

            Text(guideVM.currentGuide?.transcript ?? L10n.string("guide.narrationPending"))
                .font(.subheadline)
                .lineSpacing(5)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("guide.followup")
                    .font(.headline)
                Spacer()
                if guideVM.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            quickQuestionRow

            ForEach(messages) { message in
                POIIntroChatBubble(message: message, accent: accent)
                    .id(message.id)
            }
        }
    }

    private var quickQuestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickQuestions, id: \.self) { item in
                    Button {
                        submitQuestion(item)
                    } label: {
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(.white.opacity(0.86), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(guideVM.currentPOI == nil || guideVM.isLoading)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var inputBar: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Button {
                    toggleSpeechInput()
                } label: {
                    Image(systemName: speechInput.isRecording ? "stop.fill" : "mic.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(speechInput.isRecording ? .white : .secondary)
                        .frame(width: 42, height: 42)
                        .background(
                            speechInput.isRecording ? accent : Color.black.opacity(0.06),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(guideVM.currentPOI == nil || guideVM.isLoading)
                .accessibilityLabel(speechInput.isRecording ? L10n.string("guide.voice.stop") : L10n.string("guide.voice.start"))

                TextField("guide.input.placeholder", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isQuestionFocused)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(speechInput.isRecording ? accent.opacity(0.48) : forest.opacity(0.20), lineWidth: 1)
                    )

                Button {
                    submitQuestion(question)
                } label: {
                    Image(systemName: guideVM.isLoading ? "hourglass" : "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(canSubmit ? accent : Color.gray.opacity(0.45), in: Circle())
                }
                .disabled(!canSubmit)
                .accessibilityLabel(L10n.string("guide.sendFollowup"))
            }

            if let speechStatusText {
                HStack(spacing: 5) {
                    Image(systemName: speechInput.isRecording ? "waveform" : "info.circle")
                        .font(.caption2.weight(.semibold))
                    Text(speechStatusText)
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(speechInput.isRecording ? accent : .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var sourceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: guideVM.currentPOI?.source.verified == true ? "shield.checkered" : "info.circle")
                .foregroundStyle(forest)
            Text(L10n.format("guide.source.format", guideVM.currentGuide?.source.name ?? guideVM.currentPOI?.source.name ?? L10n.string("guide.source.afterLocation")))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.72), in: Capsule())
    }

    private var categoryText: String {
        guard let category = guideVM.currentPOI?.category else { return L10n.string("guide.category.locating") }
        switch category {
        case .palace: return L10n.string("guide.category.palace")
        case .temple: return L10n.string("guide.category.temple")
        case .garden: return L10n.string("guide.category.garden")
        case .museum: return L10n.string("guide.category.museum")
        case .exhibit: return L10n.string("guide.category.exhibit")
        case .building: return L10n.string("guide.category.building")
        }
    }

    private var quickQuestions: [String] {
        let name = guideVM.currentPOI?.name ?? L10n.string("guide.quick.here")
        return [
            L10n.format("guide.quick.whyImportant.format", name),
            L10n.string("guide.quick.kids"),
            L10n.string("guide.quick.nextNearby")
        ]
    }

    private var canSubmit: Bool {
        guideVM.currentPOI != nil &&
            !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !guideVM.isLoading &&
            !speechInput.isRecording
    }

    private var speechStatusText: String? {
        if speechInput.isRecording {
            return L10n.string("guide.speech.listening")
        }
        return speechInput.statusMessage
    }

    private func seedIntroMessageIfNeeded() {
        guard messages.isEmpty, let poi = guideVM.currentPOI else { return }
        messages = [
            POIIntroChatMessage(
                role: .assistant,
                content: L10n.format("guide.intro.seed.format", poi.name)
            )
        ]
    }

    private func submitQuestion(_ rawQuestion: String) {
        let trimmed = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, guideVM.currentPOI != nil, !guideVM.isLoading else { return }

        speechInput.stop()
        messages.append(POIIntroChatMessage(role: .user, content: trimmed))
        question = ""
        speechBaseQuestion = ""
        isQuestionFocused = false

        Task {
            await guideVM.askQuestion(trimmed)
            let answer = guideVM.currentAnswer ?? L10n.string("guide.answerFallback")
            messages.append(POIIntroChatMessage(role: .assistant, content: answer))
        }
    }

    private func toggleSpeechInput() {
        if speechInput.isRecording {
            speechInput.stop()
            return
        }

        speechBaseQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        isQuestionFocused = false
        Task {
            await speechInput.start()
        }
    }

    private func applySpeechTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if speechBaseQuestion.isEmpty {
            question = trimmed
        } else {
            question = "\(speechBaseQuestion) \(trimmed)"
        }
    }
}

private struct POIIntroChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let content: String
}

private struct POIIntroChatBubble: View {
    let message: POIIntroChatMessage
    let accent: Color

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 42)
            }

            Text(displayContent)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    message.role == .user
                        ? accent
                        : Color.white.opacity(0.88),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            if message.role == .assistant {
                Spacer(minLength: 42)
            }
        }
    }

    private var displayContent: String {
        guard message.role == .assistant else { return message.content }
        return message.content.plainLLMDisplayText
    }
}

private extension String {
    var plainLLMDisplayText: String {
        let markerCleaned = replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")

        let lines = markerCleaned.components(separatedBy: .newlines).map { line in
            var cleaned = line.trimmingCharacters(in: .whitespaces)

            while cleaned.hasPrefix("#") {
                cleaned.removeFirst()
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            }

            if cleaned.hasPrefix(">") {
                cleaned.removeFirst()
                cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            }

            return cleaned
        }

        var text = lines.joined(separator: "\n")
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
private final class SpeechInputController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var statusMessage: String?

    private var speechRecognizer: SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: SettingsService.shared.language.locale)
    }
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func start() async {
        guard !isRecording else { return }
        statusMessage = nil
        transcript = ""

        let speechAllowed = await requestSpeechAuthorization()
        let microphoneAllowed = await requestMicrophoneAuthorization()

        guard speechAllowed && microphoneAllowed else {
            statusMessage = L10n.string("guide.speech.permissionRequired")
            return
        }

        do {
            try startRecognition()
        } catch {
            statusMessage = L10n.string("guide.speech.unavailable")
            stop()
        }
    }

    func stop() {
        guard isRecording || recognitionTask != nil || recognitionRequest != nil else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusMessage = L10n.string("guide.speech.recognizerUnavailable")
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
    }
}

private struct DrawerActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct WorkbenchToolButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .frame(height: 18)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct ConfidenceEvidenceChip: View {
    let text: String
    let highlighted: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(highlighted ? Color(red: 0.85, green: 0.35, blue: 0.15) : .secondary)
            .background(
                (highlighted ? Color(red: 0.85, green: 0.35, blue: 0.15) : Color.gray)
                    .opacity(highlighted ? 0.10 : 0.08),
                in: Capsule()
            )
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let progress: Double
    let isPlaying: Bool
    var color: Color = .blue

    var body: some View {
        if isPlaying {
            TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                HStack(spacing: 2) {
                    ForEach(0..<50, id: \.self) { i in
                        let baseHeight = CGFloat(6 + (i * 7) % 14)
                        let sineValue = sin(time * 7.5 + Double(i) * 0.28)
                        let height = baseHeight * (1.0 + 0.45 * CGFloat(sineValue))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Double(i) / 50 < progress ? color : .gray.opacity(0.2))
                            .frame(width: 2.5, height: max(4, height))
                    }
                }
            }
        } else {
            HStack(spacing: 2) {
                ForEach(0..<50, id: \.self) { i in
                    let baseHeight = CGFloat(8 + (i * 7) % 16)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Double(i) / 50 < progress ? color : .gray.opacity(0.2))
                        .frame(width: 2.5, height: baseHeight)
                }
            }
        }
    }
}

private enum GuideMapMode: String, CaseIterable, Identifiable {
    case explore
    case quiet
    case satellite
    case hybrid

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .explore:
            return "guide.mapMode.explore"
        case .quiet:
            return "guide.mapMode.quiet"
        case .satellite:
            return "guide.mapMode.satellite"
        case .hybrid:
            return "guide.mapMode.hybrid"
        }
    }

    var subtitleKey: String {
        switch self {
        case .explore:
            return "guide.mapMode.explore.subtitle"
        case .quiet:
            return "guide.mapMode.quiet.subtitle"
        case .satellite:
            return "guide.mapMode.satellite.subtitle"
        case .hybrid:
            return "guide.mapMode.hybrid.subtitle"
        }
    }

    var icon: String {
        switch self {
        case .explore:
            return "map.fill"
        case .quiet:
            return "line.3.horizontal.decrease.circle.fill"
        case .satellite:
            return "globe.americas.fill"
        case .hybrid:
            return "square.3.layers.3d"
        }
    }

    var mapType: MKMapType {
        switch self {
        case .explore:
            return .standard
        case .quiet:
            return .mutedStandard
        case .satellite:
            return .satellite
        case .hybrid:
            return .hybrid
        }
    }
}

private struct GuideMapModeSheet: View {
    @Binding var selectedMode: GuideMapMode
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.string("guide.mapMode.title"))
                    .font(.title3.weight(.bold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("common.close"))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(GuideMapMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(mode == selectedMode ? .white : Color(red: 0.12, green: 0.40, blue: 0.24))

                                Spacer()

                                if mode == selectedMode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.callout.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.string(mode.titleKey))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(mode == selectedMode ? .white : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Text(L10n.string(mode.subtitleKey))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(mode == selectedMode ? .white.opacity(0.78) : .secondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.76)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(mode == selectedMode ? Color(red: 0.12, green: 0.40, blue: 0.24) : Color(.secondarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(mode == selectedMode ? Color.clear : Color(.separator).opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(L10n.string("guide.mapMode.note"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Map View Container
struct MapViewContainer: UIViewRepresentable {
    let currentPOI: POI?
    let initialRegion: MKCoordinateRegion
    let route: Route
    let nearbyPOIs: [POI]
    let mapType: MKMapType
    let isMap3D: Bool
    let onUserLocationUpdate: (CLLocation) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = mapType
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.setRegion(displayRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.currentPOIID = currentPOI?.id
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        let targetRegion = displayRegion
        let targetPitch: CGFloat = isMap3D ? 45 : 0

        let currentCenter = CLLocation(
            latitude: mapView.region.center.latitude,
            longitude: mapView.region.center.longitude
        )
        let targetCenter = CLLocation(
            latitude: targetRegion.center.latitude,
            longitude: targetRegion.center.longitude
        )

        let pitchChanged = abs(mapView.camera.pitch - targetPitch) > 1

        if currentCenter.distance(from: targetCenter) > 12 || pitchChanged {
            let spanMeters = targetRegion.span.latitudeDelta * 111_000
            let fromDistance = max(350, min(1500, spanMeters * 1.2))

            let camera = MKMapCamera(
                lookingAtCenter: targetRegion.center,
                fromDistance: fromDistance,
                pitch: targetPitch,
                heading: mapView.camera.heading
            )
            mapView.setCamera(camera, animated: true)
        }

        let routePOIs = route.stops.compactMap { stop in
            poi(for: stop.poiId)
        }
        let routeOrderByID = Dictionary(uniqueKeysWithValues: route.stops.map { ($0.poiId, $0.order + 1) })
        updateRouteOverlay(on: mapView, routePOIs: routePOIs)

        let displayedPOIs = mergedPOIs(routePOIs + nearbyPOIs + [currentPOI].compactMap { $0 })
        let displayedIDs = Set(displayedPOIs.map(\.id))
        let existingAnnotations = mapView.annotations.compactMap { $0 as? POIMapAnnotation }
        let existingIDs = Set(existingAnnotations.map(\.poi.id))
        let currentChanged = existingAnnotations.contains { $0.isCurrent != ($0.poi.id == currentPOI?.id) }

        if existingIDs != displayedIDs || currentChanged {
            mapView.removeAnnotations(existingAnnotations)
            mapView.addAnnotations(displayedPOIs.map { poi in
                POIMapAnnotation(
                    poi: poi,
                    isCurrent: poi.id == currentPOI?.id,
                    isRouteStop: route.stops.contains { $0.poiId == poi.id },
                    routeOrder: routeOrderByID[poi.id]
                )
            })
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onUserLocationUpdate: onUserLocationUpdate)
    }

    private var displayRegion: MKCoordinateRegion {
        var region = initialRegion
        let routePOIs = route.stops.compactMap { poi(for: $0.poiId) }
        let focusPOIs = mergedPOIs([currentPOI].compactMap { $0 } + routePOIs + Array(nearbyPOIs.prefix(3)))

        if !focusPOIs.isEmpty {
            let latitudes = focusPOIs.map { $0.coordinate.latitude } + [initialRegion.center.latitude]
            let longitudes = focusPOIs.map { $0.coordinate.longitude } + [initialRegion.center.longitude]
            let minLatitude = latitudes.min() ?? initialRegion.center.latitude
            let maxLatitude = latitudes.max() ?? initialRegion.center.latitude
            let minLongitude = longitudes.min() ?? initialRegion.center.longitude
            let maxLongitude = longitudes.max() ?? initialRegion.center.longitude

            region.center = CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            )
            region.span = MKCoordinateSpan(
                latitudeDelta: min(max((maxLatitude - minLatitude) * 1.9, 0.006), 0.04),
                longitudeDelta: min(max((maxLongitude - minLongitude) * 1.9, 0.006), 0.04)
            )
        }

        region.center.latitude -= region.span.latitudeDelta * 0.12
        return region
    }

    private func poi(for id: String) -> POI? {
        nearbyPOIs.first { $0.id == id } ?? POI.seedList.first { $0.id == id }
    }

    private func mergedPOIs(_ pois: [POI]) -> [POI] {
        var seen = Set<String>()
        return pois.filter { poi in
            guard !seen.contains(poi.id) else { return false }
            seen.insert(poi.id)
            return true
        }
    }

    private func updateRouteOverlay(on mapView: MKMapView, routePOIs: [POI]) {
        mapView.removeOverlays(mapView.overlays)
        guard routePOIs.count > 1 else { return }

        var coordinates = routePOIs.map(\.coordinate)
        let line = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        mapView.addOverlay(line)
    }

    final class POIMapAnnotation: NSObject, MKAnnotation {
        let poi: POI
        let isCurrent: Bool
        let isRouteStop: Bool
        let routeOrder: Int?

        var coordinate: CLLocationCoordinate2D {
            poi.coordinate
        }

        var title: String? {
            poi.name
        }

        init(poi: POI, isCurrent: Bool, isRouteStop: Bool, routeOrder: Int?) {
            self.poi = poi
            self.isCurrent = isCurrent
            self.isRouteStop = isRouteStop
            self.routeOrder = routeOrder
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentPOIID: String?
        private let onUserLocationUpdate: (CLLocation) -> Void
        private var lastForwardedUserLocation: CLLocation?

        init(onUserLocationUpdate: @escaping (CLLocation) -> Void) {
            self.onUserLocationUpdate = onUserLocationUpdate
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let location = userLocation.location else { return }

            if let lastForwardedUserLocation,
               location.distance(from: lastForwardedUserLocation) < 8 {
                return
            }

            lastForwardedUserLocation = location
            Task { @MainActor in
                self.onUserLocationUpdate(location)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            guard let poiAnnotation = annotation as? POIMapAnnotation else { return nil }

            let identifier = "POI-\(poiAnnotation.isCurrent)-\(poiAnnotation.isRouteStop)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.displayPriority = .required
                markerView.titleVisibility = .adaptive
                markerView.subtitleVisibility = .hidden

                if poiAnnotation.isCurrent {
                    markerView.markerTintColor = UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 1.0)
                    markerView.glyphText = poiAnnotation.routeOrder.map(String.init) ?? "•"
                    markerView.glyphImage = nil
                } else if poiAnnotation.isRouteStop {
                    markerView.markerTintColor = UIColor(red: 0.12, green: 0.40, blue: 0.24, alpha: 0.92)
                    markerView.glyphText = poiAnnotation.routeOrder.map(String.init) ?? ""
                    markerView.glyphImage = nil
                } else {
                    markerView.markerTintColor = UIColor.systemGray
                    markerView.glyphText = nil
                    markerView.glyphImage = UIImage(systemName: "building.2.fill")
                }
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 0.78)
            renderer.lineWidth = 7
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

#Preview {
    GuideView()
        .environmentObject(AppState())
        .environmentObject(JoiCharacterSession.shared)
}
