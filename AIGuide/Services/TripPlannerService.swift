// Trip Planner Service - Route Planning & Journey Review

import Foundation
import SwiftUI
import MapKit

@MainActor
class TripPlannerService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentTrip: Trip?
    @Published var savedTrips: [Trip] = []
    @Published var tripTemplates: [TripTemplate] = []
    @Published var isPlanning = false
    @Published var selectedDay: Int = 1
    @Published var searchResults: [DestinationSearchResult] = []
    @Published var isSearching = false
    @Published var searchError: String?

    // MARK: - Types
    struct Trip: Identifiable, Codable {
        let id: String
        var name: String
        var description: String
        var startDate: Date
        var endDate: Date
        var days: [TripDay]
        var coverImage: String?
        var status: TripStatus
        var notes: [TripNote]

        var duration: Int {
            Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        }

        var formattedDateRange: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }

        enum TripStatus: String, Codable {
            case planning = "规划中"
            case ongoing = "进行中"
            case completed = "已完成"

            var localizedName: String {
                switch self {
                case .planning: return L10n.string("trip.status.planning")
                case .ongoing: return L10n.string("trip.status.ongoing")
                case .completed: return L10n.string("trip.status.completed")
                }
            }

            var color: Color {
                switch self {
                case .planning: return .orange
                case .ongoing: return .green
                case .completed: return .blue
                }
            }
        }
    }

    struct TripDay: Identifiable, Codable {
        let id: String
        let dayNumber: Int
        var title: String
        var spots: [TripSpot]
        var transportation: [Transportation]
        var accommodation: String?
        var notes: String?

        var formattedDate: String {
            L10n.format("trip.day.title.format", dayNumber)
        }
    }

    struct TripSpot: Identifiable, Codable {
        let id: String
        let poiId: String
        let name: String
        let address: String?
        let arrivalTime: Date?
        let duration: TimeInterval?
        let category: SpotCategory
        let priority: Priority
        let notes: String?
        var isVisited: Bool = false

        enum SpotCategory: String, Codable {
            case scenic = "景点"
            case museum = "博物馆"
            case restaurant = "餐厅"
            case hotel = "住宿"
            case transport = "交通"
            case shopping = "购物"

            var localizedName: String {
                switch self {
                case .scenic: return L10n.string("trip.category.scenic")
                case .museum: return L10n.string("trip.category.museum")
                case .restaurant: return L10n.string("trip.category.restaurant")
                case .hotel: return L10n.string("trip.category.hotel")
                case .transport: return L10n.string("trip.category.transport")
                case .shopping: return L10n.string("trip.category.shopping")
                }
            }
        }

        enum Priority: String, Codable {
            case mustSee = "必去"
            case recommended = "推荐"
            case optional = "可选"

            var localizedName: String {
                switch self {
                case .mustSee: return L10n.string("trip.priority.mustSee")
                case .recommended: return L10n.string("trip.priority.recommended")
                case .optional: return L10n.string("trip.priority.optional")
                }
            }

            var color: Color {
                switch self {
                case .mustSee: return .red
                case .recommended: return .orange
                case .optional: return .gray
                }
            }
        }
    }

    struct Transportation: Identifiable, Codable {
        let id: String
        let from: String
        let to: String
        let mode: TransportMode
        let duration: TimeInterval?
        let cost: Double?

        enum TransportMode: String, Codable {
            case walking = "步行"
            case subway = "地铁"
            case bus = "公交"
            case taxi = "打车"
            case car = "自驾"

            var icon: String {
                switch self {
                case .walking: return "figure.walk"
                case .subway: return "tram.fill"
                case .bus: return "bus.fill"
                case .taxi: return "car.fill"
                case .car: return "car.fill"
                }
            }
        }
    }

    struct TripNote: Identifiable, Codable {
        let id: String
        let dayId: String?
        let content: String
        let timestamp: Date
        let tag: NoteTag?

        enum NoteTag: String, Codable {
            case tip = "贴士"
            case warning = "注意"
            case memory = "回忆"
        }
    }

    struct TripTemplate: Identifiable {
        let id: String
        let name: String
        let description: String
        let duration: Int
        let highlights: [String]
        let spots: [String]

        static var mockTemplates: [TripTemplate] {
            [
            TripTemplate(
                id: "t1",
                name: L10n.string("trip.template.forbiddenCityOneDay.name"),
                description: L10n.string("trip.template.forbiddenCityOneDay.description"),
                duration: 1,
                highlights: [
                    L10n.string("poi.taihedian.name"),
                    L10n.string("poi.qianqinggong.name"),
                    L10n.string("poi.yuhuayuan.name")
                ],
                spots: ["wumen", "taihedian", "zhonghedian", "baohedian", "qianqinggong", "yuhuayuan"]
            ),
            TripTemplate(
                id: "t2",
                name: L10n.string("trip.template.forbiddenCityTwoDay.name"),
                description: L10n.string("trip.template.forbiddenCityTwoDay.description"),
                duration: 2,
                highlights: [
                    L10n.string("trip.template.highlight.threeHalls"),
                    L10n.string("trip.template.highlight.innerPalaces"),
                    L10n.string("trip.template.highlight.treasures"),
                    L10n.string("trip.template.highlight.clocks")
                ],
                spots: ["wumen", "taihedian", "zhonghedian", "baohedian", "qianqinggong", "kunninggong", "yuhuayuan"]
            ),
            TripTemplate(
                id: "t3",
                name: L10n.string("trip.template.beijingCulture.name"),
                description: L10n.string("trip.template.beijingCulture.description"),
                duration: 3,
                highlights: [
                    L10n.string("trip.template.highlight.forbiddenCity"),
                    L10n.string("trip.template.highlight.templeOfHeaven"),
                    L10n.string("trip.template.highlight.greatWall"),
                    L10n.string("trip.template.highlight.summerPalace")
                ],
                spots: ["taihedian", "tiantan", "greatwall", "summerpalace"]
            )
            ]
        }
    }

    struct DestinationSearchResult: Identifiable {
        let id: String
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
        let mapItem: MKMapItem
    }

    struct TripPlanPreferences: Equatable {
        var durationHours: Int = 4
        var interest: Interest = .essentials
        var audience: Audience = .general
        var pace: Pace = .balanced

        enum Interest: String, CaseIterable {
            case essentials
            case history
            case architecture
            case photography
        }

        enum Audience: String, CaseIterable {
            case general
            case family
            case kids
        }

        enum Pace: String, CaseIterable {
            case relaxed
            case balanced
            case efficient
        }

        var maxStops: Int {
            let baseStops: Int
            switch durationHours {
            case ...2: baseStops = 3
            case 3...4: baseStops = 5
            default: baseStops = 6
            }

            switch pace {
            case .relaxed: return max(2, baseStops - 1)
            case .balanced: return baseStops
            case .efficient: return min(7, baseStops + 1)
            }
        }

        var mainStopMinutes: Int {
            switch durationHours {
            case ...2: return 55
            case 3...4: return 75
            default: return 95
            }
        }

        var secondaryStopMinutes: Int {
            switch pace {
            case .relaxed: return 42
            case .balanced: return 35
            case .efficient: return 28
            }
        }

        var llmPayload: [String: Any] {
            [
                "duration_hours": durationHours,
                "interest": interest.rawValue,
                "audience": audience.rawValue,
                "pace": pace.rawValue,
                "max_stops": maxStops
            ]
        }
    }

    private struct DestinationPlace {
        let id: String
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    private struct LLMTripPlanResponse: Codable {
        let title: String
        let summary: String
        let estimatedMinutes: Int
        let stops: [LLMTripPlanStop]
        let tips: [String]
        let source: String

        enum CodingKeys: String, CodingKey {
            case title, summary, stops, tips, source
            case estimatedMinutes = "estimated_minutes"
        }
    }

    private struct LLMTripPlanStop: Codable {
        let name: String
        let poiId: String?
        let address: String?
        let category: String
        let priority: String
        let durationMinutes: Int
        let arrivalOffsetMinutes: Int
        let highlight: String

        enum CodingKeys: String, CodingKey {
            case name, address, category, priority, highlight
            case poiId = "poi_id"
            case durationMinutes = "duration_minutes"
            case arrivalOffsetMinutes = "arrival_offset_minutes"
        }
    }

    // MARK: - Private Properties
    private let storageKey = "com.aiguide.trips"
    private let defaults = UserDefaults.standard
    private let apiClient = APIClient()
    private let placeResolver = GlobalPlaceResolver.shared

    // MARK: - Initialization
    init() {
        loadTrips()
        refreshLocalizedTemplates()
    }

    // MARK: - Public Methods

    func refreshLocalizedTemplates() {
        tripTemplates = TripTemplate.mockTemplates
    }

    /// Load a deterministic local trip for simulator screenshot checks.
    func loadQASampleTrip() {
        guard let destination = placeResolver.knownDestinations(matching: "Louvre Museum Paris").first else {
            return
        }

        currentTrip = buildFallbackTrip(destination: destinationResult(from: destination), nearbyItems: [])
        isPlanning = true
    }

    /// Create a new trip
    func createTrip(name: String, description: String, startDate: Date, endDate: Date) -> Trip {
        let trip = Trip(
            id: UUID().uuidString,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            days: [],
            status: .planning,
            notes: []
        )

        currentTrip = trip
        isPlanning = true
        return trip
    }

    /// Create trip from template
    func createTripFromTemplate(_ template: TripTemplate, startDate: Date) -> Trip {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: template.duration - 1, to: startDate) ?? startDate

        var trip = createTrip(
            name: template.name,
            description: template.description,
            startDate: startDate,
            endDate: endDate
        )

        // Create days
        for dayNum in 1...template.duration {
            let day = TripDay(
                id: UUID().uuidString,
                dayNumber: dayNum,
                title: L10n.format("trip.day.title.format", dayNum),
                spots: [],
                transportation: []
            )
            trip.days.append(day)
        }

        currentTrip = trip
        return trip
    }

    /// Search any destination/place through Apple Maps.
    func searchDestinations(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchError = nil
            return
        }

        isSearching = true
        searchError = nil
        defer { isSearching = false }

        let knownMatches = placeResolver.knownDestinations(matching: trimmed)
        if !knownMatches.isEmpty {
            searchResults = await searchKnownDestinations(knownMatches, originalQuery: trimmed)
            searchError = searchResults.isEmpty ? L10n.string("trip.search.error.empty") : nil
            return
        }

        do {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed

            let response = try await MKLocalSearch(request: request).start()
            searchResults = placeResolver.rankedMapItems(response.mapItems, query: trimmed)
                .prefix(10)
                .compactMap(destinationResult(from:))

            if searchResults.isEmpty {
                searchError = L10n.string("trip.search.error.empty")
            }
        } catch {
            searchResults = []
            searchError = L10n.string("trip.search.error.unavailable")
        }
    }

    /// Generate a practical one-day route and highlights from a searched place.
    func generateRecommendedTrip(
        for result: DestinationSearchResult,
        preferences: TripPlanPreferences = TripPlanPreferences()
    ) async {
        isSearching = true
        searchError = nil
        defer { isSearching = false }

        let nearbyItems = await searchNearbyHighlights(around: result)
        let trip: Trip
        do {
            let response = try await requestLLMTripPlan(destination: result, nearbyItems: nearbyItems, preferences: preferences)
            trip = buildTrip(from: response, destination: result, nearbyItems: nearbyItems, preferences: preferences)
        } catch {
            trip = buildFallbackTrip(destination: result, nearbyItems: nearbyItems, preferences: preferences)
        }

        currentTrip = trip
        isPlanning = true
        saveTrip()
    }

    /// Generate through the LLM even when Apple Maps search is temporarily unavailable.
    func generateRecommendedTrip(
        forKeyword keyword: String,
        preferences: TripPlanPreferences = TripPlanPreferences()
    ) async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        searchError = nil
        defer { isSearching = false }

        if let knownDestination = placeResolver.knownDestinations(matching: trimmed).first {
            await generateRecommendedTrip(for: destinationResult(from: knownDestination), preferences: preferences)
            return
        }

        let fallbackCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let placemark = MKPlacemark(coordinate: fallbackCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = trimmed

        let destination = DestinationSearchResult(
            id: stableID(for: trimmed, coordinate: fallbackCoordinate),
            name: trimmed,
            subtitle: L10n.string("trip.search.keywordDestination"),
            coordinate: fallbackCoordinate,
            mapItem: mapItem
        )

        let trip: Trip
        do {
            let response = try await requestLLMTripPlan(destination: destination, nearbyItems: [], preferences: preferences)
            trip = buildTrip(from: response, destination: destination, nearbyItems: [], preferences: preferences)
        } catch {
            trip = buildFallbackTrip(destination: destination, nearbyItems: [], preferences: preferences)
        }

        currentTrip = trip
        isPlanning = true
        saveTrip()
    }

    /// Add spot to a day
    func addSpot(toDay dayIndex: Int, spot: TripSpot) {
        guard var trip = currentTrip, dayIndex < trip.days.count else { return }

        trip.days[dayIndex].spots.append(spot)
        currentTrip = trip
    }

    /// Mark spot as visited
    func markSpotVisited(dayIndex: Int, spotIndex: Int) {
        guard var trip = currentTrip,
              dayIndex < trip.days.count,
              spotIndex < trip.days[dayIndex].spots.count else { return }

        let spot = trip.days[dayIndex].spots[spotIndex]
        if !spot.isVisited {
            let noteContent = L10n.format("trip.memory.visitCompleted.format", spot.name)
            trip.notes.append(
                TripNote(
                    id: UUID().uuidString,
                    dayId: trip.days[dayIndex].id,
                    content: noteContent,
                    timestamp: Date(),
                    tag: .memory
                )
            )
            JourneyMemoryStore.shared.addVisitedSpot(
                tripName: trip.name,
                spotName: spot.name,
                summary: noteContent
            )
        }
        trip.days[dayIndex].spots[spotIndex].isVisited = true
        currentTrip = trip
        saveTrip()
    }

    /// Add a user-authored field note for a spot and mirror it into shared journey memory.
    func addSpotMemory(dayIndex: Int, spotIndex: Int, content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty,
              var trip = currentTrip,
              dayIndex < trip.days.count,
              spotIndex < trip.days[dayIndex].spots.count else { return }

        let spot = trip.days[dayIndex].spots[spotIndex]
        let noteContent = L10n.format("trip.memory.spotNote.format", spot.name, trimmedContent)
        trip.notes.append(
            TripNote(
                id: UUID().uuidString,
                dayId: trip.days[dayIndex].id,
                content: noteContent,
                timestamp: Date(),
                tag: .memory
            )
        )
        currentTrip = trip
        saveTrip()

        JourneyMemoryStore.shared.addSpotMemory(
            tripName: trip.name,
            spotName: spot.name,
            note: trimmedContent
        )
    }

    /// Add note to trip
    func addNote(content: String, dayId: String? = nil, tag: TripNote.NoteTag? = nil) {
        guard var trip = currentTrip else { return }

        let note = TripNote(
            id: UUID().uuidString,
            dayId: dayId,
            content: content,
            timestamp: Date(),
            tag: tag
        )

        trip.notes.append(note)
        currentTrip = trip
        saveTrip()
    }

    /// Save trip
    func saveTrip() {
        guard let trip = currentTrip else { return }

        if let index = savedTrips.firstIndex(where: { $0.id == trip.id }) {
            savedTrips[index] = trip
        } else {
            savedTrips.append(trip)
        }

        saveTrips()
    }

    /// Complete trip
    func completeTrip() {
        guard var trip = currentTrip else { return }

        trip.status = .completed
        trip.endDate = Date()
        currentTrip = trip
        saveTrip()
        isPlanning = false
    }

    /// Delete trip
    func deleteTrip(_ trip: Trip) {
        savedTrips.removeAll { $0.id == trip.id }
        saveTrips()
    }

    /// Get trip summary
    func getTripSummary() -> String? {
        guard let trip = currentTrip else { return nil }

        var summary = "## \(trip.name)\n\n"
        summary += "\(trip.description)\n\n"
        summary += "📅 \(trip.formattedDateRange)\n"
        summary += "⏱️ \(L10n.format("trip.summary.days.format", trip.duration + 1))\n\n"

        for day in trip.days {
            summary += "### \(day.title)\n"

            for spot in day.spots {
                let status = spot.isVisited ? "✅" : "⬜️"
                summary += "\(status) \(spot.name) (\(spot.category.localizedName))\n"
            }

            summary += "\n"
        }

        return summary
    }

    /// Export trip as shareable text
    func exportTrip() -> String? {
        guard let trip = currentTrip else { return nil }

        var text = "📍 \(trip.name)\n"
        text += "\(trip.formattedDateRange)\n\n"

        for day in trip.days {
            text += "🗓 \(day.title)\n"
            for spot in day.spots {
                text += "  • \(spot.name)\n"
            }
            text += "\n"
        }

        text += L10n.string("trip.export.tags")

        return text
    }

    // MARK: - Private Methods

    private func loadTrips() {
        guard let data = defaults.data(forKey: storageKey),
              let trips = try? JSONDecoder().decode([Trip].self, from: data) else {
            return
        }
        savedTrips = trips
    }

    private func saveTrips() {
        if let data = try? JSONEncoder().encode(savedTrips) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func requestLLMTripPlan(
        destination: DestinationSearchResult,
        nearbyItems: [MKMapItem],
        preferences: TripPlanPreferences
    ) async throws -> LLMTripPlanResponse {
        let candidates = nearbyItems.prefix(8).compactMap(placePayload(from:))
        var body: [String: Any] = [
            "destination": placePayload(from: destination),
            "candidates": candidates,
            "audience": L10n.string("trip.llm.audience.general")
        ]
        preferences.llmPayload.forEach { key, value in
            body[key] = value
        }

        return try await apiClient.post(endpoint: APIConfig.Endpoints.tripPlan, body: body)
    }

    private func buildTrip(
        from response: LLMTripPlanResponse,
        destination: DestinationSearchResult,
        nearbyItems: [MKMapItem],
        preferences: TripPlanPreferences
    ) -> Trip {
        let startDate = Date()
        let placeLookup = placeLookup(destination: destination, nearbyItems: nearbyItems)
        let spots = response.stops.prefix(preferences.maxStops).enumerated().map { index, stop in
            let sourcePlace = stop.poiId.flatMap { placeLookup[$0] }
            let poiId = stop.poiId ?? sourcePlace?.id ?? "llm-\(index)-\(stableID(for: stop.name, coordinate: destination.coordinate))"
            return TripSpot(
                id: UUID().uuidString,
                poiId: poiId,
                name: stop.name,
                address: stop.address ?? sourcePlace?.subtitle,
                arrivalTime: Calendar.current.date(byAdding: .minute, value: stop.arrivalOffsetMinutes, to: startDate),
                duration: TimeInterval(max(5, stop.durationMinutes) * 60),
                category: spotCategory(from: stop.category),
                priority: priority(from: stop.priority, index: index),
                notes: stop.highlight
            )
        }

        let finalSpots = spots.isEmpty ? buildRecommendedSpots(destination: destination, nearbyItems: nearbyItems, preferences: preferences) : spots
        let day = TripDay(
            id: UUID().uuidString,
            dayNumber: 1,
            title: response.title,
            spots: finalSpots,
            transportation: buildTransportation(for: finalSpots),
            accommodation: nil,
            notes: response.summary
        )

        return Trip(
            id: "generated-\(stableID(for: destination.name, coordinate: destination.coordinate))",
            name: response.title,
            description: response.summary,
            startDate: startDate,
            endDate: startDate,
            days: [day],
            status: .planning,
            notes: response.tips.prefix(4).map { tip in
                TripNote(
                    id: UUID().uuidString,
                    dayId: day.id,
                    content: tip,
                    timestamp: Date(),
                    tag: .tip
                )
            }
        )
    }

    private func buildFallbackTrip(
        destination: DestinationSearchResult,
        nearbyItems: [MKMapItem],
        preferences: TripPlanPreferences = TripPlanPreferences()
    ) -> Trip {
        let spots = buildRecommendedSpots(destination: destination, nearbyItems: nearbyItems, preferences: preferences)
        let startDate = Date()
        let day = TripDay(
            id: UUID().uuidString,
            dayNumber: 1,
            title: L10n.format("trip.fallback.dayTitle.format", destination.name),
            spots: spots,
            transportation: buildTransportation(for: spots),
            accommodation: nil,
            notes: L10n.string("trip.fallback.dayNotes")
        )

        return Trip(
            id: "generated-\(stableID(for: destination.name, coordinate: destination.coordinate))",
            name: L10n.format("trip.fallback.tripName.format", destination.name),
            description: L10n.string("trip.fallback.description"),
            startDate: startDate,
            endDate: startDate,
            days: [day],
            status: .planning,
            notes: [
                TripNote(
                    id: UUID().uuidString,
                    dayId: day.id,
                    content: L10n.string("trip.fallback.arrivalTip"),
                    timestamp: Date(),
                    tag: .tip
                )
            ]
        )
    }

    private func placePayload(from result: DestinationSearchResult) -> [String: Any] {
        [
            "id": result.id,
            "name": result.name,
            "subtitle": result.subtitle,
            "latitude": result.coordinate.latitude,
            "longitude": result.coordinate.longitude,
            "category": category(for: result.name, subtitle: result.subtitle).rawValue
        ]
    }

    private func placePayload(from mapItem: MKMapItem) -> [String: Any]? {
        guard let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        let coordinate = mapItem.placemark.coordinate
        let subtitle = mapItem.placemark.title ?? L10n.string("trip.search.mapResult")
        return [
            "id": stableID(for: name, coordinate: coordinate),
            "name": name,
            "subtitle": subtitle,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "category": category(for: name, subtitle: subtitle).rawValue
        ]
    }

    private func placeLookup(destination: DestinationSearchResult, nearbyItems: [MKMapItem]) -> [String: DestinationPlace] {
        var lookup = [
            destination.id: DestinationPlace(
                id: destination.id,
                name: destination.name,
                subtitle: destination.subtitle,
                coordinate: destination.coordinate
            )
        ]

        for item in nearbyItems {
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                continue
            }

            let coordinate = item.placemark.coordinate
            let id = stableID(for: name, coordinate: coordinate)
            lookup[id] = DestinationPlace(
                id: id,
                name: name,
                subtitle: item.placemark.title ?? L10n.string("trip.search.mapResult"),
                coordinate: coordinate
            )
        }

        return lookup
    }

    private func searchKnownDestinations(_ destinations: [GlobalKnownDestination], originalQuery: String) async -> [DestinationSearchResult] {
        var results: [DestinationSearchResult] = []

        for destination in destinations.prefix(4) {
            let knownResults = await searchKnownDestination(destination, originalQuery: originalQuery)
            for result in knownResults {
                appendUnique(result, to: &results)
            }
        }

        return Array(results.prefix(10))
    }

    private func searchKnownDestination(_ destination: GlobalKnownDestination, originalQuery: String) async -> [DestinationSearchResult] {
        let canonicalResult = destinationResult(from: destination)
        let region = MKCoordinateRegion(
            center: destination.coordinate,
            latitudinalMeters: 8_000,
            longitudinalMeters: 8_000
        )
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destination.searchQuery
        request.region = region

        var results: [DestinationSearchResult] = [canonicalResult]

        do {
            let response = try await MKLocalSearch(request: request).start()
            for result in placeResolver.rankedMapItems(response.mapItems, query: destination.searchQuery).compactMap(destinationResult(from:)) {
                guard isRelevant(result, to: destination),
                      isTourismSearchResult(result) else {
                    continue
                }
                appendUnique(result, to: &results)
            }
        } catch {
            return await appendGeneralSearchResults(for: originalQuery, to: results)
        }

        return await appendGeneralSearchResults(for: originalQuery, to: results)
    }

    private func appendGeneralSearchResults(
        for query: String,
        to prioritizedResults: [DestinationSearchResult]
    ) async -> [DestinationSearchResult] {
        var results = prioritizedResults
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        do {
            let response = try await MKLocalSearch(request: request).start()
            for result in placeResolver.rankedMapItems(response.mapItems, query: query).compactMap(destinationResult(from:)) {
                guard isTourismSearchResult(result) else { continue }
                appendUnique(result, to: &results)
            }
        } catch {
            return Array(results.prefix(10))
        }

        return Array(results.prefix(10))
    }

    private func destinationResult(from destination: GlobalKnownDestination) -> DestinationSearchResult {
        let placemark = MKPlacemark(coordinate: destination.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        let localizedName = destination.displayName
        mapItem.name = localizedName

        let displayParts = [localizedName, destination.localName]
            .compactMap { $0 }
            .reduce(into: [String]()) { parts, item in
                if !parts.contains(item) {
                    parts.append(item)
                }
            }
        let displayName = displayParts.joined(separator: " / ")

        return DestinationSearchResult(
            id: destination.id,
            name: displayName.isEmpty ? localizedName : displayName,
            subtitle: "\(destination.displaySubtitle) · \(destination.displayAddress)",
            coordinate: destination.coordinate,
            mapItem: mapItem
        )
    }

    private func isRelevant(_ result: DestinationSearchResult, to destination: GlobalKnownDestination) -> Bool {
        let distanceToKnown = distance(from: result.coordinate, to: destination.coordinate)
        if distanceToKnown <= 12_000 {
            return true
        }

        let text = normalizedSearchText("\(result.name) \(result.subtitle)")
        return destination.disambiguators
            .map(normalizedSearchText)
            .contains { clue in
                !clue.isEmpty && text.contains(clue)
            }
    }

    private func isTourismSearchResult(_ result: DestinationSearchResult) -> Bool {
        placeResolver.shouldKeepMapResult(
            name: result.name,
            subtitle: result.subtitle,
            category: result.mapItem.pointOfInterestCategory
        )
    }

    private func appendUnique(_ result: DestinationSearchResult, to results: inout [DestinationSearchResult]) {
        let duplicate = results.contains { existing in
            let distanceBetweenResults = distance(from: existing.coordinate, to: result.coordinate)
            return existing.id == result.id ||
                distanceBetweenResults < 40 ||
                (normalizedSearchText(existing.name) == normalizedSearchText(result.name) && distanceBetweenResults < 1_000)
        }

        if !duplicate {
            results.append(result)
        }
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
    }

    private func destinationResult(from mapItem: MKMapItem) -> DestinationSearchResult? {
        guard let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }

        let coordinate = mapItem.placemark.coordinate
        let subtitle = [
            mapItem.placemark.title,
            mapItem.phoneNumber,
            mapItem.url?.host()
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty && $0 != name } ?? L10n.string("trip.search.mapResult")

        return DestinationSearchResult(
            id: stableID(for: name, coordinate: coordinate),
            name: name,
            subtitle: subtitle,
            coordinate: coordinate,
            mapItem: mapItem
        )
    }

    private func searchNearbyHighlights(around result: DestinationSearchResult) async -> [MKMapItem] {
        let region = MKCoordinateRegion(
            center: result.coordinate,
            latitudinalMeters: 2_400,
            longitudinalMeters: 2_400
        )
        let queries = [
            "museum",
            "landmark",
            "attraction",
            "gallery",
            "historic site"
        ]

        var uniqueItems: [String: MKMapItem] = [:]
        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region

            do {
                let response = try await MKLocalSearch(request: request).start()
                for item in placeResolver.rankedMapItems(response.mapItems, query: query) {
                    guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty,
                          name != result.name else {
                        continue
                    }
                    let subtitle = item.placemark.title ?? L10n.string("trip.search.nearMainSpot")
                    guard placeResolver.shouldKeepMapResult(
                        name: name,
                        subtitle: subtitle,
                        category: item.pointOfInterestCategory
                    ) else {
                        continue
                    }

                    let id = stableID(for: name, coordinate: item.placemark.coordinate)
                    uniqueItems[id] = item
                }
            } catch {
                continue
            }
        }

        return Array(uniqueItems.values)
            .sorted { first, second in
                distance(from: result.coordinate, to: first.placemark.coordinate) <
                    distance(from: result.coordinate, to: second.placemark.coordinate)
            }
            .prefix(5)
            .map { $0 }
    }

    private func buildRecommendedSpots(
        destination: DestinationSearchResult,
        nearbyItems: [MKMapItem],
        preferences: TripPlanPreferences
    ) -> [TripSpot] {
        let startDate = Date()
        var spots: [TripSpot] = [
            TripSpot(
                id: UUID().uuidString,
                poiId: destination.id,
                name: destination.name,
                address: destination.subtitle,
                arrivalTime: startDate,
                duration: TimeInterval(preferences.mainStopMinutes * 60),
                category: category(for: destination.name, subtitle: destination.subtitle),
                priority: .mustSee,
                notes: L10n.string("trip.spot.mainNotes")
            )
        ]

        let nearbyLimit = max(0, preferences.maxStops - 1)
        let nearbySpots = nearbyItems.prefix(nearbyLimit).enumerated().compactMap { index, item -> TripSpot? in
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }

            let subtitle = item.placemark.title ?? L10n.string("trip.search.nearMainSpot")
            let arrivalOffset = preferences.mainStopMinutes + 15 + index * (preferences.secondaryStopMinutes + 10)
            return TripSpot(
                id: UUID().uuidString,
                poiId: stableID(for: name, coordinate: item.placemark.coordinate),
                name: name,
                address: subtitle,
                arrivalTime: Calendar.current.date(byAdding: .minute, value: arrivalOffset, to: startDate),
                duration: TimeInterval(preferences.secondaryStopMinutes * 60),
                category: category(for: name, subtitle: subtitle),
                priority: index < 2 ? .recommended : .optional,
                notes: note(for: name, subtitle: subtitle, index: index)
            )
        }

        spots.append(contentsOf: nearbySpots)

        let minFallbackCount = min(3, preferences.maxStops)
        if spots.count < minFallbackCount {
            spots.append(contentsOf: fallbackSpots(for: destination, preferences: preferences, startDate: startDate).prefix(minFallbackCount - spots.count))
        }

        return spots
    }

    private func fallbackSpots(
        for destination: DestinationSearchResult,
        preferences: TripPlanPreferences,
        startDate: Date
    ) -> [TripSpot] {
        [
            TripSpot(
                id: UUID().uuidString,
                poiId: "\(destination.id)-context",
                name: L10n.string("trip.fallback.contextSpot.name"),
                address: destination.subtitle,
                arrivalTime: Calendar.current.date(byAdding: .minute, value: preferences.mainStopMinutes + 15, to: startDate),
                duration: TimeInterval(preferences.secondaryStopMinutes * 60),
                category: .scenic,
                priority: .recommended,
                notes: L10n.string("trip.fallback.contextSpot.notes")
            ),
            TripSpot(
                id: UUID().uuidString,
                poiId: "\(destination.id)-break",
                name: L10n.string("trip.fallback.breakSpot.name"),
                address: L10n.string("trip.fallback.walkable"),
                arrivalTime: Calendar.current.date(byAdding: .minute, value: preferences.mainStopMinutes + preferences.secondaryStopMinutes + 30, to: startDate),
                duration: TimeInterval((preferences.pace == .relaxed ? 50 : 35) * 60),
                category: .restaurant,
                priority: .optional,
                notes: L10n.string("trip.fallback.breakSpot.notes")
            )
        ]
    }

    private func buildTransportation(for spots: [TripSpot]) -> [Transportation] {
        guard spots.count > 1 else { return [] }

        return zip(spots, spots.dropFirst()).map { from, to in
            Transportation(
                id: UUID().uuidString,
                from: from.name,
                to: to.name,
                mode: .walking,
                duration: 8 * 60,
                cost: nil
            )
        }
    }

    private func category(for name: String, subtitle: String) -> TripSpot.SpotCategory {
        let text = "\(name) \(subtitle)".lowercased()
        if text.contains("museum") || text.contains("gallery") || text.contains("博物馆") || text.contains("美术馆") {
            return .museum
        }
        if text.contains("restaurant") || text.contains("cafe") || text.contains("coffee") || text.contains("餐厅") || text.contains("咖啡") {
            return .restaurant
        }
        if text.contains("hotel") || text.contains("住宿") || text.contains("酒店") {
            return .hotel
        }
        if text.contains("station") || text.contains("airport") || text.contains("站") || text.contains("机场") {
            return .transport
        }
        if text.contains("mall") || text.contains("shop") || text.contains("购物") {
            return .shopping
        }
        return .scenic
    }

    private func spotCategory(from rawValue: String) -> TripSpot.SpotCategory {
        switch rawValue.lowercased() {
        case TripSpot.SpotCategory.museum.rawValue, "museum", "gallery":
            return .museum
        case TripSpot.SpotCategory.restaurant.rawValue, "restaurant", "cafe", "food":
            return .restaurant
        case TripSpot.SpotCategory.hotel.rawValue, "hotel", "accommodation":
            return .hotel
        case TripSpot.SpotCategory.transport.rawValue, "transport", "transit", "station":
            return .transport
        case TripSpot.SpotCategory.shopping.rawValue, "shopping", "shop":
            return .shopping
        default:
            return .scenic
        }
    }

    private func priority(from rawValue: String, index: Int) -> TripSpot.Priority {
        switch rawValue.lowercased() {
        case TripSpot.Priority.mustSee.rawValue, "must-see", "must see", "must":
            return .mustSee
        case TripSpot.Priority.optional.rawValue, "optional":
            return .optional
        case TripSpot.Priority.recommended.rawValue, "recommended":
            return .recommended
        default:
            return index == 0 ? .mustSee : .recommended
        }
    }

    private func note(for name: String, subtitle: String, index: Int) -> String {
        switch category(for: name, subtitle: subtitle) {
        case .museum:
            return L10n.string("trip.note.museum")
        case .restaurant:
            return L10n.string("trip.note.restaurant")
        case .shopping:
            return L10n.string("trip.note.shopping")
        case .transport:
            return L10n.string("trip.note.transport")
        case .hotel:
            return L10n.string("trip.note.hotel")
        case .scenic:
            return index < 2 ? L10n.string("trip.note.scenic.primary") : L10n.string("trip.note.scenic.secondary")
        }
    }

    private func stableID(for name: String, coordinate: CLLocationCoordinate2D) -> String {
        let safeName = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\u{4e00}-\\u{9fa5}]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let lat = Int((coordinate.latitude * 10_000).rounded())
        let lon = Int((coordinate.longitude * 10_000).rounded())
        return "\(safeName)-\(lat)-\(lon)"
    }

    private func distance(from first: CLLocationCoordinate2D, to second: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: first.latitude, longitude: first.longitude)
            .distance(from: CLLocation(latitude: second.latitude, longitude: second.longitude))
    }
}

