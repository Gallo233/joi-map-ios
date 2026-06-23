import Foundation
import CoreLocation

// MARK: - POI (Point of Interest)
struct POI: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let category: POICategory
    let images: [String]
    let source: ContentSource

    enum CodingKeys: String, CodingKey {
        case id, name, description, coordinate, category, images, source
    }

    init(id: String, name: String, description: String, coordinate: CLLocationCoordinate2D, category: POICategory, images: [String], source: ContentSource) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
        self.category = category
        self.images = images
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let coord = try container.decode(Coordinate.self, forKey: .coordinate)
        coordinate = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        category = try container.decode(POICategory.self, forKey: .category)
        images = try container.decode([String].self, forKey: .images)
        source = try container.decode(ContentSource.self, forKey: .source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(Coordinate(coordinate), forKey: .coordinate)
        try container.encode(category, forKey: .category)
        try container.encode(images, forKey: .images)
        try container.encode(source, forKey: .source)
    }
}

// MARK: - Coordinate Helper
struct Coordinate: Codable {
    let latitude: Double
    let longitude: Double

    init(_ clLocation: CLLocationCoordinate2D) {
        self.latitude = clLocation.latitude
        self.longitude = clLocation.longitude
    }
}

// MARK: - POI Category
enum POICategory: String, Codable {
    case palace = "palace"
    case temple = "temple"
    case garden = "garden"
    case museum = "museum"
    case exhibit = "exhibit"
    case building = "building"
}

// MARK: - Content Source
struct ContentSource: Codable {
    let name: String
    let type: SourceType
    let verified: Bool

    enum SourceType: String, Codable {
        case official = "official"
        case curated = "curated"
        case userContributed = "user_contributed"
    }
}

// MARK: - Route
struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let stops: [RouteStop]
    let estimatedDuration: TimeInterval
    let distance: Double // meters
}

// MARK: - Route Stop
struct RouteStop: Identifiable, Codable {
    let id: String
    let poiId: String
    let name: String
    let order: Int
    let estimatedTime: TimeInterval
    let distanceFromPrevious: Double?
    var state: StopState = .upcoming
    var meta: String {
        switch state {
        case .completed: return L10n.string("route.stop.completed")
        case .active: return L10n.string("route.stop.active")
        case .upcoming:
            return distanceFromPrevious != nil
                ? L10n.format("route.stop.upcomingWithDistance.format", Int(estimatedTime / 60), Int(distanceFromPrevious!))
                : L10n.string("route.stop.upcoming")
        case .locked: return L10n.string("route.stop.locked")
        }
    }
}

enum StopState: String, Codable {
    case completed = "completed"
    case active = "active"
    case upcoming = "upcoming"
    case locked = "locked"
}

// MARK: - Audio Guide
struct AudioGuide: Identifiable, Codable {
    let id: String
    let poiId: String
    let style: GuideStyle
    let duration: GuideDuration
    let transcript: String
    let audioURL: URL?
    let source: ContentSource
}

enum GuideStyle: String, Codable, CaseIterable {
    case history = "history"
    case architecture = "architecture"
    case children = "children"
    case legend = "legend"
    case casual = "casual"
    case inDepth = "in_depth"

    var displayName: String {
        switch self {
        case .history: return L10n.string("guide.style.history")
        case .architecture: return L10n.string("guide.style.architecture")
        case .children: return L10n.string("guide.style.children")
        case .legend: return L10n.string("guide.style.legend")
        case .casual: return L10n.string("guide.style.casual")
        case .inDepth: return L10n.string("guide.style.inDepth")
        }
    }
}

enum GuideDuration: Int, Codable, CaseIterable {
    case short = 60
    case long = 120

    var displayText: String {
        L10n.format("guide.duration.seconds.format", rawValue)
    }
}

// MARK: - Location Confidence
struct LocationConfidence: Identifiable {
    let id = UUID()
    let poi: POI
    let confidence: Double // 0.0 - 1.0
    let rank: Int
    let distance: CLLocationDistance?
    let evidence: [String]
    let isRecommendation: Bool

    init(
        poi: POI,
        confidence: Double,
        rank: Int,
        distance: CLLocationDistance? = nil,
        evidence: [String] = [],
        isRecommendation: Bool = false
    ) {
        self.poi = poi
        self.confidence = confidence
        self.rank = rank
        self.distance = distance
        self.evidence = evidence
        self.isRecommendation = isRecommendation
    }

