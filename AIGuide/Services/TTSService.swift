// TTS Service - Text-to-Speech

import Foundation
import AVFoundation

@MainActor
class TTSService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isSpeaking = false
    @Published var progress: Double = 0
    @Published var currentText: String?
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private var totalCharacters: Int = 0
    private var spokenCharacters: Int = 0
    
    // MARK: - Voice Configuration
    private var fallbackLanguage: String {
        AIGuideLocalization.current.speechLanguageCode
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Speak the given text
    func speak(_ text: String, rate: Float = 0.5, pitch: Float = 1.0) {
        // Stop any current speech
        stop()

        let speechText = SpeechTextFormatter.condensedNarration(text)
        guard !speechText.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: speechText)
        
        // Match the system TTS fallback to the app language setting.
        if let voice = AVSpeechSynthesisVoice(language: fallbackLanguage) {
            utterance.voice = voice
        }
        
        utterance.rate = rate // 0.0 to 1.0, 0.5 is normal
        utterance.pitchMultiplier = pitch // 0.5 to 2.0
        utterance.volume = 1.0
        
        totalCharacters = speechText.count
        spokenCharacters = 0
        currentText = speechText
        isSpeaking = true
        
        synthesizer.speak(utterance)
    }
    
    /// Speak with style-specific settings
    func speakWithStyle(_ text: String, style: GuideStyle) {
        let rate: Float
        let pitch: Float
        
        switch style {
        case .history:
            rate = 0.45
            pitch = 1.0
        case .architecture:
            rate = 0.4
            pitch = 0.95
        case .children:
            rate = 0.5
            pitch = 1.2 // Higher pitch for children
        case .legend:
            rate = 0.4
            pitch = 1.05
        case .casual:
            rate = 0.55
            pitch = 1.1
        case .inDepth:
            rate = 0.4
            pitch = 0.95
        }
        
        speak(text, rate: rate, pitch: pitch)
    }
    
    /// Pause speech
    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isSpeaking = false
    }
    
    /// Resume speech
    func resume() {
        synthesizer.continueSpeaking()
        isSpeaking = true
    }
    
    /// Stop speech
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        progress = 0
        currentText = nil
    }
    
    /// Toggle pause/resume
    func togglePlayback() {
        if synthesizer.isPaused {
            resume()
        } else if synthesizer.isSpeaking {
            pause()
        } else if let text = currentText {
            speak(text)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TTSService: AVSpeechSynthesizerDelegate {
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
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            let spoken = characterRange.location + characterRange.length
            self.spokenCharacters = spoken
            self.progress = self.totalCharacters > 0 ? Double(spoken) / Double(self.totalCharacters) : 0
        }
    }
}

// MARK: - Singleton
extension TTSService {
    static let shared = TTSService()
}
