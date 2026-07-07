// Guide ViewModel - With Edge TTS Support

import Foundation
import MapKit
import Combine

@MainActor
class GuideViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentPOI: POI?
    @Published var currentRoute: Route = .nearbyPlaceholder
    @Published var currentGuide: AudioGuide?
    @Published var nearbyPOIs: [POI] = []
    @Published var confidenceList: [LocationConfidence] = []

    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var selectedStyle: GuideStyle = .history
    @Published var selectedDuration: GuideDuration = .short
    @Published var selectedVoice: EdgeVoice = .default

    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9163, longitude: 116.3972),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )

    @Published var question = ""
    @Published var currentAnswer: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isConnectedToBackend = false
    @Published var positioningSummary = L10n.string("guide.locating")
    @Published var contextPhase: GuideContextPhase = .locating
    @Published var isRefreshingNearbyPlaces = false

    // MARK: - Services
    let locationService = LocationService()
    let indoorLocationService = IndoorLocationService()
    let ttsService = EdgeTTSService.shared
    let apiClient = APIClient()
    let historyService = HistoryService.shared

    // MARK: - Playback tracking
    private var playbackStartTime: Date?
    private var allPOIs: [POI] = POI.seedList
    private var lastContextResolveAt: Date?
    private var visualConfirmations: [String: VisualConfirmation] = [:]
    private let remoteResolveInterval: TimeInterval = 8
    private let visualConfirmationTTL: TimeInterval = 120
    private let poiSwitchConfidenceGap = 0.08
    private let mapSearchPOIPrefix = "mapsearch-"
    private let offlinePOIPrefix = "offline-cultural-"
    private let userPOIPrefix = "user-poi-"
    private let mapSearchRadii: [CLLocationDistance] = [2_500, 8_000, 20_000]
    private let mapPlaceSearchTimeout: TimeInterval = 5
    private let cachedPOIsKey = "AIGuide.cachedPOIs.v1"
    private let cachedMapRecommendationsKey = "AIGuide.cachedMapRecommendations.v1"
    private let mapRecommendationCacheMaxAge: TimeInterval = 7 * 24 * 60 * 60
    private let mapRecommendationCacheRadius: CLLocationDistance = 900
    private var lastMapSearchLocation: CLLocation?
    private var lastMapSearchAt: Date?
    private var isSearchingMapPlaces = false
    private var prefetchedGuides: [String: AudioGuide] = [:]
    private var prefersOfflineMode: Bool {
        SettingsService.shared.offlineMode
    }

    private struct FusedCandidate {
        let poi: POI
        let distance: CLLocationDistance
        let gpsConfidence: Double
        let routeBoost: Double
        let indoorBoost: Double
        let visualBoost: Double
        let confidence: Double
        let layers: [String]
    }

    private struct RouteSnap {
        let nearestStopId: String?
        let nearestStopDistance: CLLocationDistance
        let segmentStopIds: Set<String>
        let segmentDistance: CLLocationDistance
    }

    private struct VisualConfirmation {
        let confidence: Double
        let timestamp: Date
        let source: String
    }

    private struct CachedMapRecommendations: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
        let pois: [POI]
    }

    private enum MapPlaceSearchError: Error {
        case timedOut
    }

    private final class MapSearchState {
        private let search: MKLocalSearch
        private let continuation: CheckedContinuation<MKLocalSearch.Response, Error>
        private let lock = NSLock()
        private var didResume = false

        init(search: MKLocalSearch, continuation: CheckedContinuation<MKLocalSearch.Response, Error>) {
            self.search = search
            self.continuation = continuation
        }

        func resume(returning response: MKLocalSearch.Response) {
            complete(.success(response))
        }

        func resume(throwing error: Error) {
            complete(.failure(error))
        }

        private func complete(_ result: Result<MKLocalSearch.Response, Error>) {
            lock.lock()
            guard !didResume else {
                lock.unlock()
                return
            }
            didResume = true
            lock.unlock()

            search.cancel()

            switch result {
            case .success(let response):
                continuation.resume(returning: response)
            case .failure(let error):
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Computed Properties
    var currentUserLocation: CLLocation? {
        locationService.currentLocation
    }

    var topConfidence: Double {
        confidenceList.first?.confidence ?? 0
    }

    var currentTimeString: String {
        let elapsed = formatTime(currentTime)
        let total = formatTime(TimeInterval(selectedDuration.rawValue))
        return "\(elapsed) / \(total)"
    }

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        let settings = SettingsService.shared
        selectedStyle = settings.guideStyle
        selectedVoice = settings.preferredVoice
        ttsService.selectedVoice = settings.preferredVoice
        setupBindings()
        setupMockData()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Location updates
        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)

        // TTS progress
        ttsService.$isSpeaking
            .assign(to: &$isPlaying)

        ttsService.$progress
            .assign(to: &$progress)

        // Style changes
        $selectedStyle
            .sink { [weak self] style in
                self?.updateGuide(for: style)
                Task { [weak self] in
                    await self?.generateNarration()
                    self?.prefetchNextStopGuide()
                }
            }
            .store(in: &cancellables)

        indoorLocationService.$nearbyBeacons
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshFromLatestSignals()
            }
            .store(in: &cancellables)

        indoorLocationService.$currentZone
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshFromLatestSignals()
            }
            .store(in: &cancellables)
    }

    private func setupMockData() {
        if let cachedPOIs = loadCachedPOIs(), !cachedPOIs.isEmpty {
            allPOIs = mergePOIs(POI.seedList, with: cachedPOIs)
        } else {
            allPOIs = POI.seedList
        }
        confidenceList = []
        nearbyPOIs = []
    }

    // MARK: - Public Methods

    /// Check backend connection
    func checkBackendConnection() async {
        if prefersOfflineMode {
            isConnectedToBackend = false
            if currentPOI == nil {
                contextPhase = .offline
                positioningSummary = L10n.string("guide.backendOffline.localMode")
            }
            return
        }

        isConnectedToBackend = await apiClient.checkHealth()
        if !isConnectedToBackend, currentPOI == nil {
            contextPhase = .offline
            positioningSummary = L10n.string("guide.backendOffline.localMode")
        }
    }

    /// Start location updates
    func startLocationUpdates() {
        contextPhase = .locating
        positioningSummary = L10n.string("guide.readingLocation")
        locationService.requestPermission()
        locationService.startUpdating()
        indoorLocationService.requestAuthorization()
        indoorLocationService.startIndoorPositioning()
    }

    /// Use MKMapView's blue-dot location as a fallback when CoreLocation has not emitted yet.
    func updateFromMapUserLocation(_ location: CLLocation) {
        if let currentLocation = locationService.currentLocation,
           location.distance(from: currentLocation) < 8 {
            return
        }

        locationService.currentLocation = location
    }

    /// Stop location updates
    func stopLocationUpdates() {
        locationService.stopUpdating()
        indoorLocationService.stopIndoorPositioning()
    }

    /// Apply a photo/vision result as a temporary confirmation signal.
    func applyVisualConfirmation(_ confirmation: AppState.VisualPOIConfirmation) {
        visualConfirmations[confirmation.poi.id] = VisualConfirmation(
            confidence: confirmation.confidence,
            timestamp: confirmation.timestamp,
            source: confirmation.source
        )
        allPOIs = mergePOIs(allPOIs, with: [confirmation.poi])
        saveCachedPOIs(allPOIs)

        if confirmation.confidence >= 0.78 {
            contextPhase = .visualConfirmed
            applyCurrentPOI(confirmation.poi)
        }

        refreshFromLatestSignals()
    }

    /// Let users correct the automatic POI selection from nearby candidates.
    func selectPOI(_ poi: POI) {
        allPOIs = mergePOIs(allPOIs, with: [poi])
        saveCachedPOIs(allPOIs)
        contextPhase = .manual
        positioningSummary = L10n.string("guide.manualCalibrationHigh")
        applyCurrentPOI(poi)
        updateRouteProgress(activePOI: poi)

        if let location = locationService.currentLocation {
            resolveLocationLocally(location)
        } else {
            confidenceList = [
                LocationConfidence(
                    poi: poi,
                    confidence: 0.99,
                    rank: 1,
                    evidence: [L10n.string("guide.evidence.manual"), poi.source.verified ? L10n.string("guide.evidence.official") : localizedSourceName(poi.source.name)]
                )
            ]
        }
    }

    /// Add a temporary/local POI from the user's current location.
    func addCustomPOI(name: String, description: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let location = locationService.currentLocation else { return }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDescription = trimmedDescription.isEmpty
            ? L10n.string("guide.customPOI.defaultDescription")
            : trimmedDescription

        let poi = POI(
            id: "\(userPOIPrefix)\(stableMapItemID(name: trimmedName, coordinate: location.coordinate))",
            name: trimmedName,
            description: finalDescription,
            coordinate: location.coordinate,
            category: .building,
            images: [],
            source: ContentSource(name: L10n.string("guide.source.user"), type: .userContributed, verified: false)
        )

        allPOIs = mergePOIs(allPOIs, with: [poi])
        nearbyPOIs = mergePOIs([poi], with: nearbyPOIs)
        saveCachedPOIs(allPOIs)
        selectPOI(poi)
    }

    /// Load POIs from backend
    func loadPOIs() async {
        isLoading = true
        defer { isLoading = false }

        if prefersOfflineMode {
            isConnectedToBackend = false
            if let cachedPOIs = loadCachedPOIs(), !cachedPOIs.isEmpty {
                allPOIs = mergePOIs(POI.seedList, with: cachedPOIs)
            } else {
                allPOIs = POI.seedList
            }
            if currentPOI == nil {
                contextPhase = .offline
                positioningSummary = L10n.string("guide.offlineReady")
                nearbyPOIs = []
            }
            return
        }

        do {
            let pois: [POI] = try await apiClient.get(endpoint: APIConfig.Endpoints.pois)
            let cachedUserPOIs = loadCachedPOIs()?.filter { poi in
                poi.id.hasPrefix(userPOIPrefix) || poi.source.type == .userContributed
            } ?? []
            allPOIs = mergePOIs(pois.isEmpty ? POI.seedList : pois, with: cachedUserPOIs)
            saveCachedPOIs(allPOIs)
            if locationService.currentLocation == nil {
                nearbyPOIs = []
            }
            isConnectedToBackend = true
        } catch {
            isConnectedToBackend = false
            if currentPOI == nil {
                contextPhase = .offline
                positioningSummary = L10n.string("guide.offlineReady")
            }
            if let cachedPOIs = loadCachedPOIs(), !cachedPOIs.isEmpty {
                allPOIs = mergePOIs(POI.seedList, with: cachedPOIs)
            } else if allPOIs.isEmpty {
                allPOIs = POI.seedList
            }
            if currentPOI == nil {
                nearbyPOIs = []
            }
        }
    }

    /// Generate narration
    func generateNarration() async {
        guard let poi = currentPOI else { return }

        let cacheKey = "\(poi.id)-\(selectedStyle.rawValue)-\(selectedDuration.rawValue)"
        if let cachedGuide = prefetchedGuides[cacheKey] {
            currentGuide = cachedGuide
            return
        }
        if let cachedGuide = historyService.getCachedGuide(for: cacheKey) {
            prefetchedGuides[cacheKey] = cachedGuide
            currentGuide = cachedGuide
            return
        }

        if prefersOfflineMode {
            updateGuide(for: selectedStyle)
            if let currentGuide {
                prefetchedGuides[cacheKey] = currentGuide
                historyService.cacheGuide(currentGuide, for: cacheKey)
            }
            isConnectedToBackend = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let body: [String: Any] = [
                "poi_id": poi.id,
                "style": selectedStyle.rawValue,
                "duration": selectedDuration.rawValue,
                "context": [String: Any]()
            ]

            let response: NarrateResponse = try await apiClient.post(
                endpoint: APIConfig.Endpoints.guideNarrate,
                body: body
            )

            let guide = AudioGuide(
                id: response.id,
                poiId: response.poiId,
                style: response.style,
                duration: response.duration,
                transcript: response.transcript,
                audioURL: response.audioUrl,
                source: response.source
            )

            currentGuide = guide
            prefetchedGuides[cacheKey] = guide
            historyService.cacheGuide(guide, for: cacheKey)
            isConnectedToBackend = true
        } catch {
            updateGuide(for: selectedStyle)
            if let currentGuide {
                prefetchedGuides[cacheKey] = currentGuide
                historyService.cacheGuide(currentGuide, for: cacheKey)
            }
        }
    }

    /// Ask question
    func askQuestion(_ question: String) async {
        guard let poi = currentPOI else { return }

        self.question = question
        if prefersOfflineMode {
            isConnectedToBackend = false
            currentAnswer = L10n.format("guide.answerFallback", poi.name)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let body: [String: Any] = [
                "poi_id": poi.id,
                "poi_name": poi.name,
                "poi_description": poi.description,
                "question": question
            ]

            let response: QAResponse = try await apiClient.post(
                endpoint: APIConfig.Endpoints.qaAsk,
                body: body
            )

            currentAnswer = response.answer
            isConnectedToBackend = true
        } catch {
            isConnectedToBackend = false
            currentAnswer = L10n.format("guide.answerFallback", poi.name)
        }
    }

    // MARK: - Playback Controls

    /// Toggle TTS playback
    func togglePlayback() {
        guard let guide = currentGuide, currentPOI != nil else { return }

        if ttsService.isSpeaking {
            ttsService.pause()
            recordVisit()
        } else if ttsService.currentText != nil {
            ttsService.resume()
            playbackStartTime = Date()
        } else {
            playbackStartTime = Date()
            Task {
                await ttsService.speakWithStyle(guide.transcript, style: selectedStyle)
                recordVisit()
            }
        }
    }

    /// Record visit to history
    private func recordVisit() {
        guard let poi = currentPOI,
              let startTime = playbackStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)

        // Only record if played for more than 10 seconds
        if duration > 10 {
            historyService.addVisit(
                poiId: poi.id,
                poiName: poi.name,
                duration: duration,
                style: selectedStyle,
                summary: currentGuide?.transcript.prefix(50).description,
                sourceName: currentGuide?.source.name ?? poi.source.name
            )
        }

        playbackStartTime = nil
    }

    /// Stop playback
    func stopPlayback() {
        ttsService.stop()
    }

    /// Change voice
    func changeVoice(_ voice: EdgeVoice) {
        selectedVoice = voice
        ttsService.selectedVoice = voice
        SettingsService.shared.preferredVoice = voice
        SettingsService.shared.saveSettings()
    }

    /// Seek (restart for TTS)
    func seek(by seconds: TimeInterval) {
        if seconds < 0 {
            stopPlayback()
            if let guide = currentGuide {
                Task {
                    await ttsService.speakWithStyle(guide.transcript, style: selectedStyle)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func handleLocationUpdate(_ location: CLLocation) {
        region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )

        resolveLocationLocally(location)

        guard shouldResolveRemoteContext() else { return }
        lastContextResolveAt = Date()

        Task {
            await resolveContext(for: location)
        }
    }

    private func resolveContext(for location: CLLocation) async {
        do {
            let body: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]

            let response: ContextResponse = try await apiClient.post(
                endpoint: APIConfig.Endpoints.contextResolve,
                body: body
            )

            if !response.nearbyPois.isEmpty {
                allPOIs = mergePOIs(allPOIs, with: response.nearbyPois)
            }

            if let poi = response.poi {
                allPOIs = mergePOIs(allPOIs, with: [poi])
                applyCurrentPOI(poi)
            }

            resolveLocationLocally(location)
            isConnectedToBackend = true
        } catch {
            isConnectedToBackend = false
            if currentPOI == nil {
                contextPhase = .offline
                positioningSummary = L10n.string("guide.backendOffline.localSearch")
            }
        }
    }

    private func resolveLocationLocally(_ location: CLLocation) {
        pruneExpiredVisualConfirmations()

        let routeSnap = routeSnap(for: location)
        let indoorSignals = indoorSignalMap()
        let ranked = allPOIs
            .map { fusedCandidate(for: $0, location: location, routeSnap: routeSnap, indoorSignals: indoorSignals) }
            .sorted { first, second in
                if first.confidence == second.confidence {
                    return first.distance < second.distance
                }
                return first.confidence > second.confidence
            }

        let matchRadius = localMatchRadius(for: location)
        let eligibleRanked = ranked.filter { candidate in
            candidate.distance <= matchRadius ||
                candidate.indoorBoost > 0.05 ||
                candidate.visualBoost > 0.05
        }

        guard let best = eligibleRanked.first else {
            confidenceList = []
            nearbyPOIs = []
            contextPhase = .recommending
            positioningSummary = L10n.string("guide.findingNearby")
            clearCurrentPOIIfNeeded(location: location)
            requestMapPlaceRecommendationsIfNeeded(around: location)
            return
        }

        confidenceList = eligibleRanked.prefix(3).enumerated().map { index, item in
            confidenceItem(from: item, rank: index + 1)
        }

        let nearbyRadius = localNearbyRadius(for: location)
        let localNearby = eligibleRanked
            .filter { $0.distance <= nearbyRadius || $0.indoorBoost > 0.05 || $0.visualBoost > 0.05 }
            .prefix(8)
            .map(\.poi)

        nearbyPOIs = localNearby.isEmpty ? Array(eligibleRanked.prefix(3).map(\.poi)) : Array(localNearby)
        if best.visualBoost > 0.05 {
            contextPhase = .visualConfirmed
        } else if best.poi.id.hasPrefix(mapSearchPOIPrefix) || best.poi.id.hasPrefix(offlinePOIPrefix) {
            contextPhase = .recommended
        } else if contextPhase != .manual {
            contextPhase = .nearbyMatch
        }
        positioningSummary = positioningSummary(for: best)
        updateRouteProgress(activePOI: best.poi)

        let currentCandidate = currentPOI.flatMap { poi in
            ranked.first { $0.poi.id == poi.id }
        }

        if shouldSwitchCurrentPOI(to: best, currentCandidate: currentCandidate, location: location) {
            applyCurrentPOI(best.poi)
        }

        if shouldRefreshMapPlaceRecommendations(from: location, bestDistance: best.distance) {
            requestMapPlaceRecommendationsIfNeeded(around: location)
        }
    }

    private func shouldResolveRemoteContext() -> Bool {
        guard !prefersOfflineMode else { return false }
        guard let lastContextResolveAt else { return true }
        return Date().timeIntervalSince(lastContextResolveAt) >= remoteResolveInterval
    }

    private func shouldSwitchCurrentPOI(
        to candidate: FusedCandidate,
        currentCandidate: FusedCandidate?,
        location: CLLocation
    ) -> Bool {
        guard candidate.confidence >= 0.45 else { return false }
        guard let currentPOI else { return true }
        guard currentPOI.id != candidate.poi.id else { return false }

        let currentDistance = currentCandidate?.distance ?? distance(from: location, to: currentPOI.coordinate)
        let currentConfidence = currentCandidate?.confidence ??
            gpsConfidence(distance: currentDistance, horizontalAccuracy: location.horizontalAccuracy)

        return candidate.distance < 18 ||
            candidate.confidence > currentConfidence + poiSwitchConfidenceGap ||
            currentDistance > localNearbyRadius(for: location)
    }

    private func applyCurrentPOI(_ poi: POI) {
        let didChange = currentPOI?.id != poi.id
        currentPOI = poi

        guard didChange else { return }

        if ttsService.isSpeaking {
            ttsService.stop()
        }

        currentAnswer = nil
        currentTime = 0
        progress = 0
        updateGuide(for: selectedStyle)

        Task {
            await generateNarration()
            prefetchNextStopGuide()
        }
    }

    private func refreshFromLatestSignals() {
        guard let location = locationService.currentLocation else { return }
        resolveLocationLocally(location)
    }

    private func clearCurrentPOIIfNeeded(location: CLLocation) {
        guard let currentPOI else { return }
        let currentDistance = distance(from: location, to: currentPOI.coordinate)
        guard currentDistance > localMatchRadius(for: location) else { return }

        stopPlayback()
        self.currentPOI = nil
        currentGuide = nil
        currentAnswer = nil
        currentTime = 0
        progress = 0
        currentRoute = .nearbyPlaceholder
    }

    private func requestMapPlaceRecommendationsIfNeeded(around location: CLLocation) {
        guard shouldSearchMapPlaces(from: location) else { return }
        lastMapSearchLocation = location
        lastMapSearchAt = Date()

        Task {
            await refreshMapPlaceRecommendations(around: location)
        }

        let fallbackDelay = UInt64((mapPlaceSearchTimeout * Double(mapSearchRadii.count) + 1) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: fallbackDelay)

            await MainActor.run {
                guard let self,
                      self.isSearchingMapPlaces,
                      self.nearbyPOIs.isEmpty || self.currentPOI == nil,
                      let lastMapSearchLocation = self.lastMapSearchLocation,
                      location.distance(from: lastMapSearchLocation) < 20 else {
                    return
                }

                let fallbackRecommendations = Array(self.offlineCulturalRecommendations(around: location).prefix(8))
                guard !fallbackRecommendations.isEmpty else { return }

                self.applyPlaceRecommendations(fallbackRecommendations, origin: location)
                self.isSearchingMapPlaces = false
                self.isRefreshingNearbyPlaces = false
            }
        }
    }

    private func shouldSearchMapPlaces(from location: CLLocation) -> Bool {
        guard !isSearchingMapPlaces else { return false }

        if let lastMapSearchAt,
           Date().timeIntervalSince(lastMapSearchAt) < 20 {
            return false
        }

        guard let lastMapSearchLocation else { return true }
        return location.distance(from: lastMapSearchLocation) > 220
    }

    private func shouldRefreshMapPlaceRecommendations(
        from location: CLLocation,
        bestDistance: CLLocationDistance
    ) -> Bool {
        guard bestDistance > localNearbyRadius(for: location) else { return false }
        return nearbyPOIs.allSatisfy { !$0.id.hasPrefix(mapSearchPOIPrefix) }
    }

    private func refreshMapPlaceRecommendations(around location: CLLocation) async {
        guard !isSearchingMapPlaces else { return }
        isSearchingMapPlaces = true
        isRefreshingNearbyPlaces = true
        defer {
            isSearchingMapPlaces = false
            isRefreshingNearbyPlaces = false
        }

        if let cachedRecommendations = loadCachedMapRecommendations(around: location),
           !cachedRecommendations.isEmpty {
            applyPlaceRecommendations(cachedRecommendations, origin: location)
        }

        let mapItems = await searchNearbyMapItems(around: location)
        let mapRecommendations = mapItems
            .compactMap { poi(from: $0) }
            .uniquedByID()
            .sorted {
                distance(from: location, to: $0.coordinate) < distance(from: location, to: $1.coordinate)
            }
            .prefix(8)

        let recommendations = Array(mapRecommendations).isEmpty
            ? Array(offlineCulturalRecommendations(around: location).prefix(8))
            : Array(mapRecommendations)

        guard !recommendations.isEmpty else {
            contextPhase = .empty
        positioningSummary = L10n.string("guide.nearbyEmpty")
            return
        }

        if recommendations.contains(where: { $0.id.hasPrefix(mapSearchPOIPrefix) }) {
            saveCachedMapRecommendations(recommendations, around: location)
        }

        applyPlaceRecommendations(recommendations, origin: location)
    }

    private func applyPlaceRecommendations(_ recommendations: [POI], origin location: CLLocation) {
        allPOIs = mergePOIs(
            allPOIs.filter {
                !$0.id.hasPrefix(mapSearchPOIPrefix) && !$0.id.hasPrefix(offlinePOIPrefix)
            },
            with: recommendations
        )
        currentRoute = routeFromMapRecommendations(recommendations, origin: location)
        nearbyPOIs = recommendations

        confidenceList = recommendations.prefix(3).enumerated().map { index, poi in
            let candidate = fusedCandidate(
                for: poi,
                location: location,
                routeSnap: routeSnap(for: location),
                indoorSignals: indoorSignalMap()
            )
            return confidenceItem(from: candidate, rank: index + 1)
        }

        guard let first = recommendations.first else { return }

        let meters = Int(distance(from: location, to: first.coordinate))
        contextPhase = .recommended
        positioningSummary = L10n.format("guide.nearbyRecommendationDistance.format", meters)
        applyCurrentPOI(first)
        updateRouteProgress(activePOI: first)
    }

    private func searchNearbyMapItems(around location: CLLocation) async -> [MKMapItem] {
        var categorySearchTimedOut = false

        for radius in mapSearchRadii {
            let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: radius)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: culturalPOICategories)

            do {
                let response = try await searchResponse(for: MKLocalSearch(request: request))
                if !response.mapItems.isEmpty {
                    return response.mapItems
                }
            } catch MapPlaceSearchError.timedOut {
                categorySearchTimedOut = true
                continue
            } catch {
                continue
            }
        }

        if categorySearchTimedOut {
            return []
        }

        let queries = [
            "museum",
            "tourist attraction",
            "landmark",
            "gallery",
            "park",
            "theater",
            "library",
            "博物馆",
            "景点",
            "地标"
        ]
        var items: [MKMapItem] = []

        for radius in mapSearchRadii {
            for query in queries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.resultTypes = .pointOfInterest
                request.region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: radius,
                    longitudinalMeters: radius
                )

                do {
                    let response = try await searchResponse(for: MKLocalSearch(request: request))
                    items.append(contentsOf: response.mapItems)
                } catch MapPlaceSearchError.timedOut {
                    return items
                } catch {
                    continue
                }
            }

            if !items.isEmpty {
                return items
            }
        }

        return items
    }

    private func searchResponse(for search: MKLocalSearch) async throws -> MKLocalSearch.Response {
        let timeout = mapPlaceSearchTimeout
        return try await withCheckedThrowingContinuation { continuation in
            let state = MapSearchState(search: search, continuation: continuation)

            search.start { response, error in
                if let response {
                    state.resume(returning: response)
                } else {
                    state.resume(throwing: error ?? MapPlaceSearchError.timedOut)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                state.resume(throwing: MapPlaceSearchError.timedOut)
            }
        }
    }

    private var culturalPOICategories: [MKPointOfInterestCategory] {
        var categories: [MKPointOfInterestCategory] = [
            .museum,
            .park,
            .theater,
            .library,
            .university,
            .nationalPark,
            .amusementPark,
            .aquarium,
            .zoo,
            .movieTheater,
            .stadium
        ]

        if #available(iOS 18.0, *) {
            categories.append(contentsOf: [
                .landmark,
                .nationalMonument,
                .castle,
                .fortress,
                .planetarium,
                .musicVenue
            ])
        }

        return categories
    }

    private func offlineCulturalRecommendations(around location: CLLocation) -> [POI] {
        let maxFallbackDistance: CLLocationDistance = 25_000
        return offlineCulturalPOIs
            .filter { distance(from: location, to: $0.coordinate) <= maxFallbackDistance }
            .sorted {
                distance(from: location, to: $0.coordinate) < distance(from: location, to: $1.coordinate)
            }
    }

    private var offlineCulturalPOIs: [POI] {
        [
            POI(
                id: "\(offlinePOIPrefix)union-square-sf",
                name: "Union Square",
                description: L10n.string("guide.offlinePOI.unionSquare.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7880, longitude: -122.4075),
                category: .building,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)sfmoma",
                name: "San Francisco Museum of Modern Art",
                description: L10n.string("guide.offlinePOI.sfmoma.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7857, longitude: -122.4011),
                category: .museum,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)contemporary-jewish-museum",
                name: "Contemporary Jewish Museum",
                description: L10n.string("guide.offlinePOI.cjm.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7863, longitude: -122.4039),
                category: .museum,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)moad",
                name: "Museum of the African Diaspora",
                description: L10n.string("guide.offlinePOI.moad.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7865, longitude: -122.4012),
                category: .museum,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)yerba-buena-gardens",
                name: "Yerba Buena Gardens",
                description: L10n.string("guide.offlinePOI.yerbaBuena.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7856, longitude: -122.4020),
                category: .garden,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)asian-art-museum-sf",
                name: "Asian Art Museum",
                description: L10n.string("guide.offlinePOI.asianArt.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7802, longitude: -122.4162),
                category: .museum,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            ),
            POI(
                id: "\(offlinePOIPrefix)cable-car-museum",
                name: "Cable Car Museum",
                description: L10n.string("guide.offlinePOI.cableCar.desc"),
                coordinate: CLLocationCoordinate2D(latitude: 37.7946, longitude: -122.4115),
                category: .museum,
                images: [],
                source: ContentSource(name: L10n.string("guide.source.offlineCultural"), type: .curated, verified: false)
            )
        ]
    }

    private func poi(from mapItem: MKMapItem) -> POI? {
        guard let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        let coordinate = mapItem.placemark.coordinate
        let locality = [
            mapItem.placemark.locality,
            mapItem.placemark.administrativeArea
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        let description: String
        if locality.isEmpty {
            description = L10n.string("guide.mapPOI.defaultDescription")
        } else {
            description = L10n.format("guide.mapPOI.localityDescription.format", locality)
        }

        return POI(
            id: "\(mapSearchPOIPrefix)\(stableMapItemID(name: name, coordinate: coordinate))",
            name: name,
            description: description,
            coordinate: coordinate,
            category: .museum,
            images: [],
            source: ContentSource(name: L10n.string("guide.source.appleMaps"), type: .curated, verified: false)
        )
    }

    private func stableMapItemID(name: String, coordinate: CLLocationCoordinate2D) -> String {
        let normalizedName = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\u{4e00}-\\u{9fa5}]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let lat = Int((coordinate.latitude * 10_000).rounded())
        let lon = Int((coordinate.longitude * 10_000).rounded())
        return "\(normalizedName)-\(lat)-\(lon)"
    }

    private func routeFromMapRecommendations(_ pois: [POI], origin: CLLocation) -> Route {
        let orderedPOIs = pois
            .sorted { distance(from: origin, to: $0.coordinate) < distance(from: origin, to: $1.coordinate) }
            .prefix(4)

        var previousCoordinate: CLLocationCoordinate2D?
        let stops = orderedPOIs.enumerated().map { index, poi in
            let distanceFromPrevious: Double?
            if let previousCoordinate {
                distanceFromPrevious = distanceBetween(previousCoordinate, and: poi.coordinate)
            } else {
                distanceFromPrevious = distance(from: origin, to: poi.coordinate)
            }
            previousCoordinate = poi.coordinate

            return RouteStop(
                id: poi.id,
                poiId: poi.id,
                name: poi.name,
                order: index,
                estimatedTime: max(90, (distanceFromPrevious ?? 120) / 1.2),
                distanceFromPrevious: distanceFromPrevious,
                state: index == 0 ? .active : .upcoming
            )
        }

        let totalDistance = stops.compactMap(\.distanceFromPrevious).reduce(0, +)
        return Route(
            id: "nearby-map-recommendations",
            name: L10n.string("guide.nearbyCultureRoute.name"),
            description: L10n.string("guide.nearbyCultureRoute.description"),
            stops: stops,
            estimatedDuration: max(600, totalDistance / 1.2),
            distance: totalDistance
        )
    }

    private func fusedCandidate(
        for poi: POI,
        location: CLLocation,
        routeSnap: RouteSnap,
        indoorSignals: [String: IndoorLocationService.POISignal]
    ) -> FusedCandidate {
        let distance = distance(from: location, to: poi.coordinate)
        let gpsConfidence = gpsConfidence(distance: distance, horizontalAccuracy: location.horizontalAccuracy)
        let routeBoost = routeBoost(for: poi, snap: routeSnap, location: location)
        let indoorBoost = indoorBoost(for: poi.id, indoorSignals: indoorSignals)
        let visualBoost = visualBoost(for: poi.id)
        let confidence = min(0.99, max(0.05, gpsConfidence + routeBoost + indoorBoost + visualBoost))

        var layers = ["GPS"]
        if routeBoost >= 0.05 { layers.append(L10n.string("guide.evidence.route")) }
        if indoorBoost >= 0.04 { layers.append(L10n.string("guide.evidence.indoor")) }
        if visualBoost >= 0.04 { layers.append(L10n.string("guide.evidence.photo")) }

        return FusedCandidate(
            poi: poi,
            distance: distance,
            gpsConfidence: gpsConfidence,
            routeBoost: routeBoost,
            indoorBoost: indoorBoost,
            visualBoost: visualBoost,
            confidence: confidence,
            layers: layers
        )
    }

    private func routeSnap(for location: CLLocation) -> RouteSnap {
        let routePOIs = currentRoute.stops.compactMap { stop in
            poi(for: stop.poiId).map { (stop: stop, poi: $0) }
        }

        guard !routePOIs.isEmpty else {
            return RouteSnap(nearestStopId: nil, nearestStopDistance: .greatestFiniteMagnitude, segmentStopIds: [], segmentDistance: .greatestFiniteMagnitude)
        }

        let nearestStop = routePOIs
            .map { item in
                (poiId: item.poi.id, distance: distance(from: location, to: item.poi.coordinate))
            }
            .min { $0.distance < $1.distance }

        var nearestSegmentIds = Set<String>()
        var nearestSegmentDistance = CLLocationDistance.greatestFiniteMagnitude

        if routePOIs.count >= 2 {
            for index in routePOIs.indices.dropLast() {
                let start = routePOIs[index]
                let end = routePOIs[routePOIs.index(after: index)]
                let segmentDistance = distanceFrom(
                    location.coordinate,
                    toSegmentStart: start.poi.coordinate,
                    end: end.poi.coordinate
                )

                if segmentDistance < nearestSegmentDistance {
                    nearestSegmentDistance = segmentDistance
                    nearestSegmentIds = [start.poi.id, end.poi.id]
                }
            }
        }

        return RouteSnap(
            nearestStopId: nearestStop?.poiId,
            nearestStopDistance: nearestStop?.distance ?? .greatestFiniteMagnitude,
            segmentStopIds: nearestSegmentIds,
            segmentDistance: nearestSegmentDistance
        )
    }

    private func routeBoost(for poi: POI, snap: RouteSnap, location: CLLocation) -> Double {
        guard currentRoute.stops.contains(where: { $0.poiId == poi.id }) else { return 0 }

        let radius = routeSnapRadius(for: location)
        var boost = 0.03

        if snap.nearestStopId == poi.id, snap.nearestStopDistance <= radius {
            boost += 0.13
        }

        if snap.segmentStopIds.contains(poi.id), snap.segmentDistance <= radius {
            boost += 0.06
        }

        return min(0.18, boost)
    }

    private func routeSnapRadius(for location: CLLocation) -> CLLocationDistance {
        let accuracy = max(location.horizontalAccuracy, 0)
        return max(24, min(68, accuracy * 1.6))
    }

    private func indoorSignalMap() -> [String: IndoorLocationService.POISignal] {
        Dictionary(
            indoorLocationService.currentPOISignals().map { ($0.poiId, $0) },
            uniquingKeysWith: { first, second in
                first.confidence >= second.confidence ? first : second
            }
        )
    }

    private func indoorBoost(
        for poiId: String,
        indoorSignals: [String: IndoorLocationService.POISignal]
    ) -> Double {
        guard let signal = indoorSignals[poiId] else { return 0 }
        return min(0.18, signal.confidence * 0.20)
    }

    private func visualBoost(for poiId: String) -> Double {
        guard let confirmation = visualConfirmations[poiId] else { return 0 }
        let age = Date().timeIntervalSince(confirmation.timestamp)
        let freshness = max(0, 1 - age / visualConfirmationTTL)
        return min(0.16, confirmation.confidence * freshness * 0.18)
    }

    private func pruneExpiredVisualConfirmations() {
        let now = Date()
        visualConfirmations = visualConfirmations.filter { _, confirmation in
            now.timeIntervalSince(confirmation.timestamp) <= visualConfirmationTTL
        }
    }

    private func positioningSummary(for candidate: FusedCandidate) -> String {
        let layerText = candidate.layers.joined(separator: "+")
        return "\(layerText) · \(Int(candidate.confidence * 100))%"
    }

    private func confidenceItem(from candidate: FusedCandidate, rank: Int) -> LocationConfidence {
        LocationConfidence(
            poi: candidate.poi,
            confidence: candidate.confidence,
            rank: rank,
            distance: candidate.distance,
            evidence: evidenceLayers(for: candidate),
            isRecommendation: candidate.poi.id.hasPrefix(mapSearchPOIPrefix) ||
                candidate.poi.id.hasPrefix(offlinePOIPrefix)
        )
    }

    private func evidenceLayers(for candidate: FusedCandidate) -> [String] {
        var evidence = candidate.layers

        if candidate.poi.id.hasPrefix(mapSearchPOIPrefix) {
            evidence.append(L10n.string("guide.evidence.mapRecommendation"))
        } else if candidate.poi.id.hasPrefix(offlinePOIPrefix) {
            evidence.append(L10n.string("guide.evidence.offlineRecommendation"))
        } else if candidate.poi.id.hasPrefix(userPOIPrefix) {
            evidence.append(L10n.string("guide.evidence.userAdded"))
        }

        if candidate.poi.source.verified {
            evidence.append(L10n.string("guide.evidence.official"))
        } else if !candidate.poi.source.name.isEmpty {
            evidence.append(localizedSourceName(candidate.poi.source.name))
        }

        var seen = Set<String>()
        return evidence.filter { seen.insert($0).inserted }
    }

    private func localizedSourceName(_ sourceName: String) -> String {
        switch sourceName {
        case "离线文化地点":
            return L10n.string("guide.source.offlineCultural")
        case "Apple 地图附近地点":
            return L10n.string("guide.source.appleMaps")
        case "用户添加":
            return L10n.string("guide.source.user")
        case "故宫博物院公开资料":
            return L10n.string("guide.source.palaceMuseum")
        default:
            return sourceName
        }
    }

    private func updateRouteProgress(activePOI: POI) {
        guard let activeStop = currentRoute.stops.first(where: { $0.poiId == activePOI.id }) else { return }

        let updatedStops = currentRoute.stops.map { stop in
            let state: StopState
            if stop.order < activeStop.order {
                state = .completed
            } else if stop.order == activeStop.order {
                state = .active
            } else {
                state = .upcoming
            }

            return RouteStop(
                id: stop.id,
                poiId: stop.poiId,
                name: stop.name,
                order: stop.order,
                estimatedTime: stop.estimatedTime,
                distanceFromPrevious: stop.distanceFromPrevious,
                state: state
            )
        }

        currentRoute = Route(
            id: currentRoute.id,
            name: currentRoute.name,
            description: currentRoute.description,
            stops: updatedStops,
            estimatedDuration: currentRoute.estimatedDuration,
            distance: currentRoute.distance
        )
    }

    private func poi(for id: String) -> POI? {
        allPOIs.first { $0.id == id } ?? POI.seedList.first { $0.id == id }
    }

    private func localNearbyRadius(for location: CLLocation) -> CLLocationDistance {
        let accuracy = max(location.horizontalAccuracy, 0)
        return max(90, min(180, accuracy * 2.2))
    }

    private func localMatchRadius(for location: CLLocation) -> CLLocationDistance {
        let accuracy = max(location.horizontalAccuracy, 0)
        return max(650, min(1_800, accuracy * 8.0))
    }

    private func gpsConfidence(distance: CLLocationDistance, horizontalAccuracy: CLLocationAccuracy) -> Double {
        let usableAccuracy = horizontalAccuracy > 0 ? min(max(horizontalAccuracy, 8), 80) : 18
        let nearRadius = max(24, usableAccuracy * 1.4)
        let midRadius = max(70, usableAccuracy * 3.0)

        switch distance {
        case 0...nearRadius:
            return 0.96 - (distance / nearRadius) * 0.10
        case nearRadius...midRadius:
            let t = (distance - nearRadius) / max(1, midRadius - nearRadius)
            return 0.86 - t * 0.32
        case midRadius...160:
            let t = (distance - midRadius) / max(1, 160 - midRadius)
            return max(0.18, 0.54 - t * 0.30)
        default:
            let t = min(1, (distance - 160) / 420)
            return max(0.06, 0.24 - t * 0.18)
        }
    }

    private func distance(from location: CLLocation, to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: targetLocation)
    }

    private func distanceBetween(
        _ first: CLLocationCoordinate2D,
        and second: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
    }

    private func distanceFrom(
        _ coordinate: CLLocationCoordinate2D,
        toSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let metersPerLatitude = 111_320.0
        let metersPerLongitude = metersPerLatitude * cos(coordinate.latitude * .pi / 180)

        func point(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
            CGPoint(
                x: coordinate.longitude * metersPerLongitude,
                y: coordinate.latitude * metersPerLatitude
            )
        }

        let p = point(coordinate)
        let a = point(start)
        let b = point(end)
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)
        let abLengthSquared = ab.x * ab.x + ab.y * ab.y

        guard abLengthSquared > 0 else {
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: start.latitude, longitude: start.longitude))
        }

        let t = max(0, min(1, (ap.x * ab.x + ap.y * ab.y) / abLengthSquared))
        let projection = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        let dx = p.x - projection.x
        let dy = p.y - projection.y
        return sqrt(dx * dx + dy * dy)
    }

    private func mergePOIs(_ current: [POI], with incoming: [POI]) -> [POI] {
        var merged: [String: POI] = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        incoming.forEach { merged[$0.id] = $0 }
        return Array(merged.values).sorted { $0.name < $1.name }
    }

    private func loadCachedPOIs() -> [POI]? {
        guard let data = UserDefaults.standard.data(forKey: cachedPOIsKey) else { return nil }
        return try? JSONDecoder().decode([POI].self, from: data)
    }

    private func saveCachedPOIs(_ pois: [POI]) {
        guard let data = try? JSONEncoder().encode(pois) else { return }
        UserDefaults.standard.set(data, forKey: cachedPOIsKey)
    }

    private func loadCachedMapRecommendations(around location: CLLocation) -> [POI]? {
        guard let data = UserDefaults.standard.data(forKey: cachedMapRecommendationsKey),
              let cache = try? JSONDecoder().decode(CachedMapRecommendations.self, from: data),
              Date().timeIntervalSince(cache.timestamp) <= mapRecommendationCacheMaxAge else {
            return nil
        }

        let cacheLocation = CLLocation(latitude: cache.latitude, longitude: cache.longitude)
        guard location.distance(from: cacheLocation) <= mapRecommendationCacheRadius else {
            return nil
        }

        return cache.pois
    }

    private func saveCachedMapRecommendations(_ pois: [POI], around location: CLLocation) {
        let cache = CachedMapRecommendations(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date(),
            pois: pois
        )

        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: cachedMapRecommendationsKey)
    }

    private func updateGuide(for style: GuideStyle) {
        guard let poi = currentPOI else { return }

        let transcript = localNarrationTranscript(for: poi, style: style)

        currentGuide = AudioGuide(
            id: "\(poi.id)-\(style.rawValue)-\(selectedDuration.rawValue)",
            poiId: poi.id,
            style: style,
            duration: selectedDuration,
            transcript: transcript,
            audioURL: nil,
            source: poi.source
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var nextRouteStop: RouteStop? {
        guard let currentPOI = currentPOI,
              let currentIndex = currentRoute.stops.firstIndex(where: { $0.poiId == currentPOI.id }) else {
            return currentRoute.stops.first { $0.state == .upcoming }
        }

        let nextIndex = currentRoute.stops.index(after: currentIndex)
        guard nextIndex < currentRoute.stops.endIndex else { return nil }
        return currentRoute.stops[nextIndex]
    }

    /// Prefetch the next stop's guide in the background
    func prefetchNextStopGuide() {
        guard let nextStop = nextRouteStop else { return }
        let nextPoiId = nextStop.poiId
        let style = selectedStyle
        let duration = selectedDuration
        let cacheKey = "\(nextPoiId)-\(style.rawValue)-\(duration.rawValue)"

        // If already prefetched, do nothing
        guard prefetchedGuides[cacheKey] == nil else { return }
        if let cachedGuide = historyService.getCachedGuide(for: cacheKey) {
            prefetchedGuides[cacheKey] = cachedGuide
            return
        }

        if prefersOfflineMode {
            cacheLocalGuideForPrefetch(poiId: nextPoiId, style: style, duration: duration, cacheKey: cacheKey)
            return
        }

        Task {
            do {
                let body: [String: Any] = [
                    "poi_id": nextPoiId,
                    "style": style.rawValue,
                    "duration": duration.rawValue
                ]

                let response: NarrateResponse = try await apiClient.post(
                    endpoint: APIConfig.Endpoints.guideNarrate,
                    body: body
                )

                let guide = AudioGuide(
                    id: response.id,
                    poiId: response.poiId,
                    style: response.style,
                    duration: response.duration,
                    transcript: response.transcript,
                    audioURL: response.audioUrl,
                    source: response.source
                )

                prefetchedGuides[cacheKey] = guide
                historyService.cacheGuide(guide, for: cacheKey)
                print("Successfully prefetched guide for \(nextPoiId)")
            } catch {
                // Generate a local fallback and cache it
                if let poi = allPOIs.first(where: { $0.id == nextPoiId }) {
                    let transcript = localNarrationTranscript(for: poi, style: style)

                    let guide = AudioGuide(
                        id: "\(poi.id)-\(style.rawValue)-\(duration.rawValue)",
                        poiId: poi.id,
                        style: style,
                        duration: duration,
                        transcript: transcript,
                        audioURL: nil,
                        source: poi.source
                    )
                    prefetchedGuides[cacheKey] = guide
                    historyService.cacheGuide(guide, for: cacheKey)
                }
            }
        }
    }

    private func cacheLocalGuideForPrefetch(
        poiId: String,
        style: GuideStyle,
        duration: GuideDuration,
        cacheKey: String
    ) {
        guard let poi = allPOIs.first(where: { $0.id == poiId }) else { return }

        let guide = AudioGuide(
            id: "\(poi.id)-\(style.rawValue)-\(duration.rawValue)",
            poiId: poi.id,
            style: style,
            duration: duration,
            transcript: localNarrationTranscript(for: poi, style: style),
            audioURL: nil,
            source: poi.source
        )
        prefetchedGuides[cacheKey] = guide
        historyService.cacheGuide(guide, for: cacheKey)
    }

    private func localNarrationTranscript(for poi: POI, style: GuideStyle) -> String {
        switch style {
        case .history:
            return L10n.format("guide.localNarration.history.format", poi.name, poi.description)
        case .architecture:
            return L10n.format("guide.localNarration.architecture.format", poi.name, poi.description)
        case .children:
            return L10n.format("guide.localNarration.children.format", poi.name, poi.description)
        case .legend:
            return L10n.format("guide.localNarration.legend.format", poi.name)
        case .casual:
            return L10n.format("guide.localNarration.casual.format", poi.name, poi.description)
        case .inDepth:
            return L10n.format("guide.localNarration.inDepth.format", poi.name, poi.description)
        }
    }
}

private extension Array where Element == POI {
    func uniquedByID() -> [POI] {
        var seen = Set<String>()
        return filter { poi in
            guard !seen.contains(poi.id) else { return false }
            seen.insert(poi.id)
            return true
        }
    }
}

// MARK: - Response Models
struct ContextResponse: Codable {
    let poi: POI?
    let confidence: Double
    let nearbyPois: [POI]
    let routeProgress: RouteProgress?

    enum CodingKeys: String, CodingKey {
        case poi, confidence
        case nearbyPois = "nearby_pois"
        case routeProgress = "route_progress"
    }
}

struct RouteProgress: Codable {
    let currentStop: Int
    let totalStops: Int
    let nextStop: RouteStop?
    let estimatedTimeRemaining: TimeInterval

    enum CodingKeys: String, CodingKey {
        case currentStop = "current_stop"
        case totalStops = "total_stops"
        case nextStop = "next_stop"
        case estimatedTimeRemaining = "estimated_time_remaining"
    }
}

struct NarrateResponse: Codable {
    let id: String
    let poiId: String
    let style: GuideStyle
    let duration: GuideDuration
    let transcript: String
    let audioUrl: URL?
    let source: ContentSource

    enum CodingKeys: String, CodingKey {
        case id
        case poiId = "poi_id"
        case style, duration, transcript
        case audioUrl = "audio_url"
        case source
    }
}

struct QAResponse: Codable {
    let answer: String
    let sources: [ContentSource]
    let confidence: Double
}
