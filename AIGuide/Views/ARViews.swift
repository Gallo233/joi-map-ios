// AR Views

import SwiftUI
import ARKit
import RealityKit

// MARK: - AR View Representable
struct ARViewContainer: UIViewRepresentable {
    let arService: ARService
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        arView.session.run(config)
        
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}

// MARK: - Compass View
struct CompassView: View {
    let heading: Double
    let pois: [ARService.ARPOI]
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 200, height: 200)
                
                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    Text(direction)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .offset(y: -90)
                        .rotationEffect(directionAngle(direction))
                }
                
                ForEach(pois) { poi in
                    POICompassIndicator(poi: poi, heading: heading)
                }
                
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                    .font(.title2)
                
                Image(systemName: "triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .offset(y: -85)
                    .rotationEffect(.degrees(-heading))
            }
            .rotationEffect(.degrees(-heading))
            
            Text("\(Int(heading))° \(getCompassDirection(heading))")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }
    
    private func directionAngle(_ direction: String) -> Angle {
        switch direction {
        case "N": return .degrees(0)
        case "E": return .degrees(90)
        case "S": return .degrees(180)
        case "W": return .degrees(270)
        default: return .degrees(0)
        }
    }
    
    private func getCompassDirection(_ heading: Double) -> String {
        switch heading {
        case 0..<22.5, 337.5..<360: return "北"
        case 22.5..<67.5: return "东北"
        case 67.5..<112.5: return "东"
        case 112.5..<157.5: return "东南"
        case 157.5..<202.5: return "南"
        case 202.5..<247.5: return "西南"
        case 247.5..<292.5: return "西"
        case 292.5..<337.5: return "西北"
        default: return ""
        }
    }
}

// MARK: - POI Compass Indicator
struct POICompassIndicator: View {
    let poi: ARService.ARPOI
    let heading: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: categoryIcon)
                .font(.caption2)
                .foregroundStyle(.white)
            
            Text(poi.name)
                .font(.system(size: 8))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(4)
        .background(.blue.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .offset(y: -70)
        .rotationEffect(.degrees(poi.bearing))
    }
    
    private var categoryIcon: String {
        switch poi.category {
        case "palace": return "building.2.fill"
        case "temple": return "building.columns.fill"
        case "garden": return "leaf.fill"
        default: return "mappin.circle.fill"
        }
    }
}

// MARK: - AR Overlay View
struct AROverlayView: View {
    let pois: [ARService.ARPOI]
    let heading: Double
    
    var body: some View {
        VStack {
            CompassView(heading: heading, pois: pois)
                .padding(.top, 60)
            
            Spacer()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pois.prefix(5)) { poi in
                        ARPOICard(poi: poi)
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }
}

// MARK: - AR POI Card
struct ARPOICard: View {
    let poi: ARService.ARPOI
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundStyle(.blue)
                Text(poi.name)
                    .font(.headline)
            }
            
            Text(poi.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(formatDistance(poi.distance), systemImage: "location")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Text("\(Int(poi.bearing))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 200)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
    
    private var categoryIcon: String {
        switch poi.category {
        case "palace": return "building.2.fill"
        case "temple": return "building.columns.fill"
        case "garden": return "leaf.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 100 {
            return "\(Int(distance))米"
        } else if distance < 1000 {
            return "\(Int(distance / 10) * 10)米"
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
}

// MARK: - AR Marker View
struct ARMarkerView: View {
    let poi: ARService.ARPOI
    let heading: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(formatDistance(poi.distance))
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 2)
                
                Image(systemName: categoryIcon)
                    .foregroundStyle(.blue)
            }
            
            Text(poi.name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .position(calculatePosition())
    }
    
    private func calculatePosition() -> CGPoint {
        let screenCenter = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 3)
        let angle = (poi.bearing - heading) * .pi / 180
        let radius: CGFloat = 120
        
        return CGPoint(
            x: screenCenter.x + radius * CGFloat(sin(angle)),
            y: screenCenter.y - radius * CGFloat(cos(angle))
        )
    }
    
    private var categoryIcon: String {
        switch poi.category {
        case "palace": return "building.2.fill"
        case "temple": return "building.columns.fill"
        case "garden": return "leaf.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 100 {
            return "\(Int(distance))m"
        } else if distance < 1000 {
            return "\(Int(distance / 10) * 10)m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - AR POI List Row
struct ARPOIListRow: View {
    let poi: ARService.ARPOI
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: categoryIcon)
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(poi.name)
                    .font(.headline)
                
                Text(poi.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDistance(poi.distance))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .rotationEffect(.degrees(poi.bearing))
                    Text("\(Int(poi.bearing))°")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var categoryIcon: String {
        switch poi.category {
        case "palace": return "building.2.fill"
        case "temple": return "building.columns.fill"
        case "garden": return "leaf.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 100 {
            return "\(Int(distance))米"
        } else if distance < 1000 {
            return "\(Int(distance / 10) * 10)米"
        } else {
            return String(format: "%.1f公里", distance / 1000)
        }
    }
}

// MARK: - AR POI Detail View
struct ARPOIDetailView: View {
    let poi: ARService.ARPOI
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: categoryIcon)
                                .font(.title)
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(poi.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(poi.category)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        InfoCard(title: L10n.string("ar.detail.distance"), value: formatDistance(poi.distance), icon: "location")
                        InfoCard(title: L10n.string("ar.detail.bearing"), value: "\(Int(poi.bearing))°", icon: "arrow.up.circle")
                        InfoCard(title: L10n.string("ar.detail.direction"), value: getCompassDirection(poi.bearing), icon: "compass")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.string("简介"))
                            .font(.headline)
                        
                        Text(poi.description)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Label(L10n.string("查看讲解"), systemImage: "book.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button(action: {}) {
                            Label(L10n.string("导航"), systemImage: "arrow.triangle.turn.up.right.diamond")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.string("景点详情"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("关闭")) { dismiss() }
                }
            }
        }
    }
    
    private var categoryIcon: String {
        switch poi.category {
        case "palace": return "building.2.fill"
        case "temple": return "building.columns.fill"
        case "garden": return "leaf.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 100 {
            return L10n.format("distance.meters.format", Int(distance))
        } else if distance < 1000 {
            return L10n.format("distance.meters.format", Int(distance / 10) * 10)
        } else {
            return L10n.format("distance.kilometers.format", distance / 1000)
        }
    }
    
    private func getCompassDirection(_ bearing: Double) -> String {
        switch bearing {
        case 0..<22.5, 337.5..<360: return L10n.string("direction.north")
        case 22.5..<67.5: return L10n.string("direction.northeast")
        case 67.5..<112.5: return L10n.string("direction.east")
        case 112.5..<157.5: return L10n.string("direction.southeast")
        case 157.5..<202.5: return L10n.string("direction.south")
        case 202.5..<247.5: return L10n.string("direction.southwest")
        case 247.5..<292.5: return L10n.string("direction.west")
        case 292.5..<337.5: return L10n.string("direction.northwest")
        default: return ""
        }
    }
}

// MARK: - Info Card
struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
