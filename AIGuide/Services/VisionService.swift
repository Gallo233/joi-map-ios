// Vision Service - Image Recognition

import Foundation
import Vision
import CoreML
import UIKit

class VisionService: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var lastResult: RecognitionResult?
    @Published var error: Error?
    
    // MARK: - Types
    struct RecognitionResult: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Double
        let category: String
        let description: String
        let timestamp: Date
    }
    
    struct DetectedObject {
        let label: String
        let confidence: Double
        let boundingBox: CGRect?
    }
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Public Methods
    
    /// Recognize building or exhibit from image
    @MainActor
    func recognizeImage(_ image: UIImage) async -> RecognitionResult? {
        isProcessing = true
        defer { isProcessing = false }
        
        guard let cgImage = image.cgImage else {
            error = VisionError.invalidImage
            return nil
        }
        
        do {
            // Try to classify the image
            let classifications = try await Self.classifyImage(cgImage)
            
            // Find the best match for landmarks/buildings
            if let bestMatch = findBestMatch(from: classifications) {
                let result = RecognitionResult(
                    label: bestMatch.label,
                    confidence: bestMatch.confidence,
                    category: categorizeLabel(bestMatch.label),
                    description: getDescriptionForLabel(bestMatch.label),
                    timestamp: Date()
                )
                lastResult = result
                return result
            }
            
            // If no specific match, return general classification
            if let first = classifications.first {
                let result = RecognitionResult(
                    label: first.label,
                    confidence: first.confidence,
                    category: "其他",
                    description: "识别为：\(first.label)",
                    timestamp: Date()
                )
                lastResult = result
                return result
            }
            
            return nil
        } catch {
            self.error = error
            return nil
        }
    }
    
    /// Detect text in image (OCR)
    @MainActor
    func detectText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        
        return await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                guard let observations = request.results else { return [] }
                
                return observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
            } catch {
                print("Text detection error: \(error)")
                return []
            }
        }.value
    }
    
    /// Detect faces in image
    @MainActor
    func detectFaces(in image: UIImage) async -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        
        return await Task.detached(priority: .userInitiated) {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                return request.results?.count ?? 0
            } catch {
                print("Face detection error: \(error)")
                return 0
            }
        }.value
    }
    
    // MARK: - Private Methods
    
    private static func classifyImage(_ cgImage: CGImage) async throws -> [DetectedObject] {
        try await Task.detached(priority: .userInitiated) {
            // Use Vision's built-in classification
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            try handler.perform([request])
            
            guard let observations = request.results else {
                return []
            }
            
            return observations.map { observation in
                DetectedObject(
                    label: observation.identifier,
                    confidence: Double(observation.confidence),
                    boundingBox: nil
                )
            }
        }.value
    }
    
    private func findBestMatch(from results: [DetectedObject]) -> DetectedObject? {
        // Look for landmarks, buildings, or architecture-related labels
        let landmarkKeywords = [
            "palace", "temple", "building", "architecture", "monument",
            "museum", "church", "castle", "tower", "bridge",
            "宫殿", "寺庙", "建筑", "塔", "桥", "博物馆"
        ]
        
        // First try to find a landmark match
        for result in results {
            let lowerLabel = result.label.lowercased()
            for keyword in landmarkKeywords {
                if lowerLabel.contains(keyword) {
                    return result
                }
            }
        }
        
        // If no landmark found, return highest confidence result
        return results.first
    }
    
    private func categorizeLabel(_ label: String) -> String {
        let lowerLabel = label.lowercased()
        
        if lowerLabel.contains("palace") || lowerLabel.contains("宫殿") {
            return "宫殿"
        } else if lowerLabel.contains("temple") || lowerLabel.contains("寺庙") {
            return "寺庙"
        } else if lowerLabel.contains("museum") || lowerLabel.contains("博物馆") {
            return "博物馆"
        } else if lowerLabel.contains("building") || lowerLabel.contains("建筑") {
            return "建筑"
        } else if lowerLabel.contains("garden") || lowerLabel.contains("花园") {
            return "园林"
        } else if lowerLabel.contains("bridge") || lowerLabel.contains("桥") {
            return "桥梁"
        } else {
            return "景观"
        }
    }
    
    private func getDescriptionForLabel(_ label: String) -> String {
        // Match known landmarks with descriptions
        let landmarks: [String: String] = [
            "太和殿": "紫禁城外朝三大殿之首，明清两代皇帝举行大典的地方",
            "中和殿": "皇帝前往太和殿大典之前暂歇之处",
            "保和殿": "清代除夕赐宴外藩、科举殿试场所",
            "午门": "紫禁城正门，皇帝颁发诏令、举行大典时使用",
            "乾清宫": "明代皇帝寝宫，清代处理政务场所",
            "天安门": "明清两代皇城正门，现为中华人民共和国象征",
            "长城": "中国古代伟大的防御工程，世界文化遗产",
            "故宫": "中国明清两代的皇家宫殿，世界上现存规模最大的宫殿型建筑",
        ]
        
        // Check for exact or partial match
        for (key, description) in landmarks {
            if label.contains(key) {
                return description
            }
        }
        
        return "识别为：\(label)"
    }
}

// MARK: - Error Types
enum VisionError: LocalizedError {
    case invalidImage
    case processingFailed
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "无效的图片"
        case .processingFailed: return "图片处理失败"
        case .noResults: return "未识别到内容"
        }
    }
}

// MARK: - Mock Data for Development
extension VisionService {
    static let mockResults: [RecognitionResult] = [
        RecognitionResult(
            label: "太和殿",
            confidence: 0.95,
            category: "宫殿",
            description: "紫禁城外朝三大殿之首，明清两代皇帝举行大典的地方",
            timestamp: Date()
        ),
        RecognitionResult(
            label: "中和殿",
            confidence: 0.88,
            category: "宫殿",
            description: "皇帝前往太和殿大典之前暂歇之处",
            timestamp: Date()
        ),
        RecognitionResult(
            label: "天安门",
            confidence: 0.92,
            category: "城门",
            description: "明清两代皇城正门，现为中华人民共和国象征",
            timestamp: Date()
        )
    ]
}
