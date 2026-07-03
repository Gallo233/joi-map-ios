// Journey Narrative Service - Tour Storytelling

import Foundation

@MainActor
class JourneyNarrativeService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentJourney: Journey?
    @Published var chapters: [Chapter] = []
    @Published var currentChapterIndex: Int = 0
    @Published var isRecording = false
    @Published var journeyStats: JourneyStats?
    
    // MARK: - Types
    struct Journey: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let startTime: Date
        var endTime: Date?
        var chapters: [Chapter]
        var photos: [JourneyPhoto]
        var notes: [JourneyNote]
        
        var duration: TimeInterval {
            (endTime ?? Date()).timeIntervalSince(startTime)
        }
        
        var formattedDuration: String {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            if hours > 0 {
                return "\(hours)小时\(minutes)分钟"
            }
            return "\(minutes)分钟"
        }
    }
    
    struct Chapter: Identifiable, Codable {
        let id: String
        let poiId: String
        let poiName: String
        let title: String
        let content: String
        let visitTime: Date
        let duration: TimeInterval
        let photos: [String] // Photo IDs
        let highlights: [String]
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: visitTime)
        }
    }
    
    struct JourneyPhoto: Identifiable, Codable {
        let id: String
        let chapterId: String?
        let imageData: Data?
        let caption: String?
        let timestamp: Date
    }
    
    struct JourneyNote: Identifiable, Codable {
        let id: String
        let chapterId: String?
        let content: String
        let timestamp: Date
    }
    
    struct JourneyStats: Codable {
        let totalJourneys: Int
        let totalChapters: Int
        let totalPhotos: Int
        let totalDuration: TimeInterval
        let favoritePOIs: [String]
        
        var formattedDuration: String {
            let hours = Int(totalDuration) / 3600
            return "\(hours)小时"
        }
    }
    
    // MARK: - Private Properties
    private let storageKey = "com.aiguide.journeys"
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    init() {
        loadJourneys()
    }
    
    // MARK: - Public Methods
    
    /// Start a new journey
    func startJourney(name: String, description: String) {
        currentJourney = Journey(
            id: UUID().uuidString,
            name: name,
            description: description,
            startTime: Date(),
            chapters: [],
            photos: [],
            notes: []
        )
        chapters = []
        currentChapterIndex = 0
        isRecording = true
    }
    
    /// Add a chapter when visiting a POI
    func addChapter(poi: POI, duration: TimeInterval, highlights: [String] = []) {
        guard var journey = currentJourney else { return }
        
        let chapter = Chapter(
            id: UUID().uuidString,
            poiId: poi.id,
            poiName: poi.name,
            title: L10n.format("journey.chapter.title.format", chapters.count + 1, poi.name),
            content: generateChapterContent(poi: poi),
            visitTime: Date(),
            duration: duration,
            photos: [],
            highlights: highlights
        )
        
        chapters.append(chapter)
        journey.chapters = chapters
        currentJourney = journey
        currentChapterIndex = chapters.count - 1
    }
    
    /// Add a photo to current chapter
    func addPhoto(imageData: Data, caption: String? = nil) {
        guard var journey = currentJourney else { return }
        
        let photo = JourneyPhoto(
            id: UUID().uuidString,
            chapterId: chapters.last?.id,
            imageData: imageData,
            caption: caption,
            timestamp: Date()
        )
        
        journey.photos.append(photo)
        currentJourney = journey
    }
    
    /// Add a note to current chapter
    func addNote(content: String) {
        guard var journey = currentJourney else { return }
        
        let note = JourneyNote(
            id: UUID().uuidString,
            chapterId: chapters.last?.id,
            content: content,
            timestamp: Date()
        )
        
        journey.notes.append(note)
        currentJourney = journey
    }
    
    /// End current journey
    func endJourney() {
        guard var journey = currentJourney else { return }
        
        journey.endTime = Date()
        currentJourney = journey
        isRecording = false
        
        // Save journey
        saveJourney(journey)
        
        // Update stats
        updateStats()
    }
    
    /// Get journey summary
    func getJourneySummary() -> String? {
        guard let journey = currentJourney else { return nil }
        
        var summary = "## \(journey.name)\n\n"
        summary += "\(journey.description)\n\n"
        summary += "**游览时长**: \(journey.formattedDuration)\n"
        summary += "**访问景点**: \(chapters.count)个\n\n"
        
        for (_, chapter) in chapters.enumerated() {
            summary += "### \(chapter.title)\n"
            summary += "**时间**: \(chapter.formattedTime)\n"
            summary += "\(chapter.content)\n\n"
        }
        
        return summary
    }
    
    /// Share journey
    func shareJourney() -> String? {
        guard let journey = currentJourney else { return nil }
        
        var text = "我在故宫的游览故事\n\n"
        text += "📍 访问了 \(chapters.count) 个景点\n"
        text += "⏱️ 游览时长 \(journey.formattedDuration)\n\n"
        
        for chapter in chapters {
            text += "🏛️ \(chapter.poiName)\n"
        }
        
        text += "\n#故宫导览 #AI讲解"
        
        return text
    }
    
    // MARK: - Private Methods
    
    private func generateChapterContent(poi: POI) -> String {
        // Generate chapter content based on POI
        return """
        \(poi.name)是\(poi.description)
        
        这里见证了无数历史时刻，每一块砖石都诉说着过去的故事。
        """
    }
    
    private func saveJourney(_ journey: Journey) {
        var journeys = loadAllJourneys()
        journeys.append(journey)
        
        if let data = try? JSONEncoder().encode(journeys) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadJourneys() {
        // Load recent journeys for stats
        let journeys = loadAllJourneys()
        updateStats(from: journeys)
    }
    
    private func loadAllJourneys() -> [Journey] {
        guard let data = defaults.data(forKey: storageKey),
              let journeys = try? JSONDecoder().decode([Journey].self, from: data) else {
            return []
        }
        return journeys
    }
    
    private func updateStats(from journeys: [Journey]? = nil) {
        let allJourneys = journeys ?? loadAllJourneys()
        
        let totalChapters = allJourneys.reduce(0) { $0 + $1.chapters.count }
        let totalPhotos = allJourneys.reduce(0) { $0 + $1.photos.count }
        let totalDuration = allJourneys.reduce(0) { $0 + $1.duration }
        
        // Find favorite POIs
        var poiCounts: [String: Int] = [:]
        for journey in allJourneys {
            for chapter in journey.chapters {
                poiCounts[chapter.poiId, default: 0] += 1
            }
        }
        let favoritePOIs = poiCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        
        journeyStats = JourneyStats(
            totalJourneys: allJourneys.count,
            totalChapters: totalChapters,
            totalPhotos: totalPhotos,
            totalDuration: totalDuration,
            favoritePOIs: favoritePOIs
        )
    }
}
