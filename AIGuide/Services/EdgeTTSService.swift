// Edge TTS Service - High Quality Natural Voice (Fixed)

import Foundation
import AVFoundation

// MARK: - Voice Model
struct EdgeVoice: Identifiable, Codable {
    let id: String
    let name: String
    let locale: String
    let gender: String
    let description: String

    var displayName: String {
        if AIGuideLocalization.storedLocale.identifier.lowercased().hasPrefix("zh") {
            return name
        }

        let normalized = id
            .replacingOccurrences(of: "Neural", with: "")
            .split(separator: "-")
            .last
            .map(String.init) ?? name
        return normalized
    }

    var localizedDescription: String {
        switch id {
        case "zh-CN-XiaoxiaoNeural": return L10n.string("voice.xiaoxiao.desc")
        case "zh-CN-XiaoyiNeural": return L10n.string("voice.xiaoyi.desc")
        case "zh-CN-XiaochenNeural": return L10n.string("voice.xiaochen.desc")
        case "zh-CN-XiaohanNeural": return L10n.string("voice.xiaohan.desc")
        case "zh-CN-XiaomengNeural": return L10n.string("voice.xiaomeng.desc")
        case "zh-CN-XiaomoNeural": return L10n.string("voice.xiaomo.desc")
        case "zh-CN-XiaoxuanNeural": return L10n.string("voice.xiaoxuan.desc")
        case "zh-CN-YunxiNeural": return L10n.string("voice.yunxi.desc")
        case "zh-CN-YunjianNeural": return L10n.string("voice.yunjian.desc")
        case "zh-CN-YunxiaNeural": return L10n.string("voice.yunxia.desc")
        case "zh-CN-YunyangNeural": return L10n.string("voice.yunyang.desc")
        case "zh-HK-HiuGaaiNeural": return L10n.string("voice.cantoneseFemale.desc")
        case "zh-HK-WanLungNeural": return L10n.string("voice.cantoneseMale.desc")
        case "zh-TW-HsiaoChenNeural": return L10n.string("voice.taiwanFemale.desc")
        case "zh-TW-YunJheNeural": return L10n.string("voice.taiwanMale.desc")
        case "zh-CN-XiaobeNeural": return L10n.string("voice.sichuanFemale.desc")
        default: return description
        }
    }
    
    static let chineseVoices: [EdgeVoice] = [
        // 普通话 - 女声
        EdgeVoice(id: "zh-CN-XiaoxiaoNeural", name: "晓晓", locale: "zh-CN", gender: "Female", description: "温柔亲切，适合日常讲解"),
        EdgeVoice(id: "zh-CN-XiaoyiNeural", name: "晓艺", locale: "zh-CN", gender: "Female", description: "活泼可爱，适合儿童讲解"),
        EdgeVoice(id: "zh-CN-XiaochenNeural", name: "晓辰", locale: "zh-CN", gender: "Female", description: "专业严谨，适合历史讲解"),
        EdgeVoice(id: "zh-CN-XiaohanNeural", name: "晓涵", locale: "zh-CN", gender: "Female", description: "知性优雅，适合文化讲解"),
        EdgeVoice(id: "zh-CN-XiaomengNeural", name: "晓梦", locale: "zh-CN", gender: "Female", description: "甜美梦幻，适合传说讲解"),
        EdgeVoice(id: "zh-CN-XiaomoNeural", name: "晓墨", locale: "zh-CN", gender: "Female", description: "沉稳大气，适合建筑讲解"),
        EdgeVoice(id: "zh-CN-XiaoxuanNeural", name: "晓萱", locale: "zh-CN", gender: "Female", description: "热情开朗，适合轻松讲解"),
        
        // 普通话 - 男声
        EdgeVoice(id: "zh-CN-YunxiNeural", name: "云希", locale: "zh-CN", gender: "Male", description: "阳光活力，适合年轻风格"),
        EdgeVoice(id: "zh-CN-YunjianNeural", name: "云健", locale: "zh-CN", gender: "Male", description: "沉稳有力，适合正式讲解"),
        EdgeVoice(id: "zh-CN-YunxiaNeural", name: "云夏", locale: "zh-CN", gender: "Male", description: "温和儒雅，适合文化讲解"),
        EdgeVoice(id: "zh-CN-YunyangNeural", name: "云扬", locale: "zh-CN", gender: "Male", description: "专业标准，适合新闻播报"),
        
        // 方言 - 粤语
        EdgeVoice(id: "zh-HK-HiuGaaiNeural", name: "曉佳", locale: "zh-HK", gender: "Female", description: "粤语女声"),
        EdgeVoice(id: "zh-HK-WanLungNeural", name: "雲龍", locale: "zh-HK", gender: "Male", description: "粤语男声"),
        
        // 方言 - 台湾
        EdgeVoice(id: "zh-TW-HsiaoChenNeural", name: "曉臻", locale: "zh-TW", gender: "Female", description: "台湾腔女声"),
        EdgeVoice(id: "zh-TW-YunJheNeural", name: "雲哲", locale: "zh-TW", gender: "Male", description: "台湾腔男声"),
        
        // 方言 - 四川
        EdgeVoice(id: "zh-CN-XiaobeNeural", name: "晓北", locale: "zh-CN-SC", gender: "Female", description: "四川话女声"),
    ]
    
    static let `default` = chineseVoices[0]
}

// MARK: - TTS Configuration
struct TTSConfig {
    var voice: EdgeVoice
    var rate: String
    var pitch: String
    var volume: String
    
    static let `default` = TTSConfig(
        voice: .default,
        rate: "+0%",
        pitch: "+0Hz",
        volume: "+0%"
    )
    
