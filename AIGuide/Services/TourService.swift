// Tour Service - Custom Tours & Routes

import Foundation

@MainActor
class TourService: ObservableObject {
    // MARK: - Published Properties
    @Published var presetTours: [Tour] = []
    @Published var customTours: [Tour] = []
    @Published var activeTour: Tour?
    @Published var currentStopIndex: Int = 0
    
    // MARK: - Types
    struct Tour: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let duration: TimeInterval
        let stops: [TourStop]
        let category: TourCategory
        let imageURL: String?
        let isCustom: Bool
        
        var formattedDuration: String {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            if hours > 0 {
                return L10n.format("common.hoursMinutes.short", hours, minutes)
            }
            return L10n.format("common.minutes.short", minutes)
        }
        
        var stopCount: Int {
            stops.count
        }
    }
    
    struct TourStop: Identifiable, Codable {
        let id: String
        let poiId: String
        let poiName: String
        let description: String
        let order: Int
        let estimatedDuration: TimeInterval
        
        var formattedDuration: String {
            let minutes = Int(estimatedDuration) / 60
            return L10n.format("common.minutes.short", minutes)
        }
    }
    
    enum TourCategory: String, Codable, CaseIterable {
        case classic = "经典"
        case culture = "文化"
        case family = "亲子"
        case photography = "摄影"
        case custom = "自定义"

        var localizedName: String {
            switch self {
            case .classic: return L10n.string("tour.category.classic")
            case .culture: return L10n.string("tour.category.culture")
            case .family: return L10n.string("tour.category.family")
            case .photography: return L10n.string("tour.category.photography")
            case .custom: return L10n.string("tour.category.custom")
            }
        }
        
        var icon: String {
            switch self {
            case .classic: return "star.fill"
            case .culture: return "book.fill"
            case .family: return "figure.2.and.child.holdinghands"
            case .photography: return "camera.fill"
            case .custom: return "slider.horizontal.3"
            }
        }
        
        var color: String {
            switch self {
            case .classic: return "red"
            case .culture: return "purple"
            case .family: return "blue"
            case .photography: return "orange"
            case .custom: return "green"
            }
        }
    }
    
    // MARK: - Private Properties
    private let customToursKey = "com.aiguide.custom.tours"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadPresetTours()
        loadCustomTours()
    }
    
    // MARK: - Public Methods
    
    /// Start a tour
    func startTour(_ tour: Tour) {
        activeTour = tour
        currentStopIndex = 0
    }
    
    /// Move to next stop
    func nextStop() {
        guard let tour = activeTour, currentStopIndex < tour.stops.count - 1 else {
            return
        }
        currentStopIndex += 1
    }
    
    /// Move to previous stop
    func previousStop() {
        guard currentStopIndex > 0 else { return }
        currentStopIndex -= 1
    }
    
    /// Stop current tour
    func stopTour() {
        activeTour = nil
        currentStopIndex = 0
    }
    
    /// Get current stop
    var currentStop: TourStop? {
        guard let tour = activeTour, currentStopIndex < tour.stops.count else {
            return nil
        }
        return tour.stops[currentStopIndex]
    }
    
    /// Create custom tour
    func createCustomTour(name: String, description: String, stops: [TourStop]) -> Tour {
        let tour = Tour(
            id: UUID().uuidString,
            name: name,
            description: description,
            duration: stops.reduce(0) { $0 + $1.estimatedDuration },
            stops: stops,
            category: .custom,
            imageURL: nil,
            isCustom: true
        )
        
        customTours.append(tour)
        saveCustomTours()
        
        return tour
    }
    
    /// Delete custom tour
    func deleteCustomTour(_ tour: Tour) {
        customTours.removeAll { $0.id == tour.id }
        saveCustomTours()
    }
    
    // MARK: - Private Methods
    
    private func loadPresetTours() {
        presetTours = [
            Tour(
                id: "tour1",
                name: L10n.string("tour.centralAxis.name"),
                description: L10n.string("tour.centralAxis.description"),
                duration: 7200, // 2 hours
                stops: [
                    TourStop(id: "s1", poiId: "wumen", poiName: L10n.string("poi.wumen.name"), description: L10n.string("tour.stop.wumen.mainGate"), order: 0, estimatedDuration: 600),
                    TourStop(id: "s2", poiId: "taihemen", poiName: L10n.string("poi.taihemen.name"), description: L10n.string("tour.stop.taihemen.outerCourtGate"), order: 1, estimatedDuration: 600),
                    TourStop(id: "s3", poiId: "taihedian", poiName: L10n.string("poi.taihedian.name"), description: L10n.string("tour.stop.taihedian.ceremony"), order: 2, estimatedDuration: 1200),
                    TourStop(id: "s4", poiId: "zhonghedian", poiName: L10n.string("poi.zhonghedian.name"), description: L10n.string("tour.stop.zhonghedian.pause"), order: 3, estimatedDuration: 600),
                    TourStop(id: "s5", poiId: "baohedian", poiName: L10n.string("poi.baohedian.name"), description: L10n.string("tour.stop.baohedian.exam"), order: 4, estimatedDuration: 900),
                    TourStop(id: "s6", poiId: "qianqinggong", poiName: L10n.string("poi.qianqinggong.name"), description: L10n.string("tour.stop.qianqinggong.residence"), order: 5, estimatedDuration: 1200),
                ],
                category: .classic,
                imageURL: nil,
                isCustom: false
            ),
            Tour(
                id: "tour2",
                name: L10n.string("tour.innerCourt.name"),
                description: L10n.string("tour.innerCourt.description"),
                duration: 5400, // 1.5 hours
                stops: [
                    TourStop(id: "s1", poiId: "qianqinggong", poiName: L10n.string("poi.qianqinggong.name"), description: L10n.string("tour.stop.qianqinggong.residence"), order: 0, estimatedDuration: 900),
                    TourStop(id: "s2", poiId: "jiaotaidian", poiName: L10n.string("tour.poi.jiaotaidian.name"), description: L10n.string("tour.stop.jiaotaidian.queenCeremony"), order: 1, estimatedDuration: 600),
                    TourStop(id: "s3", poiId: "kunninggong", poiName: L10n.string("tour.poi.kunninggong.name"), description: L10n.string("tour.stop.kunninggong.queenResidence"), order: 2, estimatedDuration: 900),
                    TourStop(id: "s4", poiId: "yuhuayuan", poiName: L10n.string("poi.yuhuayuan.name"), description: L10n.string("tour.stop.yuhuayuan.garden"), order: 3, estimatedDuration: 1200),
                ],
                category: .culture,
                imageURL: nil,
                isCustom: false
            ),
            Tour(
                id: "tour3",
                name: L10n.string("tour.family.name"),
                description: L10n.string("tour.family.description"),
                duration: 3600, // 1 hour
                stops: [
                    TourStop(id: "s1", poiId: "wumen", poiName: L10n.string("poi.wumen.name"), description: L10n.string("tour.stop.wumen.kids"), order: 0, estimatedDuration: 600),
                    TourStop(id: "s2", poiId: "taihedian", poiName: L10n.string("poi.taihedian.name"), description: L10n.string("tour.stop.taihedian.kids"), order: 1, estimatedDuration: 900),
                    TourStop(id: "s3", poiId: "yuhuayuan", poiName: L10n.string("poi.yuhuayuan.name"), description: L10n.string("tour.stop.yuhuayuan.kids"), order: 2, estimatedDuration: 1200),
                ],
                category: .family,
                imageURL: nil,
                isCustom: false
            ),
            Tour(
                id: "tour4",
                name: L10n.string("tour.photo.name"),
                description: L10n.string("tour.photo.description"),
                duration: 4800, // 1.3 hours
                stops: [
                    TourStop(id: "s1", poiId: "wumen", poiName: L10n.string("poi.wumen.name"), description: L10n.string("tour.stop.wumen.photo"), order: 0, estimatedDuration: 900),
                    TourStop(id: "s2", poiId: "taihedian", poiName: L10n.string("poi.taihedian.name"), description: L10n.string("tour.stop.taihedian.photo"), order: 1, estimatedDuration: 900),
                    TourStop(id: "s3", poiId: "jinshuiqiao", poiName: L10n.string("tour.poi.jinshuiqiao.name"), description: L10n.string("tour.stop.jinshuiqiao.reflection"), order: 2, estimatedDuration: 600),
                    TourStop(id: "s4", poiId: "jiaogulou", poiName: L10n.string("tour.poi.jiaogulou.name"), description: L10n.string("tour.stop.jiaogulou.sunset"), order: 3, estimatedDuration: 1200),
                ],
                category: .photography,
                imageURL: nil,
                isCustom: false
            ),
        ]
    }
    
    private func loadCustomTours() {
        if let data = defaults.data(forKey: customToursKey),
           let tours = try? JSONDecoder().decode([Tour].self, from: data) {
            customTours = tours
        }
    }
    
    private func saveCustomTours() {
        if let data = try? JSONEncoder().encode(customTours) {
            defaults.set(data, forKey: customToursKey)
        }
    }
}

// MARK: - Singleton
extension TourService {
    static let shared = TourService()
}
