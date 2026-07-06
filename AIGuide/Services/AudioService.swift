// Audio Service - AVAudioPlayer Integration

import Foundation
import AVFoundation
import Combine

private enum AudioServiceError: LocalizedError {
    case ttsUnavailable

    var errorDescription: String? {
        switch self {
        case .ttsUnavailable:
            return L10n.string("error.audio.ttsUnavailable")
        }
    }
}

@MainActor
class AudioService: ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var volume: Float = 1.0
    @Published var error: Error?
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentGuide: AudioGuide?
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
    }
    
    deinit {
        // Direct cleanup without MainActor isolation
        audioPlayer?.stop()
        audioPlayer = nil
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Public Methods
    
    /// Load and prepare audio from guide
    func load(guide: AudioGuide) async throws {
        currentGuide = guide
        
        // TODO: Load actual audio file from URL
        // For now, simulate with local file or URL
        
        if let audioURL = guide.audioURL {
            // Load from URL
            let (data, _) = try await URLSession.shared.data(from: audioURL)
            audioPlayer = try AVAudioPlayer(data: data)
        } else {
            // Mock: Create silent audio of specified duration
            // In production, this would load from a real audio file
            try createMockAudio(duration: TimeInterval(guide.duration.rawValue))
        }
        
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }
    
    /// Play audio
    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    /// Pause audio
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// Toggle play/pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    /// Stop audio
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        progress = 0
        stopTimer()
    }
    
    /// Seek to time
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        audioPlayer?.currentTime = clampedTime
        currentTime = clampedTime
        progress = duration > 0 ? clampedTime / duration : 0
    }
    
    /// Seek by offset
    func seek(by offset: TimeInterval) {
        seek(to: currentTime + offset)
    }
    
    /// Set volume
    func setVolume(_ volume: Float) {
        self.volume = max(0, min(1, volume))
        audioPlayer?.volume = self.volume
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
                self.progress = self.duration > 0 ? player.currentTime / self.duration : 0
                
                // Check if playback finished
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Create mock audio for testing
    private func createMockAudio(duration: TimeInterval) throws {
        // Create a simple silent audio file for testing
        // In production, replace with actual audio loading
        
        let sampleRate: Double = 44100
        let channels: Int = 1
        let bitsPerSample: Int = 16
        
        let frameCount = Int(sampleRate * duration)
        let byteRate = sampleRate * Double(channels) * Double(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = frameCount * blockAlign
        let fileSize = 36 + dataSize
        
        var header = Data()
        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)
        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM format
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })
        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        
        // Create silent audio data (all zeros)
        let audioData = Data(count: dataSize)
        
        let fullData = header + audioData
        audioPlayer = try AVAudioPlayer(data: fullData)
    }
}

// MARK: - TTS Service (Future)
extension AudioService {
    /// Future: Generate TTS audio from text
    func generateTTS(text: String, style: GuideStyle) async throws -> URL {
        throw AudioServiceError.ttsUnavailable
    }
}
