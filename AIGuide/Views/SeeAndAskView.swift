// See And Ask View

import SwiftUI
import UIKit

struct SeeAndAskView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var service = SeeAndAskService()
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private let accent = Color(red: 0.86, green: 0.23, blue: 0.10)
    private let forest = Color(red: 0.12, green: 0.40, blue: 0.24)
    private let mint = Color(red: 0.67, green: 0.93, blue: 0.84)
    private let paper = Color(.systemGroupedBackground)
    private let surface = Color(.systemBackground)
    private let softSurface = Color(.secondarySystemGroupedBackground)
    private let ink = Color.primary
    private let bottomTabClearance: CGFloat = 140

    var body: some View {
        NavigationStack {
            ZStack {
                if service.recognizedObject == nil {
                    captureView
                } else {
                    recognitionView
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: selectedImage) { _, newImage in
                guard let image = newImage else { return }
                Task {
                    await service.processImage(image)
                    if let object = service.recognizedObject,
                       let poi = object.relatedPOI {
                        appState.confirmPOIFromPhoto(
                            poi,
                            confidence: object.confidence,
                            source: object.sourceName
                        )
                    }
                    selectedImage = nil
                }
            }
        }
    }

    // MARK: - Capture

    private var captureView: some View {
        ZStack {
            paper
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(title: L10n.string("see.title"), subtitle: L10n.string("see.subtitle.capture"))
                    .padding(.horizontal, 22)
                    .padding(.top, 34)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 15) {
                        captureScanner

                        VStack(spacing: 7) {
                            Text(L10n.string("see.hero.title"))
                                .font(.system(size: 25, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)
                                .frame(maxWidth: 330)

                            Text(L10n.string("see.hero.subtitle"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.86)
                                .lineSpacing(2)
                                .frame(maxWidth: 318)
                        }

                        if service.isProcessing {
                            processingPill(L10n.string("see.processing"))
                        } else if let error = service.errorMessage {
                            statusPill(icon: "exclamationmark.triangle.fill", text: error, color: accent, lineLimit: 2)
                        } else {
                            statusPill(icon: "checkmark.circle.fill", text: L10n.string("see.status.available.compact"), color: forest)
                        }

                        HStack(spacing: 12) {
                            primaryActionButton(title: L10n.string("see.action.camera"), icon: "camera.fill", color: forest) {
                                openCamera()
                            }

                            primaryActionButton(title: L10n.string("see.action.album"), icon: "photo.on.rectangle", color: accent) {
                                showImagePicker = true
                            }
                        }
                        .padding(.horizontal, 22)

                        HStack(spacing: 8) {
                            SeeAskTipItem(icon: "viewfinder", text: L10n.string("see.tip.align"))
                            SeeAskTipItem(icon: "lightbulb.fill", text: L10n.string("see.tip.light"))
                            SeeAskTipItem(icon: "text.viewfinder", text: L10n.string("see.tip.label"))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, bottomTabClearance)
                }
            }
        }
    }

    private var captureScanner: some View {
        GeometryReader { proxy in
            let scannerWidth = min(max(proxy.size.width - 64, 236), 266)
            let scannerHeight = scannerWidth * 1.01
            let frameSize = scannerWidth * 0.66

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(surface)
                    .frame(width: scannerWidth, height: scannerHeight)
                    .overlay(
                        LinearGradient(
                            colors: [forest.opacity(0.08), .clear, mint.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 12)

                VStack(spacing: 12) {
                    HStack {
                        compactStatusPill(icon: "checkmark.circle.fill", text: L10n.string("see.mode.museum"), color: mint)
                        Spacer()
                        Image(systemName: "info.circle")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                    Spacer()

                    ZStack {
                        ScannerFrame(cornerColor: mint, lineWidth: 5)
                            .frame(width: frameSize, height: frameSize)

                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 54, weight: .medium))
                            .foregroundStyle(forest.opacity(0.62))

                        if service.isProcessing {
                            ProgressView()
                                .tint(forest)
                                .scaleEffect(1.15)
                                .offset(y: frameSize * 0.33)
                        }
                    }

                    Text(L10n.string("see.viewfinder.hint"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(forest)
                        .frame(maxWidth: scannerWidth - 22)
                        .background(forest.opacity(0.10), in: Capsule())

                    Spacer(minLength: 8)
                }
                .frame(width: scannerWidth, height: scannerHeight)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 278)
    }

    // MARK: - Recognition

    private var recognitionView: some View {
        ZStack(alignment: .bottom) {
            paper
                .ignoresSafeArea()

            if let object = service.recognizedObject {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        recognitionHero(object)
                        resultSheet(object)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 38)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func recognitionHero(_ object: SeeAndAskService.RecognizedObject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topBar(title: L10n.string("see.title"), subtitle: L10n.string("see.subtitle.success"))

            ZStack(alignment: .bottomLeading) {
                Group {
                    if let image = object.uiImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [forest.opacity(0.12), mint.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                ScannerFrame(cornerColor: mint, lineWidth: 4)
                    .padding(28)

                HStack {
                    statusPill(
                        icon: "checkmark.circle.fill",
                        text: L10n.format("see.confidence.format", Int(object.confidence * 100)),
                        color: forest
                    )
                    Spacer()
                    Text(object.category)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .foregroundStyle(forest)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.black.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        }
    }

    private func resultSheet(_ object: SeeAndAskService.RecognizedObject) -> some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(L10n.string("see.result.prefix"))
                            .font(.title2.weight(.bold))
                        Text(object.name)
                            .font(.system(size: 31, weight: .heavy, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                        Text(object.category)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .foregroundStyle(forest)
                            .background(forest.opacity(0.12), in: Capsule())
                    }

                    Spacer(minLength: 8)

                    Button {
                        service.clearConversation()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(forest)
                            .frame(width: 42, height: 42)
                            .background(forest.opacity(0.10), in: Circle())
                    }
                }
                .foregroundStyle(ink)

                HStack(spacing: 10) {
                    sourceBadge(object)
                    Spacer(minLength: 8)
                    Label(L10n.string("see.ai.generated"), systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                narrationCard(object)
                candidateCard
                questionSection
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .background(surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }

    private func sourceBadge(_ object: SeeAndAskService.RecognizedObject) -> some View {
        HStack(spacing: 8) {
            Image(systemName: object.sourceVerified ? "shield.checkered" : "eye")
                .foregroundStyle(object.sourceVerified ? forest : accent)
            Text(L10n.format("see.source.format", object.sourceName))
                .lineLimit(1)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(forest)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(forest.opacity(0.10), in: Capsule())
    }

    private func narrationCard(_ object: SeeAndAskService.RecognizedObject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(forest.opacity(0.24), lineWidth: 7)
                    Image(systemName: "waveform")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(forest)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(service.isAnswering ? L10n.string("see.narration.answering") : L10n.string("see.narration.generating"))
                        .font(.headline)
                        .foregroundStyle(ink)
                    WaveformStrip(progress: service.isAnswering ? 0.72 : 0.42, color: forest)
                        .frame(height: 22)
                    Text(L10n.format("see.narration.basedOn.format", object.sourceName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "pause.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(forest, in: Circle())
                }
            }

            Divider()

            Text(object.description)
                .font(.body)
                .lineSpacing(7)
                .foregroundStyle(ink)
        }
        .padding(18)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.black.opacity(0.07), lineWidth: 1)
        )
    }

    private var candidateCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(L10n.string("see.candidates.title"))
                    .font(.headline)
                Spacer()
                Text(L10n.string("see.candidates.confidence"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(service.recognitionCandidates) { candidate in
                Button {
                    service.selectCandidate(candidate)
                    if let poi = candidate.poi {
                        appState.confirmPOIFromPhoto(
                            poi,
                            confidence: candidate.confidence,
                            source: poi.source.name
                        )
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("\(candidate.rank)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(candidate.rank == 1 ? accent : .secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.name)
                                .font(.subheadline.weight(candidate.rank == 1 ? .bold : .regular))
                                .foregroundStyle(ink)
                            if candidate.poi != nil {
                                Text(L10n.string("see.candidates.calibrate"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.14))
                                Capsule()
                                    .fill(candidate.rank == 1 ? accent : Color.secondary.opacity(0.32))
                                    .frame(width: max(8, proxy.size.width * candidate.confidence))
                            }
                        }
                        .frame(width: 84, height: 5)
                        Text("\(Int(candidate.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
                .buttonStyle(.plain)
                .disabled(candidate.poi == nil)
                .opacity(candidate.poi == nil ? 0.7 : 1)
            }
        }
        .padding(18)
        .background(softSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var questionSection: some View {
        VStack(spacing: 14) {
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
                Text(L10n.string("see.followup.title"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
            }

            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 42, height: 42)
                    .background(softSurface, in: Circle())

                TextField(L10n.string("see.followup.placeholder"), text: $service.currentQuestion)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit { submitQuestion() }

                Button(action: { submitQuestion() }) {
                    if service.isAnswering {
                        ProgressView()
                            .tint(forest)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(canSubmit ? forest : .gray.opacity(0.5))
                    }
                }
                .disabled(!canSubmit)
            }
            .padding(8)
            .background(surface, in: Capsule())
            .overlay(Capsule().stroke(forest.opacity(0.45), lineWidth: 1.2))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedQuestions, id: \.self) { question in
                        Button {
                            submitQuestion(question)
                        } label: {
                            Label(question, systemImage: chipIcon(for: question))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(forest)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(forest.opacity(0.10), in: Capsule())
                                .overlay(Capsule().stroke(.black.opacity(0.06), lineWidth: 1))
                        }
                        .disabled(service.isAnswering)
                    }
                }
            }

            VStack(spacing: 12) {
                ForEach(service.conversationHistory) { message in
                    ChatBubble(message: message, primaryColor: forest)
                }
            }

            if let error = service.errorMessage {
                statusPill(icon: "wifi.slash", text: error, color: accent, lineLimit: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Shared

    private func topBar(title: String, subtitle: String, onDark: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.headline.weight(.bold))
                .foregroundStyle(onDark ? .white : forest)
                .frame(width: 42, height: 42)
                .background((onDark ? Color.black.opacity(0.35) : surface.opacity(0.82)), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(onDark ? .white : ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(onDark ? .white.opacity(0.72) : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer()

            statusIconBadge(icon: "checkmark.circle", color: onDark ? mint : forest, onDark: onDark)
        }
    }

    private func primaryActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: color.opacity(0.25), radius: 12, x: 0, y: 7)
        }
        .disabled(service.isProcessing)
        .opacity(service.isProcessing ? 0.65 : 1)
    }

    private func statusPill(icon: String, text: String, color: Color, lineLimit: Int = 1) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.semibold))
            .lineLimit(lineLimit)
            .minimumScaleFactor(lineLimit == 1 ? 0.72 : 0.86)
            .multilineTextAlignment(.center)
            .foregroundStyle(color)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(maxWidth: 340)
            .background(surface.opacity(0.82), in: Capsule())
    }

    private func compactStatusPill(icon: String, text: String, color: Color, onDark: Bool = false) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background((onDark ? Color.black.opacity(0.32) : surface.opacity(0.82)), in: Capsule())
    }

    private func statusIconBadge(icon: String, color: Color, onDark: Bool = false) -> some View {
        Image(systemName: icon)
            .font(.headline.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 46, height: 46)
            .background((onDark ? Color.black.opacity(0.32) : surface.opacity(0.82)), in: Circle())
            .accessibilityLabel(Text(L10n.string("common.offlineReady")))
    }

    private func processingPill(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(forest)
            Text(text)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(forest)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surface.opacity(0.86), in: Capsule())
    }

    private var canSubmit: Bool {
        !service.currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !service.isAnswering
    }

    private var suggestedQuestions: [String] {
        guard let object = service.recognizedObject else {
            return [
                L10n.string("see.quick.where"),
                L10n.string("see.quick.thirtySeconds"),
                L10n.string("see.quick.whyImportant")
            ]
        }

        return [
            L10n.format("see.quick.bestView.format", object.name),
            L10n.string("see.quick.thirtySeconds"),
            L10n.string("see.quick.history"),
            L10n.string("see.quick.next")
        ]
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            alertTitle = L10n.string("see.cameraUnavailable.title")
            alertMessage = L10n.string("see.cameraUnavailable.message")
            showAlert = true
            return
        }
        showCamera = true
    }

    private func submitQuestion(_ preset: String? = nil) {
        let question = (preset ?? service.currentQuestion).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !service.isAnswering else { return }

        Task {
            await service.askQuestion(question)
            service.currentQuestion = ""
        }
    }

    private func chipIcon(for question: String) -> String {
        if question == L10n.string("see.quick.where") || question.contains(L10n.string("guide.viewIntro")) { return "scope" }
        if question == L10n.string("see.quick.thirtySeconds") { return "timer" }
        if question == L10n.string("see.quick.next") { return "arrow.triangle.turn.up.right.circle" }
        if question == L10n.string("see.quick.history") { return "book.closed" }
        return "star"
    }
}

// MARK: - Scanner Frame

struct ScannerFrame: View {
    let cornerColor: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let corner: CGFloat = min(width, height) * 0.18

            Path { path in
                path.move(to: CGPoint(x: 0, y: corner))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: corner, y: 0))

                path.move(to: CGPoint(x: width - corner, y: 0))
                path.addLine(to: CGPoint(x: width, y: 0))
                path.addLine(to: CGPoint(x: width, y: corner))

                path.move(to: CGPoint(x: width, y: height - corner))
                path.addLine(to: CGPoint(x: width, y: height))
                path.addLine(to: CGPoint(x: width - corner, y: height))

                path.move(to: CGPoint(x: corner, y: height))
                path.addLine(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: 0, y: height - corner))
            }
            .stroke(cornerColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Waveform

struct WaveformStrip: View {
    let progress: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<36, id: \.self) { index in
                let active = Double(index) / 36.0 <= progress
                Capsule()
                    .fill(active ? color : Color.secondary.opacity(0.18))
                    .frame(width: 3, height: CGFloat(8 + (index * 7 % 17)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Corner Marker

struct CornerMarker: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    let position: Position

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.green)
                .frame(width: 30, height: 3)

            Rectangle()
                .fill(Color.green)
                .frame(width: 3, height: 30)
        }
        .frame(width: 30, height: 30)
        .rotationEffect(rotation)
    }

    var rotation: Angle {
        switch position {
        case .topLeft: return .degrees(0)
        case .topRight: return .degrees(90)
        case .bottomRight: return .degrees(180)
        case .bottomLeft: return .degrees(270)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: SeeAndAskService.ConversationMessage
    let primaryColor: Color

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 54)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                Text(message.content)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .padding(13)
                    .background(message.role == .user ? primaryColor : Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant {
                Spacer(minLength: 54)
            }
        }
    }
}

// MARK: - Tip Items

struct SeeAskTipItem: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color(red: 0.12, green: 0.40, blue: 0.24))
                .frame(width: 42, height: 42)
                .background(Color(.systemBackground).opacity(0.82), in: Circle())

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TipItem: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)

            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private extension SeeAndAskService.RecognizedObject {
    var uiImage: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }
}

#Preview {
    SeeAndAskView()
        .environmentObject(AppState())
}
