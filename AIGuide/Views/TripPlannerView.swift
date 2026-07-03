// Trip Planner View - Redesigned with Timeline

import SwiftUI
import UIKit

struct TripPlannerView: View {
    @StateObject private var service = TripPlannerService()
    @StateObject private var ttsService = TTSService()
    @StateObject private var journeyMemoryStore = JourneyMemoryStore.shared
    @StateObject private var settingsService = SettingsService.shared
    @State private var showNewTrip = false
    @State private var showTemplates = false
    @State private var showDestinationSearch = ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_TRIP_SEARCH")
    @State private var destinationQuery = ""
    @State private var generatingDestinationID: String?
    @State private var tripPlanPreferences = TripPlannerService.TripPlanPreferences()
    @State private var tripName = ""
    @State private var tripDescription = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var showJourneyReview = false
    @State private var showDailyReport = false
    @State private var spotMemoryDraft: SpotMemoryDraft?

    // MARK: - Colors
    let primaryColor = Color(red: 0.85, green: 0.35, blue: 0.15)
    let secondaryColor = Color(red: 0.95, green: 0.75, blue: 0.2)
    private let forestColor = Color(red: 0.12, green: 0.40, blue: 0.24)
    private let pageBackground = Color(.systemGroupedBackground)
    private let cardBackground = Color(.systemBackground)
    private let softCardBackground = Color(.secondarySystemGroupedBackground)

