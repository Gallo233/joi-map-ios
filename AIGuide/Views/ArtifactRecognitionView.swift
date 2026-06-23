// Artifact Recognition View - Redesigned

import SwiftUI

struct ArtifactRecognitionView: View {
    @StateObject private var service = ArtifactRecognitionService()
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var showHistory = false
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Colors
    let primaryColor = Color(red: 0.85, green: 0.35, blue: 0.15)
    let darkBg = Color(red: 0.12, green: 0.12, blue: 0.12)
    
    var body: some View {
        NavigationStack {
            ZStack {
                darkBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if service.recognizedArtifact != nil {
                        artifactDetailView
                    } else {
                        captureView
                    }
                }
            }
            .navigationTitle("see.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.close") { dismiss() }
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .sheet(isPresented: $showHistory) {
                recognitionHistoryView
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await service.recognizeArtifact(from: image)
                    }
                }
            }
        }
    }
    
    // MARK: - Capture View
    private var captureView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Camera viewfinder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 250, height: 250)
                
                // Corner markers
                VStack {
                    HStack {
                        CornerMarker(position: .topLeft)
                        Spacer()
                        CornerMarker(position: .topRight)
                    }
                    Spacer()
                    HStack {
                        CornerMarker(position: .bottomLeft)
                        Spacer()
                        CornerMarker(position: .bottomRight)
                    }
                }
                .frame(width: 250, height: 250)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                Text("see.capture.artifact.title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("see.capture.artifact.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                Button(action: { showCamera = true }) {
                    Label("see.action.camera", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primaryColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: { showImagePicker = true }) {
                    Label("see.action.album", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 40)
            
            // Tips
            HStack(spacing: 30) {
                TipItem(icon: "lightbulb.fill", text: L10n.string("see.tip.light"))
                TipItem(icon: "viewfinder", text: L10n.string("see.tip.align"))
                TipItem(icon: "hand.raised.fill", text: L10n.string("see.tip.steady"))
            }
            .padding(.top, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Artifact Detail View
    private var artifactDetailView: some View {
        VStack(spacing: 0) {
            if let artifact = service.recognizedArtifact {
                // Image with recognition overlay
                ZStack(alignment: .bottomLeading) {
                    // Background image (simulated)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 280)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                    
                    // Recognition overlay
                    VStack(alignment: .leading, spacing: 8) {
                        // Recognition badge
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("see.success")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                        
                        // Artifact info
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(artifact.category)·\(artifact.name)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            if let dynasty = artifact.dynasty {
                                Text(dynasty)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        
                        // Confidence
                        HStack {
                            Text("see.candidates.confidence")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            
                            Text("\(Int(artifact.confidence * 100))%")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                }
                
                // Content section
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Source
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundStyle(primaryColor)
                            Text(L10n.format("see.source.format", artifact.museum ?? L10n.string("see.source.curatorial")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(primaryColor.opacity(0.1))
                        .clipShape(Capsule())
                        
                        // AI Narration
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundStyle(primaryColor)
                                Text("see.ai.narration")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("see.duration.90s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(artifact.description)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            
                            Text(artifact.detailedInfo)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Q&A section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("see.followup.title")
                                .font(.headline)
                            
                            // Quick questions
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach([
                                        L10n.string("see.quick.whyImportant"),
                                        L10n.string("see.quick.craft"),
                                        L10n.string("see.quick.kids")
                                    ], id: \.self) { question in
                                        Button(action: {
                                            Task {
                                                await service.askQuestion(question)
                                            }
                                        }) {
                                            Text(question)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(primaryColor.opacity(0.1))
                                                .foregroundStyle(primaryColor)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            // Conversation history
                            ForEach(service.conversationHistory) { message in
                                HStack {
                                    if message.role == .user {
                                        Spacer(minLength: 60)
                                    }
                                    
                                    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                                        Text(message.content)
                                            .font(.subheadline)
                                            .padding(12)
                                            .background(message.role == .user ? primaryColor : .gray.opacity(0.2))
                                            .foregroundStyle(message.role == .user ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        
                                        Text(message.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if message.role == .assistant {
                                        Spacer(minLength: 60)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // Input bar
                HStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(primaryColor)
                    
                    TextField("guide.input.placeholder", text: $service.currentQuestion)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        Task {
                            await service.askQuestion(service.currentQuestion)
                            service.currentQuestion = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(service.currentQuestion.isEmpty ? .gray : primaryColor)
                    }
                    .disabled(service.currentQuestion.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }
    
    // MARK: - Recognition History
    private var recognitionHistoryView: some View {
        NavigationStack {
            List {
                if service.recentRecognitions.isEmpty {
                    ContentUnavailableView(
                        "see.history.empty.title",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("see.history.empty.desc")
                    )
                } else {
                    ForEach(service.recentRecognitions) { artifact in
                        HStack(spacing: 12) {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(primaryColor)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(artifact.displayName)
                                    .font(.headline)
                                Text(artifact.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("see.history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") { showHistory = false }
                }
            }
        }
    }
}
