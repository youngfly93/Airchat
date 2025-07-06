//
//  RealLiquidGlass.swift
//  Airchat
//
//  Created by Claude on 2025/7/6.
//  基于参考项目重新实现真正的 Liquid Glass 效果
//

import SwiftUI
import AppKit

// MARK: - 高级 NSVisualEffectView 配置
class EnhancedVisualEffectView: NSVisualEffectView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupAdvancedGlassEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAdvancedGlassEffect()
    }
    
    private func setupAdvancedGlassEffect() {
        // 基础配置
        self.material = .hudWindow
        self.blendingMode = .behindWindow
        self.state = .active
        self.wantsLayer = true
        
        // 高级配置
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.isOpaque = false
        self.layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // 尝试访问私有属性以增强效果
        if self.responds(to: Selector("_setGlassVariant:")) {
            self.perform(Selector("_setGlassVariant:"), with: 1)
        }
        
        // 设置更强的模糊效果
        if let backdropLayer = self.layer?.sublayers?.first {
            backdropLayer.setValue(20.0, forKey: "blurRadius")
            backdropLayer.setValue(1.2, forKey: "saturation")
        }
    }
}

// MARK: - SwiftUI 包装器
struct RealLiquidGlass: NSViewRepresentable {
    let cornerRadius: CGFloat
    let intensity: GlassIntensity
    
    init(cornerRadius: CGFloat = 16, intensity: GlassIntensity = .regular) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
    }
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        let effectView = EnhancedVisualEffectView()
        
        // 设置容器
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 配置效果视图
        effectView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(effectView)
        
        // 约束
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        // 设置圆角
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true
        
        // 根据强度调整效果
        configureIntensity(effectView: effectView)
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let effectView = nsView.subviews.first as? EnhancedVisualEffectView else { return }
        
        effectView.layer?.cornerRadius = cornerRadius
        configureIntensity(effectView: effectView)
    }
    
    private func configureIntensity(effectView: EnhancedVisualEffectView) {
        switch intensity {
        case .ultraThin:
            effectView.material = .selection
        case .thin:
            effectView.material = .menu
        case .regular:
            effectView.material = .hudWindow
        case .thick:
            effectView.material = .sidebar
        case .ultraThick:
            effectView.material = .headerView
        }
    }
}

// MARK: - 真实玻璃效果修饰符
struct TrueGlassEffect: ViewModifier {
    let cornerRadius: CGFloat
    let intensity: GlassIntensity
    let tint: Color?
    
    init(cornerRadius: CGFloat = 16, intensity: GlassIntensity = .regular, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.tint = tint
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // 真实的玻璃背景
                    RealLiquidGlass(cornerRadius: cornerRadius, intensity: intensity)
                    
                    // 可选的色调叠加
                    if let tint = tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.1))
                    }
                    
                    // 边缘高光
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - 便捷扩展
extension View {
    func trueGlass(
        cornerRadius: CGFloat = 16,
        intensity: GlassIntensity = .regular,
        tint: Color? = nil
    ) -> some View {
        self.modifier(TrueGlassEffect(
            cornerRadius: cornerRadius,
            intensity: intensity,
            tint: tint
        ))
    }
}

// MARK: - 高级玻璃容器
struct GlassContainer<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let intensity: GlassIntensity
    
    init(
        cornerRadius: CGFloat = 20,
        intensity: GlassIntensity = .regular,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.intensity = intensity
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                // 多层玻璃效果叠加
                ZStack {
                    // 主玻璃层
                    RealLiquidGlass(cornerRadius: cornerRadius, intensity: intensity)
                    
                    // 深度阴影
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black.opacity(0.05),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                    
                    // 顶部高光
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}