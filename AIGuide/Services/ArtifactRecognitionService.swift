// Artifact Recognition Service - Museum Exhibit Identification

import Foundation
import UIKit
import Vision

@MainActor
class ArtifactRecognitionService: ObservableObject {
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var recognizedArtifact: Artifact?
    @Published var conversationHistory: [ChatMessage] = []
    @Published var currentQuestion = ""
    @Published var recentRecognitions: [Artifact] = []
    
    // MARK: - Types
    struct Artifact: Identifiable, Codable {
        let id: String
        let name: String
        let dynasty: String?
        let category: String
        let description: String
        let detailedInfo: String
        let confidence: Double
        let museum: String?
        let exhibition: String?
        let imageURL: String?
        let relatedArtifacts: [String]
        
        var displayName: String {
            if let dynasty = dynasty {
                return "\(dynasty)·\(name)"
            }
            return name
        }
    }
    
    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: MessageRole
        let content: String
        let timestamp: Date
        
        enum MessageRole {
            case user
            case assistant
        }
    }
    
    // MARK: - Mock Data
    private let mockArtifacts: [Artifact] = [
        Artifact(
            id: "a001",
            name: "清明上河图",
            dynasty: "北宋",
            category: "书画",
            description: "中国十大传世名画之一，北宋画家张择端仅见的存世精品。",
            detailedInfo: "宽24.8厘米，长528.7厘米，绢本设色。作品以长卷形式，采用散点透视构图法，生动记录了中国十二世纪北宋都城东京（又称汴京，今开封）的城市面貌和当时社会各阶层人民的生活状况。",
            confidence: 0.95,
            museum: "故宫博物院",
            exhibition: "书画馆",
            imageURL: nil,
            relatedArtifacts: ["a002", "a003"]
        ),
        Artifact(
            id: "a002",
            name: "千里江山图",
            dynasty: "北宋",
            category: "书画",
            description: "北宋王希孟创作的绢本设色画，现收藏于故宫博物院。",
            detailedInfo: "纵51.5厘米，横1191.5厘米，是中国十大传世名画之一。该作品以长卷形式，立足传统，画面细致入微，烟波浩渺的江河、层峦起伏的群山构成了一幅美妙的江南山水图。",
            confidence: 0.92,
            museum: "故宫博物院",
            exhibition: "书画馆",
            imageURL: nil,
            relatedArtifacts: ["a001"]
        ),
        Artifact(
            id: "a003",
            name: "翠玉白菜",
            dynasty: "清代",
            category: "玉器",
            description: "清代玉器，现收藏于台北故宫博物院。",
            detailedInfo: "长18.7厘米，宽9.1厘米，厚5.07厘米。这件翠玉白菜利用翡翠天然的色泽分布，将白色部分雕刻为菜帮，绿色部分雕刻为菜叶，叶尖上还雕有两只小虫，寓意多子多孙。",
            confidence: 0.88,
            museum: "台北故宫博物院",
            exhibition: "玉器馆",
            imageURL: nil,
            relatedArtifacts: []
        ),
        Artifact(
            id: "a004",
            name: "越王勾践剑",
            dynasty: "春秋",
            category: "青铜器",
            description: "春秋晚期越国青铜器，中国一级文物。",
            detailedInfo: "剑长55.7厘米，柄长8.4厘米，剑宽 4.6厘米，剑首外翻卷成圆箍形，内铸有间隔只有0.2毫米的11道同心圆，剑身上布满了规则的黑色菱形暗格花纹。",
            confidence: 0.91,
            museum: "湖北省博物馆",
            exhibition: "楚文化馆",
            imageURL: nil,
            relatedArtifacts: []
        ),
        Artifact(
            id: "a005",
            name: "兵马俑",
            dynasty: "秦代",
            category: "陶俑",
            description: "秦始皇陵陪葬坑中的陶俑，世界第八大奇迹。",
            detailedInfo: "兵马俑是古代墓葬雕塑的一个类别。古代实行人殉，奴隶是奴隶主生前的附属品，奴隶主死后奴隶要作为殉葬品为奴隶主陪葬。兵马俑即制成兵马（战车、战马、士兵）形状的殉葬品。",
            confidence: 0.94,
            museum: "秦始皇帝陵博物院",
            exhibition: "兵马俑坑",
            imageURL: nil,
            relatedArtifacts: []
        )
    ]
    
    // MARK: - Public Methods
    
    /// Recognize artifact from image
    func recognizeArtifact(from image: UIImage) async {
        isProcessing = true
        defer { isProcessing = false }
        
        // Use Vision framework to analyze image
        guard image.cgImage != nil else { return }
        
        // Simulate recognition (in real app, use ML model or API)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Find best match from mock data
        if let artifact = mockArtifacts.randomElement() {
            recognizedArtifact = artifact
            recentRecognitions.insert(artifact, at: 0)
            
            // Keep only last 20
            if recentRecognitions.count > 20 {
                recentRecognitions = Array(recentRecognitions.prefix(20))
            }
            
            // Add initial message
            conversationHistory = [
                ChatMessage(
                    role: .assistant,
                    content: """
                    这是**\(artifact.displayName)** (\(artifact.category))
                    
                    \(artifact.description)
                    
                    来源：\(artifact.museum ?? "未知博物馆") \(artifact.exhibition ?? "")
                    
                    您可以问我关于这件文物的任何问题，比如：
                    • 它的历史背景是什么？
                    • 有什么特别的工艺？
                    • 为什么这么珍贵？
                    """,
                    timestamp: Date()
                )
            ]
        }
    }
    
    /// Ask a question about the artifact
    func askQuestion(_ question: String) async {
        guard let artifact = recognizedArtifact else { return }
        
        currentQuestion = question
        isProcessing = true
        defer { isProcessing = false }
        
        // Add user message
        conversationHistory.append(
            ChatMessage(role: .user, content: question, timestamp: Date())
        )
        
        // Generate answer based on artifact info
        let answer = generateAnswer(for: artifact, question: question)
        
        // Add assistant message
        conversationHistory.append(
            ChatMessage(role: .assistant, content: answer, timestamp: Date())
        )
        
        currentQuestion = ""
    }
    
    /// Clear current recognition
    func clearRecognition() {
        recognizedArtifact = nil
        conversationHistory = []
        currentQuestion = ""
    }
    
    // MARK: - Private Methods
    
    private func generateAnswer(for artifact: Artifact, question: String) -> String {
        let lowerQuestion = question.lowercased()
        
        if lowerQuestion.contains("历史") || lowerQuestion.contains("背景") {
            return """
            **\(artifact.displayName)**的历史背景：
            
            \(artifact.detailedInfo)
            
            这件\(artifact.category)代表了\(artifact.dynasty ?? "")时期的艺术成就。
            """
        } else if lowerQuestion.contains("工艺") || lowerQuestion.contains("制作") {
            return """
            **\(artifact.name)**的制作工艺：
            
            从这件作品可以看出，古代工匠采用了精湛的技艺。\(artifact.detailedInfo)
            
            这种工艺在当时是非常先进的。
            """
        } else if lowerQuestion.contains("珍贵") || lowerQuestion.contains("价值") || lowerQuestion.contains("重要") {
            return """
            **\(artifact.name)**之所以珍贵：
            
            1. 历史价值：它是\(artifact.dynasty ?? "")时期的重要文物
            2. 艺术价值：代表了当时的最高艺术水平
            3. 文化价值：承载着丰富的历史文化信息
            
            \(artifact.description)
            """
        } else if lowerQuestion.contains("在哪") || lowerQuestion.contains("博物馆") {
            return """
            **\(artifact.name)**目前收藏在：
            
            \(artifact.museum ?? "未知博物馆")
            \(artifact.exhibition.map { "展览位置：\($0)" } ?? "")
            """
        } else {
            return """
            关于**\(artifact.name)**：
            
            \(artifact.description)
            
            \(artifact.detailedInfo)
            
            如果您想了解更多，可以问我：
            • 历史背景
            • 制作工艺
            • 为什么珍贵
            • 收藏地点
            """
        }
    }
}

