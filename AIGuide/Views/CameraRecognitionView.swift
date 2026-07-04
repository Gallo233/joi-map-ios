// Camera View - Photo Recognition

import SwiftUI
import PhotosUI

struct CameraRecognitionView: View {
    @StateObject private var visionService = VisionService()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCamera = false
    @State private var recognitionResult: VisionService.RecognitionResult?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Preview
                    imagePreviewSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Recognition Result
                    if let result = recognitionResult {
                        resultSection(result)
                    }
                    
                    // Tips
                    tipsSection
                }
                .padding()
            }
            .navigationTitle(L10n.string("拍照识别"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCamera = true }) {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .photosPicker(isPresented: .constant(false), selection: $selectedItem)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        await recognizeImage(image)
                    }
                }
            }
            .alert(L10n.string("识别错误"), isPresented: $showError) {
                Button(L10n.string("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Image Preview
    private var imagePreviewSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.1))
                .frame(height: 300)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text(L10n.string("拍摄或选择照片"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text(L10n.string("支持识别建筑、景点、展品"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Processing overlay
            if isProcessing {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.3))
                    
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            // Camera button
            Button(action: { showCamera = true }) {
                Label(L10n.string("拍照"), systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Photo library button
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(L10n.string("相册"), systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Result Section
    private func resultSection(_ result: VisionService.RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text(L10n.string("识别结果"))
                    .font(.headline)
                
                Spacer()
                
                Text(L10n.format("camera.confidence.percent.format", Int(result.confidence * 100)))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            // Result card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.label)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(localizedCategory(result.category))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Category icon
                    Image(systemName: categoryIcon(result.category))
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                }
                
                Divider()
                
                Text(result.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                // Confidence bar
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("识别置信度"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(confidenceColor(result.confidence))
                                .frame(width: geometry.size.width * result.confidence, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Navigate to guide for this POI
                }) {
                    Label(L10n.string("common.viewNarration"), systemImage: "book.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button(action: {
                    // Share result
                }) {
                    Label(L10n.string("common.share"), systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Button(action: {
                    // Report error
                }) {
                    Label(L10n.string("纠错"), systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Tips Section
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("拍照技巧"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "sun.max.fill", text: L10n.string("camera.tip.light"))
                TipRow(icon: "viewfinder", text: L10n.string("camera.tip.center"))
                TipRow(icon: "hand.raised.fill", text: L10n.string("camera.tip.steady"))
                TipRow(icon: "textformat.size", text: L10n.string("camera.tip.text"))
            }
        }
        .padding()
        .background(.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    private func recognizeImage(_ image: UIImage) async {
        isProcessing = true
        defer { isProcessing = false }
        
        if let result = await visionService.recognizeImage(image) {
            recognitionResult = result
        } else {
            errorMessage = L10n.string("camera.error.unrecognized")
            showError = true
        }
    }

    private func localizedCategory(_ category: String) -> String {
        switch category {
        case "宫殿": return L10n.string("guide.category.palace")
        case "寺庙": return L10n.string("guide.category.temple")
        case "博物馆": return L10n.string("guide.category.museum")
        case "建筑": return L10n.string("guide.category.building")
        case "园林": return L10n.string("guide.category.garden")
        case "城门": return L10n.string("guide.category.building")
        case "其他": return L10n.string("common.other")
        default: return category
        }
    }
    
    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "宫殿": return "building.2.fill"
        case "寺庙": return "building.columns.fill"
        case "博物馆": return "books.vertical.fill"
        case "建筑": return "building.fill"
        case "园林": return "leaf.fill"
        case "桥梁": return "bridge.fill"
        default: return "mappin.circle.fill"
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .blue }
        if confidence >= 0.4 { return .orange }
        return .red
    }
}

// MARK: - Tip Row
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Camera View (UIKit Bridge)
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    CameraRecognitionView()
}
