//
//  PasteImageModifier.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI
import AppKit

struct PasteImageModifier: ViewModifier {
    @Binding var selectedImages: [AttachedImage]
    
    func body(content: Content) -> some View {
        content
            .background(PasteImageView(selectedImages: $selectedImages))
    }
}

struct PasteImageView: NSViewRepresentable {
    @Binding var selectedImages: [AttachedImage]
    
    func makeNSView(context: Context) -> NSView {
        let view = PasteView()
        view.onPaste = { image in
            processImage(image)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func processImage(_ nsImage: NSImage) {
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
        selectedImages.append(attachedImage)
    }
}

class PasteView: NSView {
    var onPaste: ((NSImage) -> Void)?
    
    override var acceptsFirstResponder: Bool { false }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            let pasteboard = NSPasteboard.general
            let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
            
            if let type = pasteboard.availableType(from: imageTypes),
               let imageData = pasteboard.data(forType: type),
               let image = NSImage(data: imageData) {
                onPaste?(image)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

extension View {
    func onPasteImage(selectedImages: Binding<[AttachedImage]>) -> some View {
        self.modifier(PasteImageModifier(selectedImages: selectedImages))
    }
}