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
        view.material = .hudWindow  // 使用 hudWindow 材质
        view.blendingMode = .behindWindow  // 使用 behindWindow 混合模式
        view.state = .active
        view.wantsLayer = true
        
        // 确保视觉效果视图是透明的
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.isOpaque = false
        
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}