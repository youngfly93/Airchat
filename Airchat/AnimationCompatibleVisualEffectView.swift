//
//  AnimationCompatibleVisualEffectView.swift
//  Airchat
//
//  Created by Claude on 2025/6/26.
//

import SwiftUI
import AppKit

/// 优化版的VisualEffectView，专门处理动画兼容性
struct AnimationCompatibleVisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        
        // 基本设置
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        
        // 动画兼容性优化
        if let layer = view.layer {
            layer.backgroundColor = NSColor.clear.cgColor
            layer.isOpaque = false
            layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
            
            // 确保在动画期间保持视觉效果
            layer.needsDisplayOnBoundsChange = true
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            
            // 优化合成
            layer.shouldRasterize = false // 不要光栅化，保持实时效果
            layer.allowsEdgeAntialiasing = true
            layer.allowsGroupOpacity = false
        }
        
        // 确保视觉效果始终活跃
        view.appearance = NSApp.effectiveAppearance
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // 更新material和blendingMode
        if nsView.material != material {
            nsView.material = material
        }
        
        if nsView.blendingMode != blendingMode {
            nsView.blendingMode = blendingMode
        }
        
        // 确保状态正确
        if nsView.state != .active {
            nsView.state = .active
        }
        
        // 更新外观
        nsView.appearance = NSApp.effectiveAppearance
    }
}