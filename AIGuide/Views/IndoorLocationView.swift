// Indoor Location View - Indoor Positioning UI

import SwiftUI

struct IndoorLocationView: View {
    @StateObject private var indoorService = IndoorLocationService()
    @StateObject private var viewModel: IndoorMapViewModel
    @State private var showFloorPicker = false
    @Environment(\.dismiss) private var dismiss
    
    init() {
        let service = IndoorLocationService()
        _indoorService = StateObject(wrappedValue: service)
        _viewModel = StateObject(wrappedValue: IndoorMapViewModel(indoorService: service))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                statusBar
                
                // Indoor map
                indoorMap
                
                // Floor picker
                floorPicker
                
                // Zone list
                zoneList
            }
            .navigationTitle("室内定位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { indoorService.simulateIndoorPositioning() }) {
                        Label("模拟定位", systemImage: "location.fill")
                    }
                }
            }
            .onAppear {
                indoorService.requestAuthorization()
                indoorService.simulateIndoorPositioning()
            }
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Floor indicator
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .foregroundStyle(.blue)
                Text("F\(indoorService.currentFloor)")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.1))
            .clipShape(Capsule())
            
            // Zone indicator
            if !indoorService.currentZone.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle")
                        .foregroundStyle(.green)
                    Text(indoorService.currentZone)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.1))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Accuracy indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(accuracyColor)
                    .frame(width: 8, height: 8)
                Text(indoorService.positioningAccuracy.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Indoor Map
    private var indoorMap: some View {
        ZStack {
            // Map background
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
                .frame(height: 300)
                .padding()
            
            // Floor layout
            VStack(spacing: 20) {
                // Title
                Text(viewModel.currentFloorInfo?.name ?? "")
                    .font(.headline)
                
                // Zones
                ForEach(viewModel.zones) { zone in
                    ZoneCard(
                        zone: zone,
                        isSelected: viewModel.selectedZone == zone.id,
                        onTap: { viewModel.selectZone(zone.id) }
                    )
                }
            }
            .padding(40)
            
            // Beacon indicators
            ForEach(indoorService.nearbyBeacons) { beacon in
                BeaconIndicator(beacon: beacon)
                    .position(x: CGFloat(150 + beacon.minor * 50), y: CGFloat(100 + beacon.minor * 30))
            }
        }
    }
    
    // MARK: - Floor Picker
    private var floorPicker: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.floors) { floor in
                Button(action: { viewModel.switchFloor(floor.id) }) {
                    VStack(spacing: 4) {
                        Text("F\(floor.id)")
                            .font(.headline)
                            .fontWeight(viewModel.currentFloor == floor.id ? .bold : .regular)
                        
                        Text(floor.name)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.currentFloor == floor.id ? .blue : .clear)
                    .foregroundStyle(viewModel.currentFloor == floor.id ? .white : .primary)
                }
            }
        }
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    // MARK: - Zone List
    private var zoneList: some View {
        List {
            Section("当前楼层区域") {
                ForEach(viewModel.zones) { zone in
                    ZoneRow(
                        zone: zone,
                        isSelected: viewModel.selectedZone == zone.id,
                        onTap: { viewModel.selectZone(zone.id) }
                    )
                }
            }
            
            if !viewModel.highlightedPOIs.isEmpty {
                Section("区域内景点") {
                    ForEach(viewModel.highlightedPOIs, id: \.self) { poiId in
                        if let poi = POI.seedList.first(where: { $0.id == poiId }) {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(.blue)
                                Text(poi.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            
            Section("附近信标") {
                ForEach(indoorService.nearbyBeacons) { beacon in
                    BeaconRow(beacon: beacon)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helpers
    private var accuracyColor: Color {
        switch indoorService.positioningAccuracy {
        case .high: return .green
        case .medium: return .blue
        case .low: return .orange
        case .unavailable: return .red
        }
    }
}

// MARK: - Zone Card
struct ZoneCard: View {
    let zone: IndoorLocationService.ZoneInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .blue)
                
                Text(zone.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Text("\(zone.pois.count)个景点")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? .blue : .white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
    }
}

// MARK: - Zone Row
struct ZoneRow: View {
    let zone: IndoorLocationService.ZoneInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "mappin.circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("\(zone.pois.count)个景点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - Beacon Indicator
struct BeaconIndicator: View {
    let beacon: IndoorLocationService.BeaconInfo
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.blue)
            }
            
            Text("\(Int(beacon.distance))m")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Beacon Row
struct BeaconRow: View {
    let beacon: IndoorLocationService.BeaconInfo
    
    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(beacon.name)
                    .font(.headline)
                
                Text(beacon.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fm", beacon.distance))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                
                Text("\(beacon.rssi) dBm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    IndoorLocationView()
}
