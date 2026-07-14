import SwiftUI
import JoiCubismRuntime

enum JoiCharacterFraming {
    case avatar
    case bust

    var zoom: CGFloat {
        switch self {
        case .avatar: return 3.3
        case .bust: return 2.0
        }
    }

    var verticalOffset: CGFloat {
        switch self {
        case .avatar: return -2.15
        case .bust: return -0.95
        }
    }
}

struct JoiCharacterView: UIViewRepresentable {
    @ObservedObject var session: JoiCharacterSession
    let framing: JoiCharacterFraming

    func makeUIView(context: Context) -> JoiCubismView {
        JoiCubismView(
            frame: .zero,
            modelPath: Self.modelPath,
            texturePath: Self.texturePath
        )
    }

    func updateUIView(_ view: JoiCubismView, context: Context) {
        view.mood = JoiCubismMood(rawValue: session.mood.rawValue) ?? .neutral
        view.isSpeaking = session.isSpeaking
        view.zoom = framing.zoom
        view.verticalOffset = framing.verticalOffset
    }

    private static var modelPath: String {
        Bundle.main.path(
            forResource: "joi",
            ofType: "moc3",
            inDirectory: "JoiCharacter"
        ) ?? ""
    }

    private static var texturePath: String {
        Bundle.main.path(
            forResource: "texture_00",
            ofType: "png",
            inDirectory: "JoiCharacter/joi.2048"
        ) ?? ""
    }
}
