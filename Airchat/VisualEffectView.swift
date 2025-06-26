//
//  VisualEffectView.swift
//  Airchat
//
//  Created by 杨飞 on 2025/6/18.
//

import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        
        // 优化视觉效果视图以兼容动画
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        view.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // 确保在动画期间保持视觉效果
        view.layer?.needsDisplayOnBoundsChange = true
        view.layer?.contentsGravity = .resize
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}