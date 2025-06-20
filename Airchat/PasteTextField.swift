//
//  PasteTextField.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI
import AppKit

struct PasteTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedImages: [AttachedImage]
    let placeholder: String
    var onSubmit: (() -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        let textView = PasteTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = CGSize(width: scrollView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.pasteDelegate = context.coordinator
        textView.drawsBackground = false
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? PasteTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        
        // Update placeholder
        textView.placeholderString = text.isEmpty ? placeholder : ""
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectedImages: $selectedImages, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var selectedImages: [AttachedImage]
        var onSubmit: (() -> Void)?
        
        init(text: Binding<String>, selectedImages: Binding<[AttachedImage]>, onSubmit: (() -> Void)?) {
            self._text = text
            self._selectedImages = selectedImages
            self.onSubmit = onSubmit
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
        
        func handlePaste(from pasteboard: NSPasteboard) -> Bool {
            // Check for images in pasteboard
            let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
            
            if let type = pasteboard.availableType(from: imageTypes),
               let imageData = pasteboard.data(forType: type),
               let image = NSImage(data: imageData) {
                
                // Process the pasted image
                processImage(image)
                return true
            }
            
            // If no image, let the text view handle the paste normally
            return false
        }
        
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
}

class PasteTextView: NSTextView {
    weak var pasteDelegate: PasteTextField.Coordinator?
    var placeholderString: String = "" {
        didSet {
            needsDisplay = true
        }
    }
    
    override func paste(_ sender: Any?) {
        if let pasteDelegate = pasteDelegate,
           pasteDelegate.handlePaste(from: NSPasteboard.general) {
            // Image was handled
            return
        }
        
        // Otherwise, perform normal paste
        super.paste(sender)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+V
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
            paste(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        // Handle Enter key for submission
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            if let coordinator = delegate as? PasteTextField.Coordinator {
                coordinator.onSubmit?()
                return
            }
        }
        super.keyDown(with: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw placeholder if needed
        if string.isEmpty && !placeholderString.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.placeholderTextColor
            ]
            
            let textRect = NSRect(x: textContainerInset.width + 5,
                                  y: textContainerInset.height,
                                  width: bounds.width - textContainerInset.width * 2 - 10,
                                  height: bounds.height - textContainerInset.height * 2)
            
            placeholderString.draw(in: textRect, withAttributes: attributes)
        }
    }
}