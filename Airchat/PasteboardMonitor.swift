//
//  PasteboardMonitor.swift
//  Airchat
//
//  Created by Claude on 2025/6/21.
//

import SwiftUI
import AppKit

class PasteboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForPasteboardChanges()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForPasteboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            // Pasteboard changed, but we'll handle paste via keyboard event
        }
    }
    
    func getImageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        
        if let type = pasteboard.availableType(from: imageTypes),
           let imageData = pasteboard.data(forType: type),
           let image = NSImage(data: imageData) {
            return image
        }
        return nil
    }
    
    deinit {
        stopMonitoring()
    }
}