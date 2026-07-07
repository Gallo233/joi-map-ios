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

    static let recommendedGuideVoices: [EdgeVoice] = [
        "zh-CN-XiaoxiaoNeural",
        "zh-CN-XiaochenNeural",
        "zh-CN-XiaomoNeural",
        "zh-CN-YunjianNeural",
        "zh-HK-HiuGaaiNeural",
        "zh-TW-HsiaoChenNeural",
        "zh-CN-XiaobeNeural",
    ].compactMap { voice(id: $0) }

    static let `default` = chineseVoices[0]

    static func voice(id: String) -> EdgeVoice? {
        chineseVoices.first { $0.id == id }
    }
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
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-XiaochenNeural") ?? .default, rate: "-8%", pitch: "+0Hz", volume: "+0%")
        case .architecture:
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-XiaomoNeural") ?? .default, rate: "-10%", pitch: "-3Hz", volume: "+0%")
        case .children:
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-XiaoyiNeural") ?? .default, rate: "+4%", pitch: "+8Hz", volume: "+5%")
        case .legend:
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-XiaomengNeural") ?? .default, rate: "-5%", pitch: "+4Hz", volume: "+0%")
        case .casual:
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-XiaoxuanNeural") ?? .default, rate: "+6%", pitch: "+4Hz", volume: "+5%")
        case .inDepth:
            return TTSConfig(voice: EdgeVoice.voice(id: "zh-CN-YunyangNeural") ?? .default, rate: "-12%", pitch: "-3Hz", volume: "+0%")
        }
    }
}

enum SpeechTextFormatter {
    static func condensedNarration(_ text: String, maxCharacters: Int = 720) -> String {
        let markdownLinkPattern = #"\[([^\]]+)\]\([^)]+\)"#
        let cleanupSteps: [(String, String)] = [
            (markdownLinkPattern, "$1"),
            (#"(?m)^\s{0,3}#{1,6}\s*"#, ""),
            (#"(?m)^\s*[-*•]\s+"#, ""),
            (#"(?m)^\s*(听点|聽點|可问|可問|Tip|Question)[:：]\s*"#, ""),
            (#"`{1,3}"#, ""),
            (#"\*\*|__|\*|_"#, ""),
            (#"\s+"#, " ")
        ]

        let cleaned = cleanupSteps
            .reduce(text) { partial, step in
                partial.replacingOccurrences(
                    of: step.0,
                    with: step.1,
                    options: .regularExpression
                )
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > maxCharacters else { return cleaned }

        let limitIndex = cleaned.index(cleaned.startIndex, offsetBy: maxCharacters)
        let prefix = String(cleaned[..<limitIndex])
        let sentenceMarks = CharacterSet(charactersIn: "。！？!?；;.")
        if let boundary = prefix.rangeOfCharacter(from: sentenceMarks, options: .backwards) {
            return String(prefix[..<boundary.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum SpeechVoiceResolver {
    static func language(for edgeVoice: EdgeVoice) -> String {
        switch edgeVoice.locale {
        case "zh-HK":
            return "zh-HK"
        case "zh-TW":
            return "zh-TW"
        default:
            return "zh-CN"
        }
    }

    static func systemVoice(for edgeVoice: EdgeVoice) -> AVSpeechSynthesisVoice? {
        if let directVoice = AVSpeechSynthesisVoice(identifier: edgeVoice.id) {
            return directVoice
        }

        let language = language(for: edgeVoice)
        let targetGender: AVSpeechSynthesisVoiceGender = edgeVoice.gender == "Female" ? .female : .male
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        return candidates.first { $0.gender == targetGender }
            ?? candidates.first
            ?? AVSpeechSynthesisVoice(language: language)
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
    @Published var availableVoices: [EdgeVoice] = EdgeVoice.recommendedGuideVoices
    @Published var useEdgeTTS = false // On-device TTS is the reliable default; Edge remains an optional path.
    
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
        var config = TTSConfig.preset(for: style)
        config.voice = selectedVoice
        await speak(text, config: config)
    }
    
    func speak(_ text: String, config: TTSConfig) async {
        stop()

        let speechText = SpeechTextFormatter.condensedNarration(text)
        guard !speechText.isEmpty else { return }

        currentText = speechText
        isSpeaking = true
        
        // Try Edge TTS first if enabled
        if useEdgeTTS {
            do {
                let audioData = try await fetchAudio(text: speechText, config: config)
                try playAudio(data: audioData)
                return
            } catch {
                print("Edge TTS Error: \(error), falling back to iOS TTS")
            }
        }
        
        // Fallback to iOS native TTS
        fallbackTTS(text: speechText, config: config)
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
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(SpeechVoiceResolver.language(for: config.voice))'>
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
        request.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.setValue("speech.platform.bing.com", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.httpBody = ssml.data(using: .utf8)
        request.timeoutInterval = 4
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.networkError
        }
        
        // Edge TTS returns audio with a header, we need to strip it
        if httpResponse.statusCode == 200 {
            return audioPayload(from: data)
        } else {
            throw TTSError.networkError
        }
    }
    
    private func audioPayload(from data: Data) -> Data {
        if data.starts(with: Data("ID3".utf8)) || isMP3FrameStart(data.startIndex, in: data) {
            return data
        }

        if let id3Range = data.range(of: Data("ID3".utf8)) {
            return data.subdata(in: id3Range.lowerBound..<data.endIndex)
        }

        if let syncIndex = data.indices.first(where: { isMP3FrameStart($0, in: data) }) {
            return data.subdata(in: syncIndex..<data.endIndex)
        }

        if let headerEnd = data.range(of: Data("\r\n\r\n".utf8))?.upperBound,
           headerEnd < data.endIndex {
            return data.subdata(in: headerEnd..<data.endIndex)
        }

        return data
    }

    private func isMP3FrameStart(_ index: Data.Index, in data: Data) -> Bool {
        let nextIndex = data.index(after: index)
        guard nextIndex < data.endIndex else { return false }
        return data[index] == 0xFF && (data[nextIndex] & 0xE0) == 0xE0
    }

    private func playAudio(data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()
        
        totalDuration = audioPlayer?.duration ?? 0
        startTime = Date()
        
        guard audioPlayer?.play() == true else {
            throw TTSError.audioPlaybackError
        }
        startProgressTimer()
    }
    
    private func fallbackTTS(text: String, config: TTSConfig) {
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = SpeechVoiceResolver.systemVoice(for: config.voice)
            ?? AVSpeechSynthesisVoice(language: AIGuideLocalization.current.speechLanguageCode) {
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
            self.audioPlayer = nil
            self.isSpeaking = false
            self.progress = 1.0
            self.currentText = nil
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
            self.currentText = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentText = nil
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
