import SwiftUI
import CoreLocation

// MARK: - Ask Sheet
struct AskSheetView: View {
    @ObservedObject var guideVM: GuideViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var question = ""

    private var quickQuestions: [String] {
        let name = guideVM.currentPOI?.name ?? L10n.string("sheet.place.here")

        switch guideVM.currentPOI?.category {
        case .palace, .building:
            return [
                L10n.format("sheet.ask.quick.whyImportant.format", name),
                L10n.string("sheet.ask.quick.architecture"),
                L10n.string("sheet.ask.quick.routeRelation")
            ]
        case .museum, .exhibit:
            return [
                L10n.format("sheet.ask.quick.bestView.format", name),
                L10n.string("sheet.ask.quick.kids"),
                L10n.string("sheet.ask.quick.uncertainty")
            ]
        case .garden:
            return [
                L10n.format("sheet.ask.quick.visitOrder.format", name),
                L10n.string("sheet.ask.quick.designMeaning"),
                L10n.string("sheet.ask.quick.kids")
            ]
        case .temple:
            return [
                L10n.format("sheet.ask.quick.history.format", name),
                L10n.string("sheet.ask.quick.ritualMeaning"),
                L10n.string("sheet.ask.quick.kids")
            ]
        case .none:
            return [
                L10n.string("sheet.ask.quick.hereImportant"),
                L10n.string("sheet.ask.quick.nearbyWorth"),
                L10n.string("sheet.ask.quick.kids")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.ask.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("sheet.ask.title")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("sheet.ask.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Input
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)

                    TextField("sheet.ask.placeholder", text: $question)

                    Button("sheet.ask.submit") {
                        Task {
                            await guideVM.askQuestion(question)
                        }
                        question = ""
                        dismiss()
                    }
                    .disabled(question.isEmpty)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(question.isEmpty ? .gray.opacity(0.2) : .blue)
                    .foregroundStyle(question.isEmpty ? Color.secondary : Color.white)
                    .clipShape(Capsule())
                }
                .padding()
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Quick questions
                VStack(alignment: .leading, spacing: 12) {
                    Text("sheet.ask.quickTitle")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(quickQuestions, id: \.self) { q in
                        Button(action: {
                            Task {
                                await guideVM.askQuestion(q)
                            }
                            dismiss()
                        }) {
                            Text(q)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.ask.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Answer Sheet
struct AnswerSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.answer.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("sheet.answer.sampleQuestion")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("sheet.answer.sampleAnswer")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.format("sheet.source.label.format", L10n.string("guide.source.palaceMuseum")), systemImage: "shield.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("sheet.answer.context", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.answer.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Route Sheet
struct RouteSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let route: Route

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.route.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text(L10n.format("sheet.route.today.format", route.name))
                        .font(.title2)
                        .fontWeight(.bold)
                }

                // Route stops
                VStack(spacing: 0) {
                    ForEach(route.stops) { stop in
                        RouteStopRow(stop: stop)
                    }
                }
                .padding()
                .background(.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("sheet.route.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.route.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

struct RouteStopRow: View {
    let stop: RouteStop

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name)
                    .font(.subheadline)
                    .fontWeight(stop.state == .active ? .bold : .regular)

                Text(stop.state == .active ? L10n.string("route.stop.active") : stop.meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if stop.state == .active {
                Image(systemName: "headphones")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch stop.state {
        case .completed: return .green
        case .active: return .blue
        case .upcoming: return .gray
        case .locked: return .gray.opacity(0.3)
        }
    }
}

// MARK: - Source Sheet
struct SourceSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let source: ContentSource?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.source.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("sheet.source.title")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("guide.source.palaceMuseum", systemImage: "shield.checkered")
                    Label("sheet.source.architectureDocs", systemImage: "book.fill")
                    Label("sheet.source.timelineReview", systemImage: "clock.arrow.circlepath")
                }
                .font(.subheadline)
                .padding()
                .background(.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("sheet.source.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.source.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Style Sheet
struct StyleSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStyle: GuideStyle

    let allStyles: [GuideStyle] = [.history, .architecture, .children, .legend, .casual, .inDepth]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.style.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("sheet.style.title")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(allStyles, id: \.self) { style in
                        Button(action: {
                            selectedStyle = style
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text(style.displayName)
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedStyle == style ? .blue : .gray.opacity(0.1))
                            .foregroundStyle(selectedStyle == style ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.style.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Roadmap Sheet
struct RoadmapSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("sheet.roadmap.eyebrow")
                        .font(.caption)
                        .foregroundStyle(.blue)

                    Text("sheet.roadmap.title")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("sheet.roadmap.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Roadmap items
                VStack(spacing: 16) {
                    RoadmapItem(
                        title: L10n.string("sheet.roadmap.guide.title"),
                        phase: L10n.string("sheet.roadmap.phase.current"),
                        description: L10n.string("sheet.roadmap.guide.description"),
                        isCurrent: true
                    )

                    RoadmapItem(
                        title: L10n.string("tab.see"),
                        phase: L10n.string("sheet.roadmap.phase.next"),
                        description: L10n.string("sheet.roadmap.scan.description"),
                        isCurrent: false
                    )

                    RoadmapItem(
                        title: L10n.string("tab.trip"),
                        phase: L10n.string("sheet.roadmap.phase.later"),
                        description: L10n.string("sheet.roadmap.trip.description"),
                        isCurrent: false
                    )
                }

                Spacer()
            }
            .padding()
            .navigationTitle("sheet.roadmap.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

struct RoadmapItem: View {
    let title: String
    let phase: String
    let description: String
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Phase indicator
            VStack {
                Circle()
                    .fill(isCurrent ? .blue : .gray.opacity(0.3))
                    .frame(width: 12, height: 12)

                if !isCurrent {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .frame(width: 1, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Text(phase)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isCurrent ? .blue : .gray.opacity(0.2))
                        .foregroundStyle(isCurrent ? Color.white : Color.secondary)
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Correct Sheet
struct CorrectSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let pois: [POI]
    let currentPOI: POI?
    let currentLocation: CLLocation?
    let onSelect: (POI) -> Void
    let onCreate: (String, String) -> Void

    @State private var customName = ""
    @State private var customDescription = ""
    @State private var isAddingCustomPOI = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("sheet.correct.eyebrow")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        Text("sheet.correct.title")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("sheet.correct.description")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    customPOISection

                    VStack(spacing: 8) {
                        if pois.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("sheet.correct.noCandidates", systemImage: "mappin.slash")
                                    .font(.subheadline.weight(.semibold))
                                Text("sheet.correct.noCandidates.description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        ForEach(pois) { poi in
                            Button(action: {
                                onSelect(poi)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: currentPOI?.id == poi.id ? "checkmark.circle.fill" : "location.fill")
                                        .foregroundStyle(currentPOI?.id == poi.id ? .green : .blue)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(poi.name)
                                            .font(.subheadline.weight(.semibold))

                                        Text(poi.source.name)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if currentPOI?.id == poi.id {
                                        Text("sheet.correct.current")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding()
                                .background(.gray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("sheet.correct.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }

    private var customPOISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isAddingCustomPOI.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(currentLocation == nil ? Color.secondary : Color.green)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("sheet.correct.addCurrent")
                            .font(.subheadline.weight(.semibold))
                        Text(currentLocation == nil ? L10n.string("sheet.correct.waitingLocation") : L10n.string("sheet.correct.useWhenNoCandidates"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isAddingCustomPOI ? 180 : 0))
                }
                .padding()
                .background(.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(currentLocation == nil)

            if isAddingCustomPOI {
                VStack(spacing: 10) {
                    TextField("sheet.correct.namePlaceholder", text: $customName)
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    TextField("sheet.correct.descriptionPlaceholder", text: $customDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        onCreate(customName, customDescription)
                        dismiss()
                    } label: {
                        Label("sheet.correct.addAndCalibrate", systemImage: "scope")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(canCreateCustomPOI ? Color.green : Color.gray.opacity(0.18))
                            .foregroundStyle(canCreateCustomPOI ? Color.white : Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canCreateCustomPOI)
                }
                .padding()
                .background(.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var canCreateCustomPOI: Bool {
        currentLocation != nil && !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview
#Preview("Ask Sheet") {
    AskSheetView(guideVM: GuideViewModel())
}

#Preview("Route Sheet") {
    RouteSheetView(route: .mock)
}
