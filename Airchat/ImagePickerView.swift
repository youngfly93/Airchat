//
//  ImagePickerView.swift
//  Airchat
//
//  Created by Claude on 2025/6/20.
//

import SwiftUI
import AppKit

struct ImagePickerView: View {
    @Binding var selectedImages: [AttachedImage]
    @State private var showFileImporter = false
    @State private var animatingImageIDs = Set<UUID>()
    
    var body: some View {
        VStack(spacing: 8) {
            if !selectedImages.isEmpty {
                imagePreviewSection
            }
            
            imagePickerButton
        }
        .onChange(of: selectedImages.count) { oldCount, newCount in
            if newCount > oldCount {
                // Animate newly added images
                if let lastImage = selectedImages.last {
                    animatingImageIDs.insert(lastImage.id)
                    
                    // Remove from animation set after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        animatingImageIDs.remove(lastImage.id)
                    }
                }
            }
        }
    }
    
    private var imagePreviewSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedImages) { image in
                    imagePreviewItem(image)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 80)
    }
    
    private func imagePreviewItem(_ image: AttachedImage) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: image.url)) { asyncImage in
                switch asyncImage {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                case .failure(_):
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                @unknown default:
                    EmptyView()
                }
            }
            .scaleEffect(animatingImageIDs.contains(image.id) ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animatingImageIDs.contains(image.id))
            
            Button(action: {
                removeImage(image)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
    }
    
    private var imagePickerButton: some View {
        Button(action: {
            showFileImporter = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                Text("添加图片")
                    .font(.system(size: 14))
            }
            .foregroundColor(.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    private func removeImage(_ image: AttachedImage) {
        selectedImages.removeAll { $0.id == image.id }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    if let imageData = try? Data(contentsOf: url) {
                        // Check file size (limit to 20MB)
                        let maxSize = 20 * 1024 * 1024 // 20MB
                        if imageData.count > maxSize {
                            print("Image too large: \(imageData.count) bytes (max: \(maxSize))")
                            continue
                        }
                        
                        // Verify it's a valid image
                        if NSImage(data: imageData) != nil {
                            // Compress if needed
                            let compressedData = compressImageData(imageData, maxSize: 5 * 1024 * 1024) // 5MB max after compression
                            
                            // Convert to base64 for API
                            let base64String = compressedData.base64EncodedString()
                            let mimeType = getMimeType(from: url)
                            let dataUrl = "data:\(mimeType);base64,\(base64String)"
                            
                            let attachedImage = AttachedImage(url: dataUrl)
                            selectedImages.append(attachedImage)
                        }
                    }
                }
            }
        case .failure(let error):
            print("File selection failed: \(error)")
        }
    }
    
    private func compressImageData(_ data: Data, maxSize: Int) -> Data {
        guard let nsImage = NSImage(data: data) else { return data }
        
        // If already small enough, return original
        if data.count <= maxSize {
            return data
        }
        
        // Calculate compression quality
        let compressionRatio = Double(maxSize) / Double(data.count)
        let quality = min(max(compressionRatio, 0.1), 0.9) // Between 0.1 and 0.9
        
        // Create bitmap representation
        if let tiffData = nsImage.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData) {
            
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: quality
            ]
            
            if let compressedData = bitmap.representation(using: .jpeg, properties: properties) {
                return compressedData
            }
        }
        
        return data
    }
    
    private func getMimeType(from url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            return "image/jpeg" // Default fallback
        }
    }
}

#Preview {
    ImagePickerView(selectedImages: .constant([]))
        .padding()
}