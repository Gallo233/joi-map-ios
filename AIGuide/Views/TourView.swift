// Tour View - Browse & Follow Tours

import SwiftUI

struct TourListView: View {
    @StateObject private var tourService = TourService.shared
    @State private var selectedCategory: TourService.TourCategory? = nil
    @State private var showCreateTour = false
    
    var filteredTours: [TourService.Tour] {
        let tours = tourService.presetTours + tourService.customTours
        if let category = selectedCategory {
            return tours.filter { $0.category == category }
        }
        return tours
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryFilter
                
                // Tours list
                toursList
            }
            .navigationTitle("tour.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateTour = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateTour) {
                CreateTourView()
            }
        }
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All
                CategoryChip(
                    title: L10n.string("tour.all"),
                    icon: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }
                
                // Categories
                ForEach(TourService.TourCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.localizedName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Tours List
    private var toursList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredTours) { tour in
                    NavigationLink(destination: TourDetailView(tour: tour)) {
                        TourCard(tour: tour)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? .blue : .gray.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Tour Card
struct TourCard: View {
    let tour: TourService.Tour
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tour.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(tour.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Category badge
                Label(tour.category.localizedName, systemImage: tour.category.icon)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.1))
                    .foregroundStyle(categoryColor)
                    .clipShape(Capsule())
            }
            
            // Info row
            HStack(spacing: 16) {
                Label(tour.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label(L10n.format("tour.spotCount.format", tour.stopCount), systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Start button
                Text("tour.start")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            
            // Stops preview
            HStack(spacing: 0) {
                ForEach(tour.stops.prefix(5)) { stop in
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    
                    if stop.id != tour.stops.prefix(5).last?.id {
                        Rectangle()
                            .fill(.blue.opacity(0.3))
                            .frame(height: 2)
                    }
                }
                
                if tour.stops.count > 5 {
                    Text("+\(tour.stops.count - 5)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    private var categoryColor: Color {
        switch tour.category {
        case .classic: return .red
        case .culture: return .purple
        case .family: return .blue
        case .photography: return .orange
        case .custom: return .green
        }
    }
}

// MARK: - Tour Detail View
struct TourDetailView: View {
    let tour: TourService.Tour
    @StateObject private var tourService = TourService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Stops list
                stopsSection
                
                // Start button
                startButton
            }
            .padding()
        }
        .navigationTitle(tour.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category & duration
            HStack {
                Label(tour.category.localizedName, systemImage: tour.category.icon)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Label(tour.formattedDuration, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text(tour.description)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("tour.stops")
                .font(.headline)
            
            ForEach(Array(tour.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 12) {
                    // Number
                    ZStack {
                        Circle()
                            .fill(.blue)
                            .frame(width: 28, height: 28)
                        
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.poiName)
                            .font(.headline)
                        
                        Text(stop.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Duration
                    Text(stop.formattedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if index < tour.stops.count - 1 {
                    HStack {
                        Rectangle()
                            .fill(.blue.opacity(0.3))
                            .frame(width: 2, height: 20)
                            .offset(x: 13)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var startButton: some View {
        Button(action: {
            tourService.startTour(tour)
            dismiss()
        }) {
            Label("tour.startRoute", systemImage: "play.fill")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Create Tour View
struct CreateTourView: View {
    @StateObject private var tourService = TourService.shared
    @State private var name = ""
    @State private var description = ""
    @State private var selectedStops: [TourService.TourStop] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("common.basicInfo") {
                    TextField("tour.routeName", text: $name)
                    TextField("tour.routeDescription", text: $description)
                }
                
                Section("tour.choosePlaces") {
                    ForEach(POI.mockList) { poi in
                        Button(action: { toggleStop(poi) }) {
                            HStack {
                                Text(poi.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedStops.contains(where: { $0.poiId == poi.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                if !selectedStops.isEmpty {
                    Section(L10n.format("tour.selectedSpots.format", selectedStops.count)) {
                        ForEach(selectedStops) { stop in
                            Text(stop.poiName)
                        }
                    }
                }
            }
            .navigationTitle("tour.create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.create") {
                        createTour()
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedStops.isEmpty)
                }
            }
        }
    }
    
    private func toggleStop(_ poi: POI) {
        if let index = selectedStops.firstIndex(where: { $0.poiId == poi.id }) {
            selectedStops.remove(at: index)
        } else {
            let stop = TourService.TourStop(
                id: UUID().uuidString,
                poiId: poi.id,
                poiName: poi.name,
                description: poi.description,
                order: selectedStops.count,
                estimatedDuration: 600 // 10 minutes default
            )
            selectedStops.append(stop)
        }
    }
    
    private func createTour() {
        _ = tourService.createCustomTour(
            name: name,
            description: description,
            stops: selectedStops
        )
    }
}

// MARK: - Preview
#Preview {
    TourListView()
}