    var distanceText: String? {
        guard let distance else { return nil }
        if distance < 1_000 {
            return "\(Int(distance.rounded()))m"
        }
        return String(format: "%.1fkm", distance / 1_000)
    }
}

enum GuideContextPhase: Equatable {
    case locating
    case nearbyMatch
    case visualConfirmed
    case manual
    case recommending
    case recommended
    case empty
    case offline
}

// MARK: - QA Session
struct QASession: Identifiable, Codable {
    let id: String
    let poiId: String
    let question: String
    let answer: String
    let sources: [ContentSource]
    let timestamp: Date
}

// MARK: - Mock Data
extension POI {
    static var mock: POI {
        POI(
            id: "taihedian",
            name: L10n.string("poi.taihedian.name"),
            description: L10n.string("poi.taihedian.description"),
            coordinate: CLLocationCoordinate2D(latitude: 39.9163, longitude: 116.3972),
            category: .palace,
            images: ["taihedian_1"],
            source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
        )
    }

    static var mockList: [POI] {
        [
            .mock,
            POI(
                id: "zhonghedian",
                name: L10n.string("poi.zhonghedian.name"),
                description: L10n.string("poi.zhonghedian.description"),
                coordinate: CLLocationCoordinate2D(latitude: 39.9159, longitude: 116.3972),
                category: .palace,
                images: ["zhonghedian_1"],
                source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
            ),
            POI(
                id: "baohedian",
                name: L10n.string("poi.baohedian.name"),
                description: L10n.string("poi.baohedian.description"),
                coordinate: CLLocationCoordinate2D(latitude: 39.9155, longitude: 116.3972),
                category: .palace,
                images: ["baohedian_1"],
                source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
            ),
            POI(
                id: "wumen",
                name: L10n.string("poi.wumen.name"),
                description: L10n.string("poi.wumen.description"),
                coordinate: CLLocationCoordinate2D(latitude: 39.9139, longitude: 116.3972),
                category: .palace,
                images: ["wumen_1"],
                source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
            ),
            POI(
                id: "taihemen",
                name: L10n.string("poi.taihemen.name"),
                description: L10n.string("poi.taihemen.description"),
                coordinate: CLLocationCoordinate2D(latitude: 39.9153, longitude: 116.3972),
                category: .palace,
                images: ["taihemen_1"],
                source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
            ),
            POI(
                id: "qianqinggong",
                name: L10n.string("poi.qianqinggong.name"),
                description: L10n.string("poi.qianqinggong.description"),
                coordinate: CLLocationCoordinate2D(latitude: 39.9172, longitude: 116.3972),
                category: .palace,
                images: ["qianqinggong_1"],
                source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
            )
        ]
    }
}

extension Route {
    static var nearbyPlaceholder: Route {
        Route(
            id: "nearby-placeholder",
            name: L10n.string("route.nearbyPlaceholder.name"),
            description: L10n.string("route.nearbyPlaceholder.description"),
            stops: [],
            estimatedDuration: 0,
            distance: 0
        )
    }

    static var mock: Route {
        Route(
            id: "central-axis",
            name: L10n.string("route.centralAxis.name"),
            description: L10n.string("route.centralAxis.description"),
            stops: [
                RouteStop(id: "wumen", poiId: "wumen", name: L10n.string("poi.wumen.name"), order: 0, estimatedTime: 0, distanceFromPrevious: nil, state: .completed),
                RouteStop(id: "taihedian", poiId: "taihedian", name: L10n.string("poi.taihedian.name"), order: 1, estimatedTime: 180, distanceFromPrevious: 0, state: .active),
                RouteStop(id: "zhonghedian", poiId: "zhonghedian", name: L10n.string("poi.zhonghedian.name"), order: 2, estimatedTime: 180, distanceFromPrevious: 210, state: .upcoming),
                RouteStop(id: "baohedian", poiId: "baohedian", name: L10n.string("poi.baohedian.name"), order: 3, estimatedTime: 180, distanceFromPrevious: 150, state: .upcoming)
            ],
            estimatedDuration: 5400,
            distance: 1200
        )
    }
}

extension AudioGuide {
    static var mock: AudioGuide {
        AudioGuide(
            id: "taihedian-history-60",
            poiId: "taihedian",
            style: .history,
            duration: .short,
            transcript: L10n.string("audioGuide.taihedian.history.short"),
            audioURL: nil,
            source: ContentSource(name: L10n.string("guide.source.palaceMuseum"), type: .official, verified: true)
        )
    }
}