@MainActor
final class JourneyMemoryStore: ObservableObject {
    static let shared = JourneyMemoryStore()

    @Published private(set) var entries: [Entry] = []

    struct Entry: Identifiable, Codable {
        let id: String
        let kind: Kind
        let title: String
        let subtitle: String
        let body: String
        let question: String?
        let answer: String?
        let tripName: String?
        let placeName: String?
        let timestamp: Date

        enum Kind: String, Codable {
            case recognitionQuestion
            case spotMemory
            case visitedSpot

            var label: String {
                switch self {
                case .recognitionQuestion: return L10n.string("trip.memory.kind.recognitionQuestion")
                case .spotMemory: return L10n.string("trip.memory.kind.spotMemory")
                case .visitedSpot: return L10n.string("trip.memory.kind.visitedSpot")
                }
            }

            var shortLabel: String {
                switch self {
                case .recognitionQuestion: return L10n.string("trip.memory.kind.short.recognitionQuestion")
                case .spotMemory: return L10n.string("trip.memory.kind.short.spotMemory")
                case .visitedSpot: return L10n.string("trip.memory.kind.short.visitedSpot")
                }
            }
        }
    }

    private let storageKey = "com.aiguide.journey.memories"
    private let defaults = UserDefaults.standard
    private let maxEntries = 120

