//
//  PasteHandler.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI
import AppKit

class PasteHandler: ObservableObject {
    @Published var shouldCheckPasteboard = false
    
    func handlePaste(selectedImages: Binding<[AttachedImage]>) {
        let pasteboard = NSPasteboard.general
        
        // Check for images in pasteboard
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        
        if let type = pasteboard.availableType(from: imageTypes),
           let imageData = pasteboard.data(forType: type),
           let image = NSImage(data: imageData) {
            
            // Process the pasted image
            processImage(image, selectedImages: selectedImages)
        }
    }
    
    private func processImage(_ nsImage: NSImage, selectedImages: Binding<[AttachedImage]>) {
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        // Convert to PNG for better compatibility
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        
        // Check size and compress if needed
        let maxSize = 5 * 1024 * 1024 // 5MB
        let imageData: Data
        
        if pngData.count > maxSize {
            // Try JPEG compression
            let quality = Double(maxSize) / Double(pngData.count)
            if let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) {
                imageData = jpegData
            } else {
                imageData = pngData
            }
        } else {
            imageData = pngData
        }
        
        // Create base64 data URL
        let base64String = imageData.base64EncodedString()
        let mimeType = pngData.count > maxSize ? "image/jpeg" : "image/png"
        let dataUrl = "data:\(mimeType);base64,\(base64String)"
        
        // Add to selected images
        let attachedImage = AttachedImage(url: dataUrl)
        selectedImages.wrappedValue.append(attachedImage)
    }
}