    var body: some View {
        NavigationStack {
            ZStack {
                pageBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    if service.isPlanning {
                        activeTripView
                    } else {
                        tripListView
                    }
                }
            }
            .navigationTitle(L10n.string("trip.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDestinationSearch) {
                destinationSearchSheet
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showNewTrip) {
                newTripSheet
            }
            .sheet(isPresented: $showTemplates) {
                templateListView
            }
            .sheet(isPresented: $showJourneyReview) {
                Group {
                    if let trip = service.currentTrip {
                        JourneyReviewSheet(
                            trip: trip,
                            primaryColor: primaryColor,
                            forestColor: forestColor
                        )
                    } else {
                        ContentUnavailableView(
                            L10n.string("trip.daily.noReview"),
                            systemImage: "sparkles",
                            description: Text(L10n.string("trip.daily.noReview.desc"))
                        )
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showDailyReport) {
                DailyMemoryReportSheet(
                    memoryStore: journeyMemoryStore,
                    primaryColor: primaryColor,
                    forestColor: forestColor
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $spotMemoryDraft) { draft in
                SpotMemorySheet(
                    draft: draft,
                    primaryColor: primaryColor,
                    forestColor: forestColor
                ) { note in
                    service.addSpotMemory(
                        dayIndex: draft.dayIndex,
                        spotIndex: draft.spotIndex,
                        content: note
                    )
                    spotMemoryDraft = nil
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                service.refreshLocalizedTemplates()
                openQASampleTripIfNeeded()
            }
            .onChange(of: settingsService.language) { _, _ in
                service.refreshLocalizedTemplates()
                openQASampleTripIfNeeded()
            }
        }
    }

    // MARK: - Trip List View
    private var tripListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tripHomeHero
                routeAssistantCard

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("trip.recommendedRoutes"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    LazyVStack(spacing: 10) {
                        ForEach(service.tripTemplates.prefix(3)) { template in
                            TemplateCard(template: template, primaryColor: primaryColor) {
                                _ = service.createTripFromTemplate(template, startDate: Date())
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.string("trip.myTrips"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if service.savedTrips.isEmpty {
                        emptyTripCard
                    } else {
                        ForEach(service.savedTrips) { trip in
                            TripCard(trip: trip, primaryColor: primaryColor) {
                                openTrip(trip)
                            }
                        }
                    }
                }

                dailyMemoryCard
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 128)
        }
    }

    private var tripHomeHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.string("trip.plan"))
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(.primary)
                Text(L10n.string("trip.home.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button(action: { showDestinationSearch = true }) {
                    Label(L10n.string("trip.search.place"), systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 10) {
                    Button(action: { showNewTrip = true }) {
                        Label(L10n.string("trip.manualCreate"), systemImage: "plus.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(softCardBackground)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button(action: { showTemplates = true }) {
                        Label(L10n.string("trip.useTemplate"), systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(softCardBackground)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }

    private var routeAssistantCard: some View {
        Button {
            showDestinationSearch = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(forestColor)
                        .frame(width: 44, height: 44)
                        .background(forestColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(L10n.string("trip.routeAssistant.title"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: 8)

                    Text(L10n.string("trip.routeAssistant.badge"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(forestColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(forestColor.opacity(0.10), in: Capsule())
                }

                Text(L10n.string("trip.routeAssistant.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    RouteAssistantStepPill(
                        icon: "mappin.and.ellipse",
                        title: L10n.string("trip.routeAssistant.stepPlan"),
                        color: primaryColor
                    )
                    RouteAssistantStepPill(
                        icon: "play.circle.fill",
                        title: L10n.string("trip.routeAssistant.stepNarrate"),
                        color: forestColor
                    )
                    RouteAssistantStepPill(
                        icon: "sparkles.rectangle.stack.fill",
                        title: L10n.string("trip.routeAssistant.stepRemember"),
                        color: primaryColor
                    )
                }
            }
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("trip.routeAssistant.title"))
    }

    private var emptyTripCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "map")
                .font(.title2.weight(.semibold))
                .foregroundStyle(forestColor)
                .frame(width: 54, height: 54)
                .background(forestColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("trip.empty.title"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(L10n.string("trip.empty.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var dailyMemoryCard: some View {
        Button {
            showDailyReport = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(forestColor)
                        .frame(width: 46, height: 46)
                        .background(forestColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("trip.daily.cardTitle"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(dailyMemorySubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    JourneyMetricPill(
                        value: "\(journeyMemoryStore.todayEntries.count)",
                        label: L10n.string("trip.daily.records"),
                        color: primaryColor
                    )
                    JourneyMetricPill(
                        value: "\(journeyMemoryStore.todayPlaceCount)",
                        label: L10n.string("trip.daily.places"),
                        color: forestColor
                    )
                    JourneyMetricPill(
                        value: latestMemoryKind,
                        label: L10n.string("trip.daily.latest"),
                        color: .secondary
                    )
                }
            }
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("trip.daily.viewToday"))
    }

    private var dailyMemorySubtitle: String {
        guard let latest = journeyMemoryStore.todayEntries.first else {
            return L10n.string("trip.daily.autoSummary")
        }
        return L10n.format("trip.daily.latest.format", latest.title, latest.body)
    }

    private var latestMemoryKind: String {
        journeyMemoryStore.todayEntries.first?.kind.shortLabel ?? L10n.string("trip.daily.pending")
    }

    // MARK: - Active Trip View
    private var activeTripView: some View {
        Group {
            if let trip = service.currentTrip {
                VStack(spacing: 0) {
                    tripHeader(trip)

                    GeometryReader { proxy in
                        ScrollView(.vertical) {
                            VStack(spacing: 16) {
                                guideScriptCard(for: trip)
                                narrationPlayerCard(for: trip)
                                journeyMemoryCard(for: trip)
                                timelineContent(for: trip)
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                            .padding(.bottom, 128)
                            .frame(width: proxy.size.width, alignment: .top)
                        }
                        .background(pageBackground)
                        .scrollBounceBehavior(.basedOnSize)
                        .clipped()
                    }
                }
            } else {
                tripListView
            }
        }
    }

    private func guideScriptCard(for trip: TripPlannerService.Trip) -> some View {
        let spots = allSpots(in: trip)
        let visitedCount = spots.filter(\.isVisited).count
        let nextSpot = activeSpot(in: trip)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.bubble.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(primaryColor)
                    .frame(width: 44, height: 44)
                    .background(primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("trip.script.title")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("trip.script.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text("\(visitedCount)/\(spots.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(forestColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(forestColor.opacity(0.10), in: Capsule())
            }

            Text(trip.displayDescription)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .lineLimit(3)

            HStack(spacing: 10) {
                GuideScriptChip(
                    title: L10n.string("trip.script.nextStop"),
                    value: nextSpot?.name ?? L10n.string("trip.detail.routeWrap"),
                    icon: "location.fill",
                    color: forestColor
                )
                GuideScriptChip(
                    title: L10n.string("trip.script.listenPoint"),
                    value: nextSpot.map(listeningCue(for:)) ?? L10n.string("trip.script.summaryReview"),
                    icon: "ear",
                    color: primaryColor
                )
            }

            HStack(spacing: 10) {
                Button {
                    toggleNarration(for: trip)
                } label: {
                    Label(ttsService.isSpeaking ? L10n.string("guide.pauseNarration") : L10n.string("trip.script.startHere"), systemImage: ttsService.isSpeaking ? "pause.fill" : "play.fill")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(.white)
                        .background(primaryColor, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    if let nextSpot {
                        playSpotNarration(nextSpot, in: trip)
                    }
                } label: {
                    Label("trip.script.currentOnly", systemImage: "waveform")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(forestColor)
                        .background(forestColor.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(nextSpot == nil)
            }
        }
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }

    private func journeyMemoryCard(for trip: TripPlannerService.Trip) -> some View {
        let spots = allSpots(in: trip)
        let visitedSpots = spots.filter(\.isVisited)
        let relatedMemories = journeyMemoryStore.entries(for: trip)
        let progress = spots.isEmpty ? 0 : Double(visitedSpots.count) / Double(spots.count)
        let latestNote = relatedMemories.first?.body
            ?? trip.notes.last?.content
            ?? L10n.string("trip.memory.fallback")

        return Button {
            showJourneyReview = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(forestColor)
                        .frame(width: 44, height: 44)
                        .background(forestColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("trip.memory.title")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text("trip.memory.subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                ProgressView(value: progress)
                    .tint(forestColor)

                HStack(spacing: 10) {
                    JourneyMetricPill(
                        value: "\(visitedSpots.count)/\(spots.count)",
                        label: L10n.string("trip.memory.seen"),
                        color: forestColor
                    )
                    JourneyMetricPill(
                        value: "\(trip.notes.count + relatedMemories.count)",
                        label: L10n.string("trip.daily.records"),
                        color: primaryColor
                    )
                    JourneyMetricPill(
                        value: totalDurationText(for: trip),
                        label: L10n.string("trip.detail.estimate"),
                        color: .secondary
                    )
                }

                Text(latestNote)
                    .font(.caption)
                    .lineSpacing(3)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("trip.memory.view"))
    }

    private func timelineContent(for trip: TripPlannerService.Trip) -> some View {
        let spots = allSpots(in: trip)

        return VStack(spacing: 0) {
            TimelinePoint(
                title: L10n.format("trip.timeline.start.format", spots.first?.name ?? L10n.string("trip.timeline.recommendedEntrance")),
                subtitle: spots.first?.address ?? L10n.string("trip.timeline.confirmOpening"),
                distance: nil,
                duration: nil,
                status: .completed,
                primaryColor: primaryColor
            )

            ForEach(Array(trip.days.enumerated()), id: \.element.id) { dayIndex, day in
                TimelineDayHeader(
                    dayNumber: dayIndex + 1,
                    title: day.displayTitle,
                    primaryColor: primaryColor
                )

                ForEach(day.spots) { spot in
                    TimelineSpotCard(
                        spot: spot,
                        primaryColor: primaryColor,
                        cue: listeningCue(for: spot),
                        prompt: suggestedQuestion(for: spot),
                        onNarrate: {
                            playSpotNarration(spot, in: trip)
                        },
                        onRemember: {
                            if let spotIndex = day.spots.firstIndex(where: { $0.id == spot.id }) {
                                spotMemoryDraft = SpotMemoryDraft(
                                    dayIndex: dayIndex,
                                    spotIndex: spotIndex,
                                    spotName: spot.displayName,
                                    prompt: suggestedQuestion(for: spot)
                                )
                            }
                        },
                        onVisit: {
                            if let spotIndex = day.spots.firstIndex(where: { $0.id == spot.id }) {
                                service.markSpotVisited(dayIndex: dayIndex, spotIndex: spotIndex)
                            }
                        }
                    )
                }
            }

            TimelinePoint(
                title: L10n.format("trip.detail.endPoint.format", spots.last?.displayName ?? L10n.string("trip.detail.routeWrap")),
                subtitle: trip.displayDescription,
                distance: spots.count > 1 ? L10n.format("trip.detail.stops.format", spots.count) : nil,
                duration: totalDurationText(for: trip),
                status: .upcoming,
                primaryColor: primaryColor
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trip Header
    private func tripHeader(_ trip: TripPlannerService.Trip) -> some View {
        let spots = trip.days.flatMap { $0.spots }
        let visitedCount = spots.filter(\.isVisited).count

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    showTripHome()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryColor)
                        .frame(width: 34, height: 34)
                        .background(primaryColor.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("common.home"))

                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.displayName)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(trip.formattedDateRange)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(forestColor.opacity(0.10), in: Circle())
                    .accessibilityLabel(L10n.string("trip.detail.offlineReady"))

                Button {
                    searchAnotherDestination()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryColor)
                        .frame(width: 34, height: 34)
                        .background(primaryColor.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("trip.detail.changePlace"))
            }

            HStack(spacing: 7) {
                TripHeaderMetric(value: "\(trip.duration + 1)", label: L10n.string("trip.detail.days"), color: primaryColor)
                TripHeaderMetric(value: "\(spots.count)", label: L10n.string("trip.detail.spots"), color: forestColor)
                TripHeaderMetric(value: totalDurationText(for: trip), label: L10n.string("trip.detail.estimate"), color: primaryColor)
            }

            HStack(spacing: 8) {
                ProgressView(value: spots.isEmpty ? 0 : Double(visitedCount) / Double(spots.count))
                    .tint(primaryColor)

                Text(L10n.format("trip.detail.completed.format", visitedCount, spots.count))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(pageBackground)
    }

    private struct TripHeaderMetric: View {
        let value: String
        let label: String
        let color: Color

        var body: some View {
            HStack(spacing: 3) {
                Text(value)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(color.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Narration Player
    private func narrationPlayerCard(for trip: TripPlannerService.Trip) -> some View {
        let spot = activeSpot(in: trip)

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(primaryColor.opacity(0.10))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryColor)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.format("trip.player.now.format", spot?.displayName ?? trip.displayName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(spot?.displayNotes ?? L10n.string("trip.player.sequenceHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: max(0, ttsService.progress))
                    .tint(primaryColor)
            }
            .layoutPriority(1)

            HStack(spacing: 8) {
                Button {
                    replayNarration(for: trip)
                } label: {
                    Image(systemName: "gobackward")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryColor)
                        .frame(width: 40, height: 40)
                        .background(primaryColor.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("trip.player.replay"))

                Button {
                    toggleNarration(for: trip)
                } label: {
                    Image(systemName: ttsService.isSpeaking ? "pause.fill" : "play.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(primaryColor, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ttsService.isSpeaking ? L10n.string("trip.player.pause") : L10n.string("trip.player.play"))
            }
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    // MARK: - Destination Search
    private var destinationSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                destinationSearchField
                tripPlanSetupCard

                if service.isSearching {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text(L10n.string(generatingDestinationID == nil ? "trip.search.loading.map" : "trip.search.loading.plan"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = service.searchError {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            error,
                            systemImage: "mappin.slash",
                            description: Text(L10n.string("trip.search.fallback.description"))
                        )

                        Button {
                            generateTripFromKeyword()
                        } label: {
                            Label(L10n.string("trip.search.generateDirect"), systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canGenerateFromKeyword ? primaryColor : Color.gray.opacity(0.35))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(!canGenerateFromKeyword)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if service.searchResults.isEmpty {
                    ScrollView(showsIndicators: false) {
                        destinationRecommendationContent
                            .padding(.bottom, 18)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(service.searchResults) { result in
                                DestinationResultRow(
                                    result: result,
                                    isGenerating: generatingDestinationID == result.id,
                                    primaryColor: primaryColor
                                ) {
                                    generateTrip(from: result)
                                }
                            }
                        }
                        .padding(.bottom, 18)
                    }
                }
            }
            .padding()
            .navigationTitle(L10n.string("trip.search.place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.close")) { showDestinationSearch = false }
                }
            }
        }
    }

    private var destinationSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.72))

            TextField(L10n.string("trip.search.placeholder"), text: $destinationQuery)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    runDestinationSearch()
                }

            if !destinationQuery.isEmpty {
                Button {
                    destinationQuery = ""
                    service.searchResults = []
                    service.searchError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                runDestinationSearch()
            } label: {
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(canSearchDestination ? primaryColor : Color.gray.opacity(0.4), in: Circle())
            }
            .disabled(!canSearchDestination)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
    }

    private var tripPlanSetupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L10n.string("trip.preference.title"), systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: 8)

                Text(L10n.format("trip.preference.maxStops.format", tripPlanPreferences.maxStops))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(forestColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(forestColor.opacity(0.10), in: Capsule())
            }

            Text(tripPreferenceSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            tripPreferenceControls

            if canGenerateFromKeyword {
                Divider()
                    .overlay(Color.black.opacity(0.04))

                Button {
                    generateTripFromKeyword()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 30, height: 30)
                            .background(primaryColor.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.format("trip.search.generateKeyword.format", trimmedDestinationQuery))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(L10n.string("trip.search.directHint"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primaryColor)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(service.isSearching)
            }
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    private var tripPreferenceControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.string("trip.preference.durationPace"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([2, 4, 6], id: \.self) { hours in
                        TripPreferenceChip(
                            title: L10n.format("trip.preference.duration.short.format", hours),
                            icon: "clock",
                            isSelected: tripPlanPreferences.durationHours == hours,
                            primaryColor: primaryColor
                        ) {
                            tripPlanPreferences.durationHours = hours
                        }
                    }

                    ForEach(TripPlannerService.TripPlanPreferences.Pace.allCases, id: \.self) { pace in
                        TripPreferenceChip(
                            title: pace.displayTitle,
                            icon: pace.iconName,
                            isSelected: tripPlanPreferences.pace == pace,
                            primaryColor: primaryColor
                        ) {
                            tripPlanPreferences.pace = pace
                        }
                    }
                }
                .padding(.horizontal, 1)
            }

            Text(L10n.string("trip.preference.focusAudience"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TripPlannerService.TripPlanPreferences.Interest.allCases, id: \.self) { interest in
                        TripPreferenceChip(
                            title: interest.displayTitle,
                            icon: interest.iconName,
                            isSelected: tripPlanPreferences.interest == interest,
                            primaryColor: primaryColor
                        ) {
                            tripPlanPreferences.interest = interest
                        }
                    }

                    ForEach(TripPlannerService.TripPlanPreferences.Audience.allCases, id: \.self) { audience in
                        TripPreferenceChip(
                            title: audience.displayTitle,
                            icon: audience.iconName,
                            isSelected: tripPlanPreferences.audience == audience,
                            primaryColor: primaryColor
                        ) {
                            tripPlanPreferences.audience = audience
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private var tripPreferenceSummaryText: String {
        L10n.format(
            "trip.preference.summary.format",
            L10n.format("trip.preference.duration.long.format", tripPlanPreferences.durationHours),
            tripPlanPreferences.pace.displayTitle,
            tripPlanPreferences.interest.displayTitle,
            tripPlanPreferences.audience.displayTitle
        )
    }

    private var trimmedDestinationQuery: String {
        destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var destinationRecommendationContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tripSearchEntryPills) { pill in
                        TripSearchPill(pill: pill, primaryColor: primaryColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: L10n.string("trip.search.featured.title"),
                    subtitle: L10n.string("trip.search.featured.subtitle")
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(featuredTripRecommendations) { item in
                            TripVisualRecommendationCard(
                                item: item,
                                isGenerating: generatingDestinationID == item.id,
                                primaryColor: primaryColor
                            ) {
                                generateTrip(from: item)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: L10n.string("trip.search.routes.title"),
                    subtitle: L10n.string("trip.search.routes.subtitle")
                )

                LazyVStack(spacing: 10) {
                    ForEach(routeMapRecommendations) { item in
                        TripRouteMapCard(
                            item: item,
                            isGenerating: generatingDestinationID == item.id,
                            primaryColor: primaryColor,
                            forestColor: forestColor
                        ) {
                            generateTrip(from: item)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: L10n.string("trip.search.more.title"),
                    subtitle: L10n.string("trip.search.more.subtitle")
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                    ForEach(placeholderGuidePills) { pill in
                        TripPlaceholderGuidePill(pill: pill)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - New Trip Sheet
    private var newTripSheet: some View {
        NavigationStack {
            Form {
                Section("trip.new.sectionInfo") {
                    TextField("trip.new.name", text: $tripName)
                    TextField("trip.new.description", text: $tripDescription)
                    DatePicker("trip.new.startDate", selection: $startDate, displayedComponents: .date)
                    DatePicker("trip.new.endDate", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    Button("trip.new.create") {
                        _ = service.createTrip(
                            name: tripName.isEmpty ? L10n.string("trip.new.defaultName") : tripName,
                            description: tripDescription,
                            startDate: startDate,
                            endDate: endDate
                        )
                        showNewTrip = false
                    }
                }
            }
            .navigationTitle("trip.new.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { showNewTrip = false }
                }
            }
        }
    }

    // MARK: - Template List
    private var templateListView: some View {
        NavigationStack {
            List {
                ForEach(service.tripTemplates) { template in
                    TemplateCard(template: template, primaryColor: primaryColor) {
                        _ = service.createTripFromTemplate(template, startDate: Date())
                        showTemplates = false
                    }
                }
            }
            .navigationTitle("trip.templates.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { showTemplates = false }
                }
            }
        }
    }

    private var canSearchDestination: Bool {
        !destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isSearching
    }

    private var tripSearchEntryPills: [TripSearchEntryPillModel] {
        [
            TripSearchEntryPillModel(id: "cities", titleKey: "trip.search.pill.cities", icon: "building.2.fill", isPrimary: true),
            TripSearchEntryPillModel(id: "landmarks", titleKey: "trip.search.pill.landmarks", icon: "camera.aperture", isPrimary: true),
            TripSearchEntryPillModel(id: "routes", titleKey: "trip.search.pill.routes", icon: "map.fill", isPrimary: true),
            TripSearchEntryPillModel(id: "food", titleKey: "trip.search.pill.food", icon: "fork.knife", isPrimary: false),
            TripSearchEntryPillModel(id: "hotels", titleKey: "trip.search.pill.hotels", icon: "bed.double.fill", isPrimary: false)
        ]
    }

    private var featuredTripRecommendations: [TripSearchRecommendation] {
        [
            TripSearchRecommendation(
                id: "beijing-forbidden-city",
                imageName: "TripBeijingForbiddenCity",
                titleKey: "trip.search.featured.beijing.title",
                subtitleKey: "trip.search.featured.beijing.subtitle",
                badgeKey: "trip.search.badge.cityGuide",
                query: "北京故宫"
            ),
            TripSearchRecommendation(
                id: "paris-louvre",
                imageName: "TripParisLouvre",
                titleKey: "trip.search.featured.paris.title",
                subtitleKey: "trip.search.featured.paris.subtitle",
                badgeKey: "trip.search.badge.artRoute",
                query: "Louvre Museum Paris"
            ),
            TripSearchRecommendation(
                id: "new-york-met",
                imageName: "TripNewYorkMet",
                titleKey: "trip.search.featured.newYork.title",
                subtitleKey: "trip.search.featured.newYork.subtitle",
                badgeKey: "trip.search.badge.museumRoute",
                query: "The Metropolitan Museum of Art New York"
            ),
            TripSearchRecommendation(
                id: "san-francisco-weekend",
                imageName: "TripSanFranciscoWeekend",
                titleKey: "trip.search.featured.sanFrancisco.title",
                subtitleKey: "trip.search.featured.sanFrancisco.subtitle",
                badgeKey: "trip.search.badge.weekend",
                query: "Contemporary Jewish Museum San Francisco"
            )
        ]
    }

    private var routeMapRecommendations: [TripSearchRecommendation] {
        [
            TripSearchRecommendation(
                id: "beijing-route-map",
                imageName: "TripBeijingForbiddenCity",
                titleKey: "trip.search.route.beijing.title",
                subtitleKey: "trip.search.route.beijing.subtitle",
                badgeKey: "trip.search.badge.routeMap",
                query: "北京故宫"
            ),
            TripSearchRecommendation(
                id: "paris-route-map",
                imageName: "TripParisLouvre",
                titleKey: "trip.search.route.paris.title",
                subtitleKey: "trip.search.route.paris.subtitle",
                badgeKey: "trip.search.badge.routeMap",
                query: "Louvre Museum Paris"
            ),
            TripSearchRecommendation(
                id: "sf-route-map",
                imageName: "TripSanFranciscoWeekend",
                titleKey: "trip.search.route.sanFrancisco.title",
                subtitleKey: "trip.search.route.sanFrancisco.subtitle",
                badgeKey: "trip.search.badge.routeMap",
                query: "Contemporary Jewish Museum San Francisco"
            )
        ]
    }

    private var placeholderGuidePills: [TripPlaceholderGuidePillModel] {
        [
            TripPlaceholderGuidePillModel(id: "food", titleKey: "trip.search.placeholder.food", icon: "fork.knife"),
            TripPlaceholderGuidePillModel(id: "hotels", titleKey: "trip.search.placeholder.hotels", icon: "bed.double.fill"),
            TripPlaceholderGuidePillModel(id: "family", titleKey: "trip.search.placeholder.family", icon: "figure.2.and.child.holdinghands"),
            TripPlaceholderGuidePillModel(id: "shopping", titleKey: "trip.search.placeholder.shopping", icon: "bag.fill")
        ]
    }

    private var canGenerateFromKeyword: Bool {
        !destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isSearching
    }

    private var shouldOpenQASampleTrip: Bool {
        ProcessInfo.processInfo.arguments.contains("AIGUIDE_OPEN_SAMPLE_TRIP")
    }

    private func openQASampleTripIfNeeded() {
        guard shouldOpenQASampleTrip, !service.isPlanning else { return }
        service.loadQASampleTrip()
    }

    private func runDestinationSearch() {
        guard canSearchDestination else { return }
        Task {
            await service.searchDestinations(query: destinationQuery)
        }
    }

    private func openTrip(_ trip: TripPlannerService.Trip) {
        ttsService.stop()
        service.currentTrip = trip
        service.isPlanning = true
    }

    private func showTripHome() {
        ttsService.stop()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            service.isPlanning = false
        }
    }

    private func searchAnotherDestination() {
        ttsService.stop()
        destinationQuery = ""
        generatingDestinationID = nil
        service.searchResults = []
        service.searchError = nil
        showDestinationSearch = true
    }

    private func generateTrip(from result: TripPlannerService.DestinationSearchResult) {
        ttsService.stop()
        generatingDestinationID = result.id
        Task {
            await service.generateRecommendedTrip(for: result, preferences: tripPlanPreferences)
            generatingDestinationID = nil
            showDestinationSearch = false
        }
    }

    private func generateTrip(from item: TripSearchRecommendation) {
        destinationQuery = item.query
        generateTripFromKeyword(id: item.id, keyword: item.query)
    }

    private func generateTripFromKeyword(id: String = "keyword", keyword: String? = nil) {
        let keyword = keyword ?? destinationQuery
        ttsService.stop()
        generatingDestinationID = id
        Task {
            await service.generateRecommendedTrip(forKeyword: keyword, preferences: tripPlanPreferences)
            generatingDestinationID = nil
            showDestinationSearch = false
        }
    }

    private func toggleNarration(for trip: TripPlannerService.Trip) {
        let text = narrationText(for: trip)
        if ttsService.isSpeaking {
            ttsService.pause()
        } else if ttsService.currentText == text && ttsService.progress > 0 && ttsService.progress < 1 {
            ttsService.resume()
        } else {
            ttsService.speak(text, rate: 0.44)
        }
    }

    private func replayNarration(for trip: TripPlannerService.Trip) {
        ttsService.speak(narrationText(for: trip), rate: 0.44)
    }

    private func playSpotNarration(_ spot: TripPlannerService.TripSpot, in trip: TripPlannerService.Trip) {
        ttsService.speak(narrationText(for: spot, in: trip), rate: 0.44)
    }

    private func narrationText(for trip: TripPlannerService.Trip) -> String {
        guard let spot = activeSpot(in: trip) else {
            return "\(trip.displayName). \(trip.displayDescription)"
        }

        return narrationText(for: spot, in: trip)
    }

    private func narrationText(for spot: TripPlannerService.TripSpot, in trip: TripPlannerService.Trip) -> String {
        let duration = spot.duration.map { L10n.format("trip.narration.duration.format", max(10, Int($0 / 60))) } ?? ""
        let notes = spot.displayNotes ?? trip.displayDescription
        return L10n.format(
            "trip.narration.spotIntro.format",
            spot.displayName,
            trip.displayName,
            duration,
            notes,
            listeningCue(for: spot),
            suggestedQuestion(for: spot)
        )
    }

    private func listeningCue(for spot: TripPlannerService.TripSpot) -> String {
        switch spot.category {
        case .museum:
            return L10n.string("trip.cue.museum")
        case .scenic:
            return L10n.string("trip.cue.scenic")
        case .restaurant:
            return L10n.string("trip.cue.restaurant")
        case .hotel:
            return L10n.string("trip.cue.hotel")
        case .transport:
            return L10n.string("trip.cue.transport")
        case .shopping:
            return L10n.string("trip.cue.shopping")
        }
    }

    private func suggestedQuestion(for spot: TripPlannerService.TripSpot) -> String {
        switch spot.category {
        case .museum:
            return L10n.format("trip.question.museum.format", spot.displayName)
        case .scenic:
            return L10n.format("trip.question.scenic.format", spot.displayName)
        case .restaurant:
            return L10n.string("trip.question.restaurant")
        case .hotel:
            return L10n.string("trip.question.hotel")
        case .transport:
            return L10n.string("trip.question.transport")
        case .shopping:
            return L10n.string("trip.question.shopping")
        }
    }

    private func allSpots(in trip: TripPlannerService.Trip) -> [TripPlannerService.TripSpot] {
        trip.days.flatMap(\.spots)
    }

    private func activeSpot(in trip: TripPlannerService.Trip) -> TripPlannerService.TripSpot? {
        allSpots(in: trip).first { !$0.isVisited } ?? allSpots(in: trip).first
    }

    private func totalDurationText(for trip: TripPlannerService.Trip) -> String {
        let minutes = Int(trip.days.flatMap(\.spots).compactMap(\.duration).reduce(0, +) / 60)
        guard minutes > 0 else { return L10n.string("common.halfDay") }
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return L10n.format("common.hours.short", minutes / 60)
            }
            return L10n.format("common.hoursMinutes.short", minutes / 60, minutes % 60)
        }
        return L10n.format("common.minutes.short", minutes)
    }
}

// MARK: - Timeline Components

struct GuideScriptChip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RouteAssistantStepPill: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct JourneyMetricPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SpotMemoryDraft: Identifiable {
    let id = UUID()
    let dayIndex: Int
    let spotIndex: Int
    let spotName: String
    let prompt: String
}

private struct SpotMemorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""

    let draft: SpotMemoryDraft
    let primaryColor: Color
    let forestColor: Color
    let onSave: (String) -> Void

    private var canSave: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var quickNotes: [String] {
        [
            L10n.string("trip.memory.quick.revisit"),
            L10n.string("trip.memory.quick.askLater"),
            L10n.string("trip.memory.quick.photoSpot"),
            L10n.string("trip.memory.quick.kids")
        ]
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.spotName)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.primary)
                    Text("trip.memory.notes.desc")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickNotes, id: \.self) { note in
                            Button {
                                appendQuickNote(note)
                            } label: {
                                Text(note)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(forestColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(forestColor.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                TextEditor(text: $noteText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 128)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if noteText.isEmpty {
                            Text("trip.memory.notes.placeholder")
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.68))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

                Label(L10n.format("trip.memory.canAsk.format", draft.prompt), systemImage: "text.bubble")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Button {
                    onSave(noteText)
                    dismiss()
                } label: {
                    Label("trip.memory.save", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(canSave ? primaryColor : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSave)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("trip.memory.notes.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }

    private func appendQuickNote(_ text: String) {
        if noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteText = "\(text):"
        } else {
            noteText += "\n\(text):"
        }
    }
}

private struct DailyMemoryReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var memoryStore: JourneyMemoryStore
    @State private var imageShare: ShareImage?

    let primaryColor: Color
    let forestColor: Color

    private var entries: [JourneyMemoryStore.Entry] {
        memoryStore.todayEntries
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = AIGuideLocalization.current.locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: Date())
    }

    private var topPlaces: [String] {
        let names = entries.compactMap { $0.placeName ?? $0.title }
        var seen: Set<String> = []
        return names.filter { name in
            let key = name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        .prefix(4)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    reportHeader

                    if entries.isEmpty {
                        emptyReport
                    } else {
                        reportStats
                        visualCardSection
                        highlightsSection
                        timelineSection
                        shareButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("trip.daily.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
        .sheet(item: $imageShare) { share in
            ActivityShareSheet(activityItems: [share.image])
        }
    }

    private var reportHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(forestColor)
                    .frame(width: 52, height: 52)
                    .background(forestColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.format("trip.daily.dateTitle.format", dateTitle))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.primary)
                    Text(entries.isEmpty ? L10n.string("trip.daily.header.empty") : L10n.string("trip.daily.header.filled"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var reportStats: some View {
        HStack(spacing: 10) {
            JourneyMetricPill(value: "\(entries.count)", label: L10n.string("trip.daily.records"), color: primaryColor)
            JourneyMetricPill(value: "\(memoryStore.todayPlaceCount)", label: L10n.string("trip.daily.places"), color: forestColor)
            JourneyMetricPill(value: "\(entries.filter { $0.kind == .recognitionQuestion }.count)", label: L10n.string("trip.daily.questions"), color: .secondary)
        }
    }

    private var visualCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("trip.daily.card", systemImage: "photo.on.rectangle.angled")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    shareVisualCard()
                } label: {
                    Label("trip.daily.shareImage", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(primaryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(primaryColor.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            DailyMemoryShareCard(
                entries: Array(entries.prefix(6)),
                dateTitle: dateTitle,
                placeCount: memoryStore.todayPlaceCount,
                primaryColor: primaryColor,
                forestColor: forestColor
            )
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            )
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var emptyReport: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("trip.daily.emptyTitle", systemImage: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text("trip.daily.emptyDesc")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            HStack(spacing: 10) {
                ReportHintPill(icon: "eye.fill", text: L10n.string("trip.daily.identifyAsk"), color: forestColor)
                ReportHintPill(icon: "note.text", text: L10n.string("trip.daily.fieldNotes"), color: primaryColor)
                ReportHintPill(icon: "checkmark.circle.fill", text: L10n.string("trip.daily.visitedRecords"), color: forestColor)
            }
        }
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("trip.daily.clues", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if topPlaces.isEmpty {
                Text("trip.daily.noPlaceClues")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(topPlaces.enumerated()), id: \.offset) { index, place in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(index == 0 ? primaryColor : forestColor.opacity(0.8), in: Circle())

                            Text(place)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("trip.daily.timeline", systemImage: "clock.arrow.circlepath")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(entries.prefix(10)) { entry in
                    DailyMemoryRow(entry: entry, primaryColor: primaryColor, forestColor: forestColor)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var shareButton: some View {
        ShareLink(item: memoryStore.todayDigestText) {
            Label("trip.daily.share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(primaryColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func shareVisualCard() {
        let renderer = ImageRenderer(
            content: DailyMemoryShareCard(
                entries: Array(entries.prefix(6)),
                dateTitle: dateTitle,
                placeCount: memoryStore.todayPlaceCount,
                primaryColor: primaryColor,
                forestColor: forestColor
            )
            .frame(width: 1080, height: 1440)
        )
        renderer.scale = 1

        guard let image = renderer.uiImage else { return }
        imageShare = ShareImage(image: image)
    }
}

private struct DailyMemoryShareCard: View {
    let entries: [JourneyMemoryStore.Entry]
    let dateTitle: String
    let placeCount: Int
    let primaryColor: Color
    let forestColor: Color

    private var questionCount: Int {
        entries.filter { $0.kind == .recognitionQuestion }.count
    }

    private var topTitle: String {
        entries.first?.title ?? L10n.string("trip.daily.todayVisit")
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    forestColor.opacity(0.10),
                    primaryColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI GUIDE")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(forestColor)
                        Text(L10n.format("trip.daily.dateTitle.format", dateTitle))
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer()

                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(primaryColor)
                        .frame(width: 92, height: 92)
                        .background(primaryColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(topTitle)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text("trip.daily.shareSubtitle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    ShareCardMetric(value: "\(entries.count)", label: L10n.string("trip.daily.records"), color: primaryColor)
                    ShareCardMetric(value: "\(placeCount)", label: L10n.string("trip.daily.places"), color: forestColor)
                    ShareCardMetric(value: "\(questionCount)", label: L10n.string("trip.daily.questions"), color: .secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(entries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(index == 0 ? primaryColor : forestColor, in: Circle())

                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(entry.question.map { L10n.format("trip.daily.questionPrefix.format", $0) } ?? entry.kind.label)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                Text(entry.body)
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(4)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(22)
                .background(Color(.systemBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                Spacer(minLength: 0)

                HStack {
                    Label("trip.daily.generatedBadge", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(forestColor)

                    Spacer()

                    Text("guide.brand")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(primaryColor)
                }
            }
            .padding(58)
        }
    }
}

private struct ShareCardMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct ShareImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct DailyMemoryRow: View {
    let entry: JourneyMemoryStore.Entry
    let primaryColor: Color
    let forestColor: Color

    private var color: Color {
        entry.kind == .recognitionQuestion ? primaryColor : forestColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entry.kind.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let question = entry.question {
                    Text(L10n.format("trip.daily.questionPrefix.format", question))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(entry.body)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
    }

    private var iconName: String {
        switch entry.kind {
        case .recognitionQuestion: return "eye.fill"
        case .spotMemory: return "note.text"
        case .visitedSpot: return "checkmark.circle.fill"
        }
    }
}

private struct ReportHintPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(color.opacity(0.10), in: Capsule())
    }
}

private struct JourneyReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var memoryStore = JourneyMemoryStore.shared

    let trip: TripPlannerService.Trip
    let primaryColor: Color
    let forestColor: Color

    private var spots: [TripPlannerService.TripSpot] {
        trip.days.flatMap(\.spots)
    }

    private var visitedSpots: [TripPlannerService.TripSpot] {
        spots.filter(\.isVisited)
    }

    private var visibleSpots: [TripPlannerService.TripSpot] {
        visitedSpots.isEmpty ? Array(spots.prefix(4)) : visitedSpots
    }

    private var memoryNotes: [TripPlannerService.TripNote] {
        trip.notes.filter { $0.tag == .memory }
    }

    private var tipNotes: [TripPlannerService.TripNote] {
        trip.notes.filter { $0.tag != .memory }
    }

    private var relatedMemories: [JourneyMemoryStore.Entry] {
        Array(memoryStore.entries(for: trip).prefix(8))
    }

    private var totalMemoryCount: Int {
        trip.notes.count + relatedMemories.count
    }

    private var completionText: String {
        guard !spots.isEmpty else { return L10n.string("trip.review.notStarted") }
        return "\(visitedSpots.count)/\(spots.count)"
    }

    private var totalMinutes: Int {
        Int(spots.compactMap(\.duration).reduce(0, +) / 60)
    }

    private var durationText: String {
        guard totalMinutes > 0 else { return L10n.string("trip.review.pendingDuration") }
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? L10n.format("common.hours.short", hours) : L10n.format("common.hoursMinutes.short", hours, minutes)
        }
        return L10n.format("common.minutes.short", totalMinutes)
    }

    private var reviewText: String {
        let visitedNames = visitedSpots.map(\.name).joined(separator: "、")
        let fallbackNames = spots.prefix(3).map(\.name).joined(separator: "、")
        let names = visitedNames.isEmpty ? fallbackNames : visitedNames
        var text = L10n.format("trip.review.textTitle.format", trip.displayName) + "\n"
        text += L10n.format("trip.review.textProgress.format", completionText, totalMemoryCount, durationText) + "\n"
        if !names.isEmpty {
            text += L10n.format("trip.review.textStops.format", names) + "\n"
        }
        if let question = relatedMemories.first(where: { $0.kind == .recognitionQuestion })?.question {
            text += L10n.format("trip.review.textQuestion.format", question) + "\n"
        }
        text += L10n.format("trip.review.textSummary.format", trip.displayDescription)
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    statsGrid
                    visitedSection
                    notesSection
                    memoryQuestionSection
                    summarySection
                    shareSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("trip.review.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(forestColor)
                    .frame(width: 50, height: 50)
                    .background(forestColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.displayName)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text("trip.review.header")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)
            }

            ProgressView(value: spots.isEmpty ? 0 : Double(visitedSpots.count) / Double(spots.count))
                .tint(forestColor)
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            JourneyMetricPill(value: completionText, label: L10n.string("trip.memory.seen"), color: forestColor)
            JourneyMetricPill(value: "\(totalMemoryCount)", label: L10n.string("trip.daily.records"), color: primaryColor)
            JourneyMetricPill(value: durationText, label: L10n.string("trip.review.duration"), color: .secondary)
        }
    }

    private var visitedSection: some View {
        reviewCard(title: visitedSpots.isEmpty ? L10n.string("trip.review.recommendedFirst") : L10n.string("trip.review.seenStops"), icon: "checkmark.seal.fill", color: forestColor) {
            if visibleSpots.isEmpty {
                Text("trip.review.noStops")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleSpots.prefix(5)) { spot in
                        HStack(spacing: 10) {
                            Image(systemName: spot.category.iconName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(forestColor)
                                .frame(width: 28, height: 28)
                                .background(forestColor.opacity(0.10), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(spot.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(spot.displayNotes ?? spot.category.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Image(systemName: spot.isVisited ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(spot.isVisited ? Color.green : Color.secondary.opacity(0.45))
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        reviewCard(title: L10n.string("trip.review.memoryExcerpt"), icon: "text.quote", color: primaryColor) {
            if memoryNotes.isEmpty && tipNotes.isEmpty {
                Text("trip.review.noNotes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array((memoryNotes + tipNotes).suffix(4))) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill((note.tag == .memory ? forestColor : primaryColor).opacity(0.85))
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)

                            Text(note.content)
                                .font(.subheadline)
                                .lineSpacing(3)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        reviewCard(title: L10n.string("trip.review.guideSummary"), icon: "book.closed.fill", color: forestColor) {
            Text(reviewText)
                .font(.subheadline)
                .lineSpacing(5)
                .foregroundStyle(.primary)
        }
    }

    private var memoryQuestionSection: some View {
        reviewCard(title: L10n.string("trip.review.qa"), icon: "bubble.left.and.text.bubble.right.fill", color: forestColor) {
            if relatedMemories.isEmpty {
                Text("trip.review.noQA")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(relatedMemories) { memory in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: iconName(for: memory.kind))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(memory.kind == .recognitionQuestion ? primaryColor : forestColor)
                                .frame(width: 28, height: 28)
                                .background((memory.kind == .recognitionQuestion ? primaryColor : forestColor).opacity(0.10), in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(memory.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(memory.kind.label)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                                }

                                if let question = memory.question {
                                    Text(L10n.format("trip.daily.questionPrefix.format", question))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Text(memory.body)
                                    .font(.subheadline)
                                    .lineSpacing(3)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }
        }
    }

    private var shareSection: some View {
        ShareLink(item: reviewText) {
            Label("trip.review.share", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(primaryColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func reviewCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func iconName(for kind: JourneyMemoryStore.Entry.Kind) -> String {
        switch kind {
        case .recognitionQuestion: return "eye.fill"
        case .spotMemory: return "note.text"
        case .visitedSpot: return "checkmark.circle.fill"
        }
    }
}

struct TimelinePoint: View {
    let title: String
    let subtitle: String
    let distance: String?
    let duration: String?
    let status: SpotStatus
    let primaryColor: Color

    enum SpotStatus {
        case completed, current, upcoming
    }

    var body: some View {
        HStack(spacing: 12) {
            // Timeline dot
            VStack {
                Circle()
                    .fill(status == .completed ? .green : status == .current ? primaryColor : .gray)
                    .frame(width: 12, height: 12)

                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 2, height: 30)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer()

            if let distance = distance, let duration = duration {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(distance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(duration)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.75))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimelineDayHeader: View {
    let dayNumber: Int
    let title: String
    let primaryColor: Color

    var body: some View {
        HStack {
            // Timeline
            VStack {
                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 2, height: 20)
            }

            // Day badge
            Text(L10n.format("trip.timeline.day.format", dayNumber))
                .font(.caption)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(primaryColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TimelineSpotCard: View {
    let spot: TripPlannerService.TripSpot
    let primaryColor: Color
    let cue: String
    let prompt: String
    let onNarrate: () -> Void
    let onRemember: () -> Void
    let onVisit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline
            VStack {
                Circle()
                    .fill(spot.isVisited ? .green : .gray)
                    .frame(width: 10, height: 10)

                Rectangle()
                    .fill(.gray.opacity(0.3))
                    .frame(width: 2, height: 60)
            }

            // Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(primaryColor.opacity(0.10))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: spot.category.iconName)
                                .foregroundStyle(primaryColor)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(spot.displayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .layoutPriority(1)

                            Text(spot.priority.localizedName)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(spot.priority.color.opacity(0.16))
                                .foregroundStyle(spot.priority.color)
                                .clipShape(Capsule())
                                .fixedSize()
                        }

                        Text("\(spot.category.localizedName) · \(durationText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(spot.displayNotes ?? L10n.string("trip.spot.defaultNotes"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Label(L10n.format("trip.spot.cue.format", cue), systemImage: "ear")
                    Label(L10n.format("trip.spot.prompt.format", prompt), systemImage: "text.bubble")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

                HStack(spacing: 10) {
                    Button(action: onNarrate) {
                        Label("trip.spot.listen", systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(primaryColor)
                            .background(primaryColor.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onRemember) {
                        Label("trip.spot.remember", systemImage: "note.text")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(primaryColor)
                            .background(primaryColor.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onVisit) {
                        Label(spot.isVisited ? L10n.string("trip.memory.seen") : L10n.string("trip.spot.markSeen"), systemImage: spot.isVisited ? "checkmark.circle.fill" : "circle")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .foregroundStyle(spot.isVisited ? .green : .secondary)
                            .background((spot.isVisited ? Color.green : Color.secondary).opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(spot.isVisited)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var durationText: String {
        guard let duration = spot.duration else { return L10n.string("trip.spot.recommendedStay") }
        return L10n.format("trip.spot.approxMinutes.format", max(10, Int(duration / 60)))
    }
}

private extension TripPlannerService.TripSpot.SpotCategory {
    var iconName: String {
        switch self {
        case .scenic: return "building.columns.fill"
        case .museum: return "building.2.fill"
        case .restaurant: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .transport: return "tram.fill"
        case .shopping: return "bag.fill"
        }
    }
}

private struct TripSearchEntryPillModel: Identifiable {
    let id: String
    let titleKey: String
    let icon: String
    let isPrimary: Bool
}

private struct TripSearchRecommendation: Identifiable {
    let id: String
    let imageName: String
    let titleKey: String
    let subtitleKey: String
    let badgeKey: String
    let query: String
}

private struct TripPlaceholderGuidePillModel: Identifiable {
    let id: String
    let titleKey: String
    let icon: String
}

private struct TripSearchPill: View {
    let pill: TripSearchEntryPillModel
    let primaryColor: Color

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: pill.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(pill.isPrimary ? primaryColor : .secondary)

            Text(L10n.string(pill.titleKey))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(pill.isPrimary ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if !pill.isPrimary {
                Text(L10n.string("trip.search.soon"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(pill.isPrimary ? Color(.secondarySystemGroupedBackground) : Color(.tertiarySystemGroupedBackground), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.black.opacity(pill.isPrimary ? 0.05 : 0.02), lineWidth: 1)
        )
    }
}

private struct TripPreferenceChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))

                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(isSelected ? .white : .primary.opacity(0.76))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? primaryColor : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? primaryColor.opacity(0.2) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension TripPlannerService.TripPlanPreferences.Interest {
    var displayTitle: String {
        switch self {
        case .essentials: return L10n.string("trip.priority.mustSee")
        case .history: return L10n.string("guide.style.history")
        case .architecture: return L10n.string("guide.style.architecture")
        case .photography: return L10n.string("tour.category.photography")
        }
    }

    var iconName: String {
        switch self {
        case .essentials: return "star.fill"
        case .history: return "scroll.fill"
        case .architecture: return "building.columns.fill"
        case .photography: return "camera.fill"
        }
    }
}

private extension TripPlannerService.TripPlanPreferences.Audience {
    var displayTitle: String {
        switch self {
        case .general: return L10n.string("trip.llm.audience.general")
        case .family: return L10n.string("trip.search.placeholder.family")
        case .kids: return L10n.string("guide.style.children")
        }
    }

    var iconName: String {
        switch self {
        case .general: return "person.2.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .kids: return "face.smiling.fill"
        }
    }
}

private extension TripPlannerService.TripPlanPreferences.Pace {
    var displayTitle: String {
        switch self {
        case .relaxed: return L10n.string("trip.preference.pace.relaxed")
        case .balanced: return L10n.string("trip.preference.pace.balanced")
        case .efficient: return L10n.string("trip.preference.pace.efficient")
        }
    }

    var iconName: String {
        switch self {
        case .relaxed: return "leaf.fill"
        case .balanced: return "slider.horizontal.3"
        case .efficient: return "bolt.fill"
        }
    }
}

private struct TripVisualRecommendationCard: View {
    let item: TripSearchRecommendation
    let isGenerating: Bool
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 218, height: 164)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.02),
                        .black.opacity(0.14),
                        .black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.string(item.badgeKey))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(primaryColor.opacity(0.92), in: Capsule())

                    Text(L10n.string(item.titleKey))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(L10n.string(item.subtitleKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .padding(13)

                if isGenerating {
                    ZStack {
                        Color.black.opacity(0.24)
                        ProgressView()
                            .tint(.white)
                    }
                }
            }
            .frame(width: 218, height: 164)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .accessibilityLabel(L10n.string(item.titleKey))
    }
}

private struct TripRouteMapCard: View {
    let item: TripSearchRecommendation
    let isGenerating: Bool
    let primaryColor: Color
    let forestColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.string(item.badgeKey))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)

                    Text(L10n.string(item.titleKey))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(L10n.string(item.subtitleKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(forestColor)
                }
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .accessibilityLabel(L10n.string(item.titleKey))
    }
}

private struct TripPlaceholderGuidePill: View {
    let pill: TripPlaceholderGuidePillModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pill.icon)
                .font(.caption.weight(.bold))
            Text(L10n.string(pill.titleKey))
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 4)
            Text(L10n.string("trip.search.soon"))
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Destination Result Row
struct DestinationResultRow: View {
    let result: TripPlannerService.DestinationSearchResult
    let isGenerating: Bool
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(primaryColor.opacity(0.12))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryColor)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(primaryColor)
                }
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
        .accessibilityLabel(L10n.format("trip.search.generateItinerary.format", result.name))
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: TripPlannerService.TripTemplate
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(primaryColor)
                    .frame(width: 52, height: 52)
                    .background(primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(template.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(durationText)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(primaryColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())

                        if let highlight = template.highlights.first {
                            Text(highlight)
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primaryColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
    }

    private var durationText: String {
        if template.duration == 1 {
            return L10n.string("trip.template.durationOneDay")
        }
        return L10n.format("trip.template.durationDays.format", template.duration)
    }
}

// MARK: - Trip Card
struct TripCard: View {
    let trip: TripPlannerService.Trip
    let primaryColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(primaryColor.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "map.fill")
                            .foregroundStyle(primaryColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(trip.formattedDateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(trip.status.localizedName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(trip.status.color.opacity(0.3))
                            .foregroundStyle(trip.status.color)
                            .clipShape(Capsule())

                        Text(L10n.format("trip.card.spotCount.format", trip.days.flatMap { $0.spots }.count))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

// MARK: - Legacy Generated Trip Localization
private extension TripPlannerService.Trip {
    var displayName: String { TripLegacyText.localized(name) }
    var displayDescription: String { TripLegacyText.localized(description) }
}

private extension TripPlannerService.TripDay {
    var displayTitle: String { TripLegacyText.localized(title) }
}

private extension TripPlannerService.TripSpot {
    var displayName: String { TripLegacyText.localized(name) }
    var displayNotes: String? { notes.map(TripLegacyText.localized) }
}

private enum TripLegacyText {
    private static let keyByLegacyText: [String: String] = [
        "大都会艺术博物馆深度导览": "legacy.trip.met.deepGuide.name",
        "用4小时探索世界顶级博物馆的精华展品": "legacy.trip.met.deepGuide.description",
        "大都会艺术博物馆": "legacy.place.met.name",
        "从埃及丹铎神殿到欧洲油画，建议按兴趣选择2-3个展厅深度游览": "legacy.place.met.note",
        "卢浮宫周边探索与美食之旅": "legacy.trip.louvre.nearbyFood.name",
        "以卢浮宫为核心，探索周边特色餐饮与品鉴体验。": "legacy.trip.louvre.nearbyFood.description",
        "卢浮宫": "legacy.place.louvre.name",
        "探索这座以法国宫殿为灵感的现代商业综合体，感受其独特的建筑风格与艺术氛围。": "legacy.place.louvreChina.note",
        "百年枝江卢浮宫品鉴馆": "legacy.place.zhijiangLouvre.name",
        "了解湖北名酒枝江大曲的历史与酿造工艺，品鉴其经典产品，感受酒文化魅力。": "legacy.place.zhijiangLouvre.note",
        "王广家·裸烹新土菜(卢浮宫店)": "legacy.place.wangguangjia.name",
        "品尝主打“裸烹”理念的本地新土菜，食材新鲜，做法地道，体验十堰风味。": "legacy.place.wangguangjia.note",
        "巴黎卢浮宫深度探索之旅": "legacy.trip.louvreParis.deepDive.name",
        "在4小时内聚焦卢浮宫镇馆三宝与经典展厅，领略艺术殿堂的精华。": "legacy.trip.louvreParis.deepDive.description",
        "卢浮宫博物馆": "legacy.place.louvreMuseum.name",
        "必看镇馆三宝：蒙娜丽莎、胜利女神、断臂维纳斯，建议按德农馆-叙利馆路线参观": "legacy.place.louvreMuseum.note",
        "卡鲁塞尔凯旋门": "legacy.place.arcCarrousel.name",
        "卢浮宫前的迷你凯旋门，拍照绝佳位置，可远眺杜乐丽花园": "legacy.place.arcCarrousel.note",
        "杜乐丽花园": "legacy.place.tuileries.name",
        "法式经典皇家园林，喷泉与雕塑点缀其间，适合散步放松": "legacy.place.tuileries.note"
    ]

    static func localized(_ text: String) -> String {
        guard let key = keyByLegacyText[text] else { return text }
        return L10n.string(key)
    }
}

#Preview {
    TripPlannerView()
}