    private init() {
        load()
    }

    var todayEntries: [Entry] {
        entries.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var todayPlaceCount: Int {
        Set(todayEntries.compactMap { entry in
            let place = entry.placeName ?? entry.title
            return normalized(place).isEmpty ? nil : normalized(place)
        }).count
    }

    var todayDigestText: String {
        let todayEntries = todayEntries
        guard !todayEntries.isEmpty else {
            return L10n.string("trip.daily.digest.empty")
        }

        let formatter = DateFormatter()
        formatter.locale = AIGuideLocalization.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        var text = L10n.format("trip.daily.digest.title.format", formatter.string(from: Date())) + "\n"
        text += L10n.format("trip.daily.digest.summary.format", todayEntries.count, todayPlaceCount) + "\n\n"

        for entry in todayEntries.prefix(8) {
            text += L10n.format("trip.daily.digest.kindTitle.format", entry.kind.label, entry.title) + "\n"
            if let question = entry.question {
                text += L10n.format("trip.daily.questionPrefix.format", question) + "\n"
            }
            text += "\(entry.body)\n\n"
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func addRecognitionQuestion(
        objectName: String,
        category: String,
        question: String,
        answer: String,
        sourceName: String
    ) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty, !trimmedAnswer.isEmpty else { return }

        add(
            Entry(
                id: UUID().uuidString,
                kind: .recognitionQuestion,
                title: objectName,
                subtitle: "\(category) · \(sourceName)",
                body: concise(trimmedAnswer, limit: 120),
                question: trimmedQuestion,
                answer: trimmedAnswer,
                tripName: nil,
                placeName: objectName,
                timestamp: Date()
            )
        )
    }

    func addSpotMemory(tripName: String, spotName: String, note: String) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return }

        add(
            Entry(
                id: UUID().uuidString,
                kind: .spotMemory,
                title: spotName,
                subtitle: tripName,
                body: trimmedNote,
                question: nil,
                answer: nil,
                tripName: tripName,
                placeName: spotName,
                timestamp: Date()
            )
        )
    }

    func addVisitedSpot(tripName: String, spotName: String, summary: String) {
        add(
            Entry(
                id: UUID().uuidString,
                kind: .visitedSpot,
                title: spotName,
                subtitle: tripName,
                body: summary,
                question: nil,
                answer: nil,
                tripName: tripName,
                placeName: spotName,
                timestamp: Date()
            )
        )
    }

    func entries(for trip: TripPlannerService.Trip) -> [Entry] {
        let spotTokens = Set(trip.days.flatMap(\.spots).map { normalized($0.name) })
        let tripToken = normalized(trip.name)

        return entries.filter { entry in
            if Calendar.current.isDateInToday(entry.timestamp) {
                return true
            }

            if let tripName = entry.tripName,
               normalized(tripName) == tripToken {
                return true
            }

            let placeToken = normalized(entry.placeName ?? entry.title)
            return !placeToken.isEmpty && spotTokens.contains(placeToken)
        }
    }

    private func add(_ entry: Entry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decodedEntries = try? JSONDecoder().decode([Entry].self, from: data) else {
            entries = []
            return
        }
        entries = decodedEntries.sorted { $0.timestamp > $1.timestamp }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func concise(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return "\(text[..<index])..."
    }

    private func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
    }
}
