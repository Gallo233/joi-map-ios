// See And Ask Service - Photo Recognition + Q&A

import Foundation
import CoreLocation
import UIKit
import Vision

@MainActor
class SeeAndAskService: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var recognizedObject: RecognizedObject?
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var currentQuestion = ""
    @Published var currentAnswer = ""
    @Published var showCamera = false
    @Published var isAnswering = false
    @Published var errorMessage: String?
    @Published var recognitionCandidates: [RecognitionCandidate] = []

    // MARK: - Types
    struct RecognizedObject: Identifiable {
        let id: String
        let name: String
        let category: String
        let description: String
        let confidence: Double
        let relatedPOI: POI?
        let imageData: Data?
        let sourceName: String
        let sourceVerified: Bool
    }

    struct ConversationMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let content: String
        let timestamp: Date

        enum MessageRole {
            case user
            case assistant
        }
    }

    struct RecognitionCandidate: Identifiable {
        let id = UUID()
        let rank: Int
        let name: String
        let confidence: Double
        let poi: POI?

        init(rank: Int, name: String, confidence: Double, poi: POI? = nil) {
            self.rank = rank
            self.name = name
            self.confidence = confidence
            self.poi = poi
        }
    }

    // MARK: - Private Properties
    private let visionService = VisionService()
    private let apiClient = APIClient()
    private let locationService = LocationService()
    private let memoryStore = JourneyMemoryStore.shared
    private var activeQuestionID: UUID?

    // MARK: - Public Methods

    /// Process image and recognize object
    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        recognizedObject = nil
        recognitionCandidates = []
        defer { isProcessing = false }

        // Save an API-friendly image copy. Sending the original camera image is
        // slow on mobile networks and can exceed multimodal request limits.
        let imageData = compressedJPEGData(for: image)

        if let backendResult = await recognizeImageWithBackend(imageData: imageData) {
            applyBackendRecognition(backendResult, imageData: imageData)
            return
        }

        // Recognize using Vision framework
        if let result = await visionService.recognizeImage(image) {
            // Find related POI
            let recognitionLocation = locationService.currentLocation
            let relatedPOI = findRelatedPOI(for: result.label, near: recognitionLocation)
            let sourceName = relatedPOI.map { localizedSourceName($0.source.name) } ?? L10n.string("see.source.localVision")

            recognizedObject = RecognizedObject(
                id: UUID().uuidString,
                name: relatedPOI?.name ?? result.label,
                category: localizedCategory(result.category, poi: relatedPOI),
                description: relatedPOI?.description ?? result.description,
                confidence: result.confidence,
                relatedPOI: relatedPOI,
                imageData: imageData,
                sourceName: sourceName,
                sourceVerified: relatedPOI?.source.verified ?? false
            )
            recognitionCandidates = makeCandidates(primary: result, relatedPOI: relatedPOI, near: recognitionLocation)

            // Add initial message
            conversationHistory = [
                ConversationMessage(
                    role: .assistant,
                    content: initialAssistantMessage(result: result, relatedPOI: relatedPOI),
                    timestamp: Date()
                )
            ]
        } else {
            errorMessage = visionService.error?.localizedDescription ?? L10n.string("see.error.noClearObject")
        }
    }

    /// Ask a question about the recognized object
    func askQuestion(_ question: String) async {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let object = recognizedObject else { return }
        guard !trimmedQuestion.isEmpty, !isAnswering else { return }

        currentQuestion = trimmedQuestion
        isAnswering = true
        errorMessage = nil
        let requestID = UUID()
        activeQuestionID = requestID
        defer {
            if activeQuestionID == requestID {
                isAnswering = false
                activeQuestionID = nil
            }
        }

        // Add user message
        conversationHistory.append(
            ConversationMessage(role: .user, content: trimmedQuestion, timestamp: Date())
        )

        // Generate answer
        let answer = await generateAnswer(
            object: object,
            question: trimmedQuestion,
            history: conversationHistory
        )
        guard activeQuestionID == requestID else { return }

        currentAnswer = answer

        // Add assistant message
        conversationHistory.append(
            ConversationMessage(role: .assistant, content: answer, timestamp: Date())
        )

        memoryStore.addRecognitionQuestion(
            objectName: object.name,
            category: object.category,
            question: trimmedQuestion,
            answer: answer,
            sourceName: object.sourceName
        )
    }

    /// Clear conversation
    func clearConversation() {
        recognizedObject = nil
        conversationHistory = []
        currentQuestion = ""
        currentAnswer = ""
        errorMessage = nil
        recognitionCandidates = []
        activeQuestionID = nil
        isAnswering = false
    }

    /// Let the user promote a visual candidate when the model chose the wrong match.
    func selectCandidate(_ candidate: RecognitionCandidate) {
        guard let poi = candidate.poi else { return }
        let imageData = recognizedObject?.imageData

        recognizedObject = RecognizedObject(
            id: UUID().uuidString,
            name: poi.name,
            category: localizedCategory(nil, poi: poi),
            description: poi.description,
            confidence: candidate.confidence,
            relatedPOI: poi,
            imageData: imageData,
            sourceName: localizedSourceName(poi.source.name),
            sourceVerified: poi.source.verified
        )
        currentAnswer = ""
        conversationHistory = [
            ConversationMessage(
                role: .assistant,
                content: L10n.format(
                    "see.initial.calibrated.format",
                    poi.name,
                    poi.description,
                    localizedSourceName(poi.source.name)
                ),
                timestamp: Date()
            )
        ]
    }

    // MARK: - Private Methods

    private func compressedJPEGData(for image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1280
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / max(longestSide, 1))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        guard scale < 1 else {
            return image.jpegData(compressionQuality: 0.76)
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.76)
    }

    private func recognizeImageWithBackend(imageData: Data?) async -> BackendVisionResponse? {
        guard let imageData else { return nil }

        var body: [String: Any] = [
            "image_base64": imageData.base64EncodedString(),
            "mime_type": "image/jpeg"
        ]

        if let location = await currentLocationForRecognition() {
            body["latitude"] = location.coordinate.latitude
            body["longitude"] = location.coordinate.longitude
        }

        do {
            let response: BackendVisionResponse = try await apiClient.post(
                endpoint: APIConfig.Endpoints.visionIdentify,
                body: body
            )
            return response.identified ? response : nil
        } catch {
            return nil
        }
    }

    private func currentLocationForRecognition() async -> CLLocation? {
        if let currentLocation = locationService.currentLocation {
            return currentLocation
        }

        guard locationService.isAuthorized else { return nil }
        return try? await locationService.requestLocation()
    }

    private func applyBackendRecognition(_ response: BackendVisionResponse, imageData: Data?) {
        let recognitionLocation = locationService.currentLocation
        let relatedPOI = response.poi
            ?? response.suggestions.first
            ?? response.label.flatMap { findRelatedPOI(for: $0, near: recognitionLocation) }
        let source = response.source
            ?? relatedPOI?.source
            ?? ContentSource(name: L10n.string("see.source.mimoVision"), type: .curated, verified: false)
        let name = relatedPOI?.name ?? response.label ?? L10n.string("see.unknownObject")
        let description = relatedPOI?.description
            ?? response.description
            ?? L10n.string("see.description.unreliable")

        recognizedObject = RecognizedObject(
            id: UUID().uuidString,
            name: name,
            category: localizedCategory(response.category, poi: relatedPOI),
            description: description,
            confidence: response.confidence,
            relatedPOI: relatedPOI,
            imageData: imageData,
            sourceName: localizedSourceName(source.name),
            sourceVerified: source.verified
        )
        recognitionCandidates = makeCandidates(from: response, near: recognitionLocation)
        conversationHistory = [
            ConversationMessage(
                role: .assistant,
                content: initialAssistantMessage(
                    response: response,
                    relatedPOI: relatedPOI,
                    source: source
                ),
                timestamp: Date()
            )
        ]
    }

    private func findRelatedPOI(for label: String, near location: CLLocation?) -> POI? {
        rankedPOIs(matching: label, near: location).first?.poi
    }

    private func generateAnswer(
        object: RecognizedObject,
        question: String,
        history: [ConversationMessage]
    ) async -> String {
        let historyPayload = history.suffix(6).map { msg in
            [
                "role": msg.role.apiRole,
                "content": msg.content
            ]
        }

        if let poi = object.relatedPOI {
            do {
                let body: [String: Any] = [
                    "poi_id": poi.id,
                    "poi_name": poi.name,
                    "poi_description": poi.description,
                    "question": question,
                    "history": historyPayload
                ]

                let response: QAResponse = try await apiClient.post(
                    endpoint: APIConfig.Endpoints.qaAsk,
                    body: body
                )
                return response.answer
            } catch {
                errorMessage = L10n.string("see.error.backendQAFallback")
            }
        }

        return localAnswer(object: object, question: question)
    }

    private func initialAssistantMessage(result: VisionService.RecognitionResult, relatedPOI: POI?) -> String {
        if let poi = relatedPOI {
            return L10n.format(
                "see.initial.poi.format",
                poi.name,
                poi.description,
                localizedSourceName(poi.source.name)
            )
        }

        return L10n.format(
            "see.initial.visionOnly.format",
            result.label,
            Int(result.confidence * 100)
        )
    }

    private func initialAssistantMessage(
        response: BackendVisionResponse,
        relatedPOI: POI?,
        source: ContentSource
    ) -> String {
        if let poi = relatedPOI {
            return L10n.format(
                "see.initial.poi.format",
                poi.name,
                poi.description,
                localizedSourceName(source.name)
            )
        }

        let label = response.label ?? L10n.string("see.visualSubject")
        let description = response.description ?? L10n.string("see.description.unreliableShort")
        return L10n.format(
            "see.initial.backendVisionOnly.format",
            label,
            Int(response.confidence * 100),
            description
        )
    }

    private func localAnswer(object: RecognizedObject, question: String) -> String {
        let lowerQuestion = question.lowercased()
        let childIntent = question.contains("孩子") || lowerQuestion.contains("child")
        let craftIntent = question.contains("工艺") || question.contains("建筑") || question.contains("结构")
        let importanceIntent = question.contains("重要") || question.contains("为什么")
        let focusIntent = question.contains("看哪里") || question.contains("值得看") || question.contains("先看")
        let shortIntent = question.contains("30秒") || question.contains("三十秒") || lowerQuestion.contains("brief")
        let nextIntent = question.contains("下一步") || question.contains("去哪") || question.contains("路线")
        let historyIntent = question.contains("历史") || question.contains("关系") || question.contains("背景")

        if focusIntent {
            return L10n.format("see.localAnswer.focus.format", object.name, object.description)
        }

        if shortIntent {
            return L10n.format("see.localAnswer.short.format", object.name)
        }

        if nextIntent {
            return L10n.format("see.localAnswer.next.format", object.name)
        }

        if childIntent {
            return L10n.format("see.localAnswer.children.format", object.name, object.description)
        }

        if historyIntent {
            return L10n.format("see.localAnswer.history.format", object.name, object.description)
        }

        if craftIntent {
            return L10n.format("see.localAnswer.craft.format", object.name, object.description)
        }

        if importanceIntent {
            return L10n.format("see.localAnswer.importance.format", object.name, object.description)
        }

        return L10n.format("see.localAnswer.default.format", object.name, object.description)
    }

    private func makeCandidates(
        primary result: VisionService.RecognitionResult,
        relatedPOI: POI?,
        near location: CLLocation?
    ) -> [RecognitionCandidate] {
        var candidates: [RecognitionCandidate] = [
            RecognitionCandidate(
                rank: 1,
                name: relatedPOI?.name ?? result.label,
                confidence: result.confidence,
                poi: relatedPOI
            )
        ]

        let relatedID = relatedPOI?.id
        let alternatives = rankedPOIs(matching: result.label, near: location)
            .filter { $0.poi.id != relatedID }
            .prefix(2)
            .enumerated()
            .map { index, match in
                RecognitionCandidate(
                    rank: index + 2,
                    name: match.poi.name,
                    confidence: min(0.92, max(0.08, result.confidence * 0.72 + match.score * 0.28 - Double(index) * 0.08)),
                    poi: match.poi
                )
            }

        candidates.append(contentsOf: alternatives)
        return candidates.uniquedByName().prefix(3).map { $0 }
    }

    private func makeCandidates(from response: BackendVisionResponse, near location: CLLocation?) -> [RecognitionCandidate] {
        var candidates: [RecognitionCandidate] = []

        if !response.suggestions.isEmpty {
            candidates = response.suggestions
                .prefix(3)
                .enumerated()
                .map { index, poi in
                    RecognitionCandidate(
                        rank: index + 1,
                        name: poi.name,
                        confidence: max(0.08, response.confidence - Double(index) * 0.18),
                        poi: poi
                    )
                }
        }

        if let label = response.label {
            if candidates.isEmpty {
                candidates.append(RecognitionCandidate(rank: 1, name: label, confidence: response.confidence))
            }

            let existingIDs = Set(candidates.compactMap { $0.poi?.id })
            let localMatches = rankedPOIs(matching: label, near: location)
                .filter { !existingIDs.contains($0.poi.id) }
                .prefix(max(0, 3 - candidates.count))

            for match in localMatches {
                candidates.append(
                    RecognitionCandidate(
                        rank: candidates.count + 1,
                        name: match.poi.name,
                        confidence: min(0.92, max(0.08, response.confidence * 0.72 + match.score * 0.28)),
                        poi: match.poi
                    )
                )
            }
        }

        return candidates.uniquedByName().prefix(3).enumerated().map { index, candidate in
            RecognitionCandidate(
                rank: index + 1,
                name: candidate.name,
                confidence: candidate.confidence,
                poi: candidate.poi
            )
        }
    }

    private func rankedPOIs(matching label: String, near location: CLLocation?) -> [(poi: POI, score: Double)] {
        let normalizedLabel = normalize(label)
        guard !normalizedLabel.isEmpty else { return [] }

        return POI.seedList.compactMap { poi -> (poi: POI, score: Double)? in
            let textScore = textualScore(for: normalizedLabel, poi: poi)
            let categoryScore = categoryScore(for: normalizedLabel, poi: poi)
            let proximityScore = location.map { distanceScore(from: $0, to: poi) } ?? 0
            let score = max(textScore, categoryScore) + proximityScore
            let isNearby = location.map { distance(from: $0, to: poi.coordinate) <= 260 } ?? false

            guard score >= 0.34 || isNearby else { return nil }
            return (poi, min(score, 0.98))
        }
        .sorted { first, second in
            if first.score == second.score {
                guard let location else { return first.poi.name < second.poi.name }
                return distance(from: location, to: first.poi.coordinate) < distance(from: location, to: second.poi.coordinate)
            }
            return first.score > second.score
        }
    }

    private func textualScore(for normalizedLabel: String, poi: POI) -> Double {
        aliases(for: poi).reduce(0) { bestScore, alias in
            let normalizedAlias = normalize(alias)
            guard !normalizedAlias.isEmpty else { return bestScore }

            if normalizedAlias == normalizedLabel {
                return max(bestScore, 0.82)
            }

            if normalizedAlias.contains(normalizedLabel), normalizedLabel.count >= 4 {
                return max(bestScore, 0.68)
            }

            if normalizedLabel.contains(normalizedAlias), normalizedAlias.count >= 4 {
                return max(bestScore, 0.72)
            }

            return bestScore
        }
    }

    private func categoryScore(for normalizedLabel: String, poi: POI) -> Double {
        switch poi.category {
        case .museum:
            return containsAny(normalizedLabel, ["museum", "gallery", "博物馆", "美术馆", "미술관", "박물관"]) ? 0.26 : 0
        case .palace:
            return containsAny(normalizedLabel, ["palace", "hall", "宫", "殿", "궁", "전"]) ? 0.26 : 0
        case .garden:
            return containsAny(normalizedLabel, ["garden", "park", "花园", "公园", "庭園", "정원"]) ? 0.22 : 0
        case .temple:
            return containsAny(normalizedLabel, ["temple", "shrine", "寺", "庙", "神社", "사원"]) ? 0.22 : 0
        case .building:
            return containsAny(normalizedLabel, ["building", "landmark", "square", "tower", "建筑", "地标", "广场"]) ? 0.20 : 0
        case .exhibit:
            return containsAny(normalizedLabel, ["artifact", "exhibit", "painting", "展品", "文物", "絵画"]) ? 0.22 : 0
        }
    }

    private func distanceScore(from location: CLLocation, to poi: POI) -> Double {
        switch distance(from: location, to: poi.coordinate) {
        case 0...120: return 0.56
        case 120...300: return 0.44
        case 300...1_200: return 0.26
        case 1_200...5_000: return 0.10
        default: return 0
        }
    }

    private func distance(from location: CLLocation, to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains(normalize($0)) }
    }

    private func aliases(for poi: POI) -> [String] {
        switch poi.id {
        case "taihedian":
            return [poi.name, "太和殿", "hall of supreme harmony", "supreme harmony", "palace", "hall"]
        case "zhonghedian":
            return [poi.name, "中和殿", "hall of central harmony", "central harmony"]
        case "baohedian":
            return [poi.name, "保和殿", "hall of preserving harmony", "preserving harmony"]
        case "wumen":
            return [poi.name, "午门", "meridian gate", "forbidden city gate"]
        case "taihemen":
            return [poi.name, "太和门", "gate of supreme harmony"]
        case "qianqinggong":
            return [poi.name, "乾清宫", "palace of heavenly purity"]
        case "louvre-paris":
            return [poi.name, "louvre", "louvre museum", "卢浮宫", "羅浮宮", "ルーヴル", "루브르", "mona lisa", "venus de milo"]
        case "met-museum-new-york":
            return [poi.name, "the met", "met museum", "metropolitan museum", "大都会艺术博物馆", "大都會藝術博物館", "メトロポリタン美術館"]
        case "british-museum-london":
            return [poi.name, "british museum", "大英博物馆", "大英博物館", "대영박물관"]
        case "tokyo-national-museum":
            return [poi.name, "tokyo national museum", "东京国立博物馆", "東京国立博物館", "도쿄국립박물관"]
        case "national-palace-museum-taipei":
            return [poi.name, "national palace museum", "台北故宫", "台北故宮", "国立故宮博物院"]
        case "contemporary-jewish-museum-san-francisco":
            return [poi.name, "contemporary jewish museum", "cjm", "当代犹太博物馆", "當代猶太博物館"]
        case "sfmoma":
            return [poi.name, "sfmoma", "san francisco moma", "modern art museum", "旧金山现代艺术博物馆"]
        case "union-square-sf":
            return [poi.name, "union square", "联合广场", "聯合廣場"]
        default:
            return [poi.name]
        }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
    }

    private func localizedCategory(_ category: String?, poi: POI?) -> String {
        if let poi {
            switch poi.category {
            case .palace: return L10n.string("category.palace")
            case .temple: return L10n.string("category.temple")
            case .garden: return L10n.string("category.garden")
            case .museum: return L10n.string("category.museum")
            case .exhibit: return L10n.string("category.exhibit")
            case .building: return L10n.string("category.building")
            }
        }

        switch category?.lowercased() {
        case "palace": return L10n.string("category.palace")
        case "temple": return L10n.string("category.temple")
        case "garden": return L10n.string("category.garden")
        case "museum": return L10n.string("category.museum")
        case "exhibit": return L10n.string("category.exhibit")
        case "building": return L10n.string("category.building")
        default: return category ?? L10n.string("category.landmark")
        }
    }

    private func localizedSourceName(_ sourceName: String) -> String {
        switch sourceName {
        case "本地视觉识别":
            return L10n.string("see.source.localVision")
        case "MiMo 多模态识别":
            return L10n.string("see.source.mimoVision")
        case "故宫博物院公开资料":
            return L10n.string("guide.source.palaceMuseum")
        case "离线文化地点":
            return L10n.string("guide.source.offlineCultural")
        case "Apple 地图附近地点":
            return L10n.string("guide.source.appleMaps")
        case "用户添加":
            return L10n.string("guide.source.user")
        default:
            return sourceName
        }
    }
}

private struct BackendVisionResponse: Codable {
    let identified: Bool
    let poi: POI?
    let confidence: Double
    let suggestions: [POI]
    let label: String?
    let category: String?
    let description: String?
    let source: ContentSource?
}

private extension SeeAndAskService.ConversationMessage.MessageRole {
    var apiRole: String {
        switch self {
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
}

private extension Array where Element == SeeAndAskService.RecognitionCandidate {
    func uniquedByName() -> [Element] {
        var seen = Set<String>()
        return filter { candidate in
            let key = candidate.name
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .lowercased()
                .replacingOccurrences(of: "[^\\p{L}\\p{N}]+", with: "", options: .regularExpression)
            return seen.insert(key).inserted
        }
    }
}