    static func preset(for style: GuideStyle) -> TTSConfig {
        switch style {
        case .history:
            return TTSConfig(voice: EdgeVoice.chineseVoices[2], rate: "-10%", pitch: "+0Hz", volume: "+0%")
        case .architecture:
            return TTSConfig(voice: EdgeVoice.chineseVoices[5], rate: "-15%", pitch: "-5Hz", volume: "+0%")
        case .children:
            return TTSConfig(voice: EdgeVoice.chineseVoices[1], rate: "+5%", pitch: "+10Hz", volume: "+5%")
        case .legend:
            return TTSConfig(voice: EdgeVoice.chineseVoices[4], rate: "-5%", pitch: "+5Hz", volume: "+0%")
        case .casual:
            return TTSConfig(voice: EdgeVoice.chineseVoices[6], rate: "+10%", pitch: "+5Hz", volume: "+5%")
        case .inDepth:
            return TTSConfig(voice: EdgeVoice.chineseVoices[10], rate: "-20%", pitch: "-5Hz", volume: "+0%")
        }
    }
}

// MARK: - Edge TTS Service
@MainActor
class EdgeTTSService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isSpeaking = false
    @Published var progress: Double = 0
    @Published var currentText: String?
    @Published var selectedVoice: EdgeVoice = .default
    @Published var availableVoices: [EdgeVoice] = EdgeVoice.chineseVoices
    @Published var useEdgeTTS = true // Toggle between Edge TTS and iOS TTS
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var totalDuration: TimeInterval = 0
    private var startTime: Date?
    private let synthesizer = AVSpeechSynthesizer()
    
    // MARK: - Configuration
    private let baseURL = "https://speech.platform.bing.com/consumer/speech/synthesize/readaloud"
    private let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    
    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    func speak(_ text: String) async {
        await speak(text, config: .default)
    }
    
    func speakWithStyle(_ text: String, style: GuideStyle) async {
        let config = TTSConfig.preset(for: style)
        await speak(text, config: config)
    }
    
    func speak(_ text: String, config: TTSConfig) async {
        stop()
        
        currentText = text
        isSpeaking = true
        
        // Try Edge TTS first if enabled
        if useEdgeTTS {
            do {
                let audioData = try await fetchAudio(text: text, config: config)
                try playAudio(data: audioData)
                return
            } catch {
                print("Edge TTS Error: \(error), falling back to iOS TTS")
            }
        }
        
        // Fallback to iOS native TTS
        fallbackTTS(text: text, config: config)
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        progress = 0
        currentText = nil
        stopProgressTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
        isSpeaking = false
        stopProgressTimer()
    }
    
    func resume() {
        audioPlayer?.play()
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
        isSpeaking = true
        startProgressTimer()
    }
    
    func togglePlayback() {
        if isSpeaking {
            pause()
        } else if audioPlayer != nil || synthesizer.isPaused {
            resume()
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAudio(text: String, config: TTSConfig) async throws -> Data {
        let escapedText = text.escapedForSSML
        let ssml = """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'>
            <voice name='\(config.voice.id)'>
                <prosody rate='\(config.rate)' pitch='\(config.pitch)' volume='\(config.volume)'>
                    \(escapedText)
                </prosody>
            </voice>
        </speak>
        """
        
        let urlString = "\(baseURL)?TrustedClientToken=\(trustedClientToken)&ConnectionId=\(UUID().uuidString)"
        guard let url = URL(string: urlString) else {
            throw TTSError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("speech.platform.bing.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.httpBody = ssml.data(using: .utf8)
        request.timeoutInterval = 10
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }
        
        // Edge TTS returns audio with a header, we need to strip it
        if httpResponse.statusCode == 200 {
            // Check if response starts with audio header
            if let headerRange = data.prefix(300).range(of: Data("Path:audio\r\n".utf8)) {
                return data.subdata(in: headerRange.upperBound..<data.count)
            }
            return data
        } else {
            throw TTSError.networkError
        }
    }
    
    private func playAudio(data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        totalDuration = audioPlayer?.duration ?? 0
        startTime = Date()
        
        audioPlayer?.play()
        startProgressTimer()
    }
    
    private func fallbackTTS(text: String, config: TTSConfig) {
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = AVSpeechSynthesisVoice(language: AIGuideLocalization.current.speechLanguageCode) {
            utterance.voice = voice
        }
        
        // Parse rate from config
        let rateString = config.rate.replacingOccurrences(of: "%", with: "")
        if let ratePercent = Double(rateString) {
            utterance.rate = Float(max(0.0, min(1.0, 0.5 + ratePercent / 200)))
        } else {
            utterance.rate = 0.5
        }
        
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start)
            progress = min(1.0, elapsed / totalDuration)
        }
    }
}

private extension String {
    var escapedForSSML: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - AVAudioPlayerDelegate
extension EdgeTTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
            self.progress = 1.0
            self.stopProgressTimer()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension EdgeTTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.progress = 1.0
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let totalLength = utterance.speechString.count
            if totalLength > 0 {
                let spoken = characterRange.location + characterRange.length
                self.progress = Double(spoken) / Double(totalLength)
            }
        }
    }
}

// MARK: - Error Types
enum TTSError: LocalizedError {
    case networkError
    case invalidResponse
    case invalidURL
    case audioPlaybackError
    
    var errorDescription: String? {
        switch self {
        case .networkError: return L10n.string("error.network.noConnection")
        case .invalidResponse: return L10n.string("error.network.invalidResponse")
        case .invalidURL: return L10n.string("api.error.invalidURL")
        case .audioPlaybackError: return L10n.string("error.audio.playbackFailed")
        }
    }
}

// MARK: - Singleton
extension EdgeTTSService {
    static let shared = EdgeTTSService()
}
