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
        
        // 支持更多图片格式
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpg"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.webp"),
            NSPasteboard.PasteboardType("public.image")
        ]
        
        // 尝试匹配支持的图片类型
        if let type = pasteboard.availableType(from: imageTypes),
           let imageData = pasteboard.data(forType: type),
           let image = NSImage(data: imageData) {
            return image
        }
        
        // 如果上述方法失败，尝试通过文件URL获取图片
        if pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue]) {
            if let fileURL = pasteboard.readObjects(forClasses: [NSURL.self], options: nil)?.first as? URL {
                let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif", "webp"]
                if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                    return NSImage(contentsOf: fileURL)
                }
            }
        }
        
        return nil
    }
    
    deinit {
        stopMonitoring()
    }
}