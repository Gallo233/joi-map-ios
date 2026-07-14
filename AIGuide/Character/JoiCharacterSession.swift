import Foundation

enum JoiMood: Int, Equatable {
    case neutral
    case attentive
    case thinking
    case delighted
    case concerned
}

@MainActor
final class JoiCharacterSession: ObservableObject {
    static let shared = JoiCharacterSession()

    @Published private(set) var mood: JoiMood = .neutral
    @Published private(set) var isSpeaking = false
    @Published private(set) var messageKey = "joi.guide.ready"

    private init() {}

    func syncGuide(
        phase: GuideContextPhase,
        isLoading: Bool,
        isSpeaking: Bool,
        hasPOI: Bool
    ) {
        self.isSpeaking = isSpeaking

        if isSpeaking {
            mood = .delighted
            messageKey = "joi.guide.speaking"
            return
        }

        if isLoading || phase == .locating || phase == .recommending {
            mood = .thinking
            messageKey = "joi.guide.locating"
            return
        }

        if phase == .offline {
            mood = .concerned
            messageKey = "joi.guide.offline"
            return
        }

        if hasPOI {
            mood = .attentive
            messageKey = "joi.guide.arrived"
        } else {
            mood = .neutral
            messageKey = "joi.guide.ready"
        }
    }
}